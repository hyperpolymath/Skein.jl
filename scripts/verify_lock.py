#!/usr/bin/env python3
# SPDX-License-Identifier: MPL-2.0
"""
Python implementation of scripts/check-lock-sync.sh.
Verifies .github/workflows/actions.lock is in sync with the workflow YAML.
"""
import sys
import os
import re
import glob

def norm(r):
    # owner/repo@ref, discarding subpath
    # returns "" for local or non-external
    if "@" not in r:
        return ""
    path, ref = r.rsplit("@", 1)
    if not path or not ref:
        return ""
    if path.startswith("./") or path.startswith("$/"):
        return ""
    parts = path.split("/")
    if len(parts) < 2:
        return ""
    return f"{parts[0]}/{parts[1]}@{ref}"

def ck(r):
    # case-fold owner/repo only, ref is case-sensitive
    if "@" not in r:
        return r.lower()
    prefix, ref = r.rsplit("@", 1)
    return f"{prefix.lower()}@{ref}"

def verify(wf_dir=".github/workflows"):
    lock_file = os.path.join(wf_dir, "actions.lock")
    if not os.path.isfile(lock_file):
        print(f"FATAL: no lockfile at {lock_file}")
        return 1

    workflows = sorted(glob.glob(os.path.join(wf_dir, "*.yml")) + glob.glob(os.path.join(wf_dir, "*.yaml")))
    if not workflows:
        print(f"FATAL: no workflow files under {wf_dir}")
        return 1

    # Pass 1: parse lockfile
    in_wf = False
    in_dep = False
    cur_wf = None
    depkey = None

    seen_path = set()
    lock = set() # (cur_wf, lr)
    haverec = set()
    want = set()
    wantsrc = {}
    disp = {}

    with open(lock_file, "r") as f:
        for line in f:
            line_str = line.rstrip("\r\n")
            if re.match(r"^workflows:\s*$", line_str):
                in_wf = True
                in_dep = False
                continue
            if re.match(r"^dependencies:\s*$", line_str):
                in_wf = False
                in_dep = True
                continue
            if re.match(r"^[a-z_]+:", line_str):
                in_wf = False
                in_dep = False
                continue

            if in_dep:
                m = re.match(r"^    '([^']+)':", line_str)
                if m:
                    depkey = m.group(1)
                    k = ck(depkey)
                    haverec.add(k)
                    disp[k] = depkey
                    continue
                m = re.match(r"^            - '([^']+)'", line_str)
                if m and depkey:
                    raw = m.group(1)
                    r = ck(raw)
                    disp[r] = raw
                    want.add(r)
                    wantsrc[r] = wantsrc.get(r, "") + f" dependencies:{depkey}"
                    continue
                continue

            if in_wf:
                m = re.match(r"^    '([^']+)':", line_str)
                if m:
                    cur_wf = m.group(1)
                    seen_path.add(cur_wf)
                    continue
                m = re.match(r"^        - '([^']+)'\s*$", line_str)
                if m and cur_wf:
                    raw = m.group(1)
                    lr = ck(raw)
                    disp[lr] = raw
                    lock.add((cur_wf, lr))
                    want.add(lr)
                    wantsrc[lr] = wantsrc.get(lr, "") + f" {cur_wf}"
                    continue

    # Pass 2: parse workflow files
    steplist = {}
    joblist = {}
    uses = set()

    for wf_path in workflows:
        steplist[wf_path] = []
        joblist[wf_path] = []
        with open(wf_path, "r") as f:
            for line in f:
                # strip trailing comment
                line_no_comment = re.sub(r"\s+#.*$", "", line.rstrip("\r\n"))
                m = re.match(r"^\s*-?\s*uses:\s*(.+)$", line_no_comment)
                if m:
                    raw = m.group(1).strip().strip("'\"")
                    n = norm(raw)
                    if n:
                        key = ck(n)
                        uses.add((wf_path, key))
                        if re.search(r"/\.github/workflows/[^@]*\.ya?ml@", raw):
                            joblist[wf_path].append(n)
                        else:
                            steplist[wf_path].append(n)

    bad = False
    jnote = ""

    for wf_path in workflows:
        wf_name = os.path.basename(wf_path)
        key = f".github/workflows/{wf_name}"

        # Clause 1: every STEP-LEVEL uses: must be locked under this path
        uniq = set()
        missing = []
        for u in steplist[wf_path]:
            if u in uniq:
                continue
            uniq.add(u)
            if (key, ck(u)) not in lock:
                missing.append(u)

        if missing:
            if key not in seen_path:
                print(f"FAIL {key}\n     not onboarded: no lockfile entry for this path\n     unlocked step-level refs: {' '.join(missing)}")
            else:
                print(f"FAIL {key}\n     step-level refs missing from the lockfile: {' '.join(missing)}")
            bad = True

        # Job-level reusable refs (advisory)
        juniq = set()
        jmissing = []
        for v in joblist[wf_path]:
            if v in juniq:
                continue
            juniq.add(v)
            if (key, ck(v)) not in lock:
                jmissing.append(v)
        if jmissing:
            jnote += f"\n  {key}: {' '.join(jmissing)}"

        # Clause 2: every lock entry must be referenced by this workflow
        orphan = []
        for (l_wf, l_ref) in lock:
            if l_wf != key:
                continue
            if (wf_path, l_ref) not in uses:
                orphan.append(disp.get(l_ref, l_ref))
        if orphan:
            print(f"FAIL {key}\n     stale lockfile entries, no uses: references them: {' '.join(orphan)}")
            bad = True

    # Lockfile entries for workflow files that no longer exist
    for p in seen_path:
        found = any(f".github/workflows/{os.path.basename(wf)}" == p for wf in workflows)
        if not found:
            print(f"FAIL {p}\n     lockfile entry for a workflow file that does not exist")
            bad = True

    # Clause 4: COVERAGE. Every workflow FILE must have a key in the lockfile
    unlisted = []
    for wf in workflows:
        k = f".github/workflows/{os.path.basename(wf)}"
        if k not in seen_path:
            unlisted.append(k)
    if unlisted:
        print(f"FAIL actions.lock: UNLISTED WORKFLOWS\n     {len(unlisted)} workflow file(s) have no key in the lockfile:\n       " + "\n       ".join(unlisted))
        bad = True

    # Clause 3: TRANSITIVE CLOSURE. Every ref named anywhere in the lockfile must resolve to a top-level dependencies: record
    dang = []
    for r in want:
        if not re.match(r"^[^/]+/[^/@]+@", r):
            continue
        if r not in haverec:
            dang.append(f"\n       {disp.get(r, r)}\n           named by:{wantsrc.get(r, '')}")
    if dang:
        print(f"FAIL actions.lock: DANGLING EDGES\n     {len(dang)} ref(s) are named in the lockfile but have no top-level dependencies: record." + "".join(dang))
        bad = True

    if bad:
        print("\nactions.lock is OUT OF SYNC with the workflow YAML, or is not transitively closed.")
        return 1

    print("actions.lock is in sync and transitively closed:")
    print("  * every step-level uses: is locked under its own workflow path")
    print("  * every lockfile entry is still referenced")
    print("  * every ref named in the lockfile resolves to a dependencies: record (0 dangling edges)")
    print("  * every workflow file has a lockfile key (zero-uses: workflows included)")
    if jnote:
        print(f"  note: job-level reusable refs not locked (harmless; see clause 1):{jnote}")
    return 0

if __name__ == "__main__":
    sys.exit(verify(sys.argv[1] if len(sys.argv) > 1 else ".github/workflows"))
