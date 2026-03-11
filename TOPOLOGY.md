<!-- SPDX-License-Identifier: PMPL-1.0-or-later -->
<!-- TOPOLOGY.md — Project architecture map and completion dashboard -->
<!-- Last updated: 2026-02-19 -->

# Skein.jl — Project Topology

## System Architecture

```
                        ┌─────────────────────────────────────────┐
                        │          EXTERNALS / ECOSYSTEM          │
                        ├─────────────────────────────────────────┤
                        │  ┌────────────┐      ┌────────────┐     │
                        │  │ KnotTheory │ ◀──▶ │   SQLite   │     │
                        │  │ (Logic)    │      │ (Storage)  │     │
                        │  └─────▲──────┘      └─────▲──────┘     │
                        │        │                   │            │
                        └────────┼───────────────────┼────────────┘
                                 │                   │
                                 ▼                   │
                        ┌────────────────────────────┼────────────┐
                        │           APPLICATION LAYER             │
                        ├─────────────────────────────────────────┤
                        │  ┌──────────────────┐      ┌──────────┐ │
                        │  │   Skein DB       │      │  Gauss   │ │
                        │  │   (API)          │ ───▶ │  Codes   │ │
                        │  └────────┬─────────┘      └─────┬────┘ │
                        │           │                      │      │
                        │  ┌────────▼─────────┐      ┌─────▼────┐ │
                        │  │   Query DSL      │      │Invariant │ │
                        │  │ (& and | logic)  │ ───▶ │ Calculator│ │
                        │  └────────┬─────────┘      └─────┬────┘ │
                        │           │                      │      │
                        │  ┌────────▼─────────┐      ┌─────▼────┐ │
                        │  │   Equivalence    │      │ Import / │ │
                        │  │   Engine         │ ◀──▶ │ Export   │ │
                        │  └──────────────────┘      └──────────┘ │
                        └──────────────────────┬──────────────────┘
                                               │
                        ┌──────────────────────▼──────────────────┐
                        │         REPO INFRASTRUCTURE             │
                        │  .machine_readable/ (state)             │
                        │  .github/workflows/ (RSR Gate)          │
                        │  Project.toml                           │
                        └─────────────────────────────────────────┘
```

## Completion Dashboard

```
COMPONENT                          STATUS              NOTES
─────────────────────────────────  ──────────────────  ─────────────────────────────────
CORE STORAGE
  Skein DB API                      ██████████ 100%    SQLite backend with WAL
  Gauss Code model                  ██████████ 100%    Core types complete
  Import/Export                     ██████████ 100%    CSV, JSON, KnotInfo

ANALYTICS & QUERY
  Query DSL (& and |)               ██████████ 100%    Composable predicates
  Invariant Calculator              ██████████ 100%    Crossing, Writhe, Hash
  Equivalence Engine                ██████████ 100%    Rotation, Relabel, Mirror

EXTENSIONS
  KnotTheory.jl Ext                 ██████████ 100%    Automated conversion & Jones
  Jones Polynomial Column           ████████░░  80%    Integration working
  R2/R3 Simplification              ░░░░░░░░░░   0%    Planned for v0.3.0

REPO INFRASTRUCTURE
  .machine_readable/ (STATE.scm)    ██████████ 100%    Updated to v0.2.0
  .github/workflows/ (CI)           ██████████ 100%    RSR standard compliance

─────────────────────────────────────────────────────────────────────────────
OVERALL:                            ████████░░  ~75%   Stable Database Layer
```

## Key Dependencies

```
Gauss Code ──────────► Skein DB API ───────────► Query DSL
                            ▲                      │
SQLite Backend ─────────────┘                      ▼
                                             Invariant Calculation
                                                   │
KnotTheory.jl ───────► Package Extension ──────────┤
                                                   │
                                             Equivalence Checking
```

## Update Protocol

This file is maintained by both humans and AI agents. When updating:

1. **After completing a component**: Change its bar and percentage
2. **After adding a component**: Add a new row in the appropriate section
3. **After architectural changes**: Update the ASCII diagram
4. **Date**: Update the `Last updated` comment at the top of this file

Progress bars use: `█` (filled) and `░` (empty), 10 characters wide.
Percentages: 0%, 10%, 20%, ... 100% (in 10% increments).
