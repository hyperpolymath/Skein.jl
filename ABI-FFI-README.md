<!-- SPDX-License-Identifier: PMPL-1.0-or-later -->
<!-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk> -->

# Skein.jl ABI/FFI Layer

## Architecture

| Layer | Language | Purpose | Location |
|-------|----------|---------|----------|
| **ABI** | Idris2 | Interface definitions with formal proofs | `src/abi/*.idr` |
| **FFI** | Zig | C-compatible implementation | `ffi/zig/src/*.zig` |
| **Headers** | C (generated) | Bridge between ABI and FFI | `generated/abi/*.h` |

## Overview

The canonical Skein implementation is in Julia (`src/*.jl`). The ABI/FFI layer provides C-compatible bindings so other languages can read and write Skein databases without requiring a Julia runtime.

### Idris2 ABI (`src/abi/`)

Formal specifications of:
- **Types.idr** — Data types with dependent-type proofs (GaussCode validity, hash length)
- **Layout.idr** — C struct memory layouts with size guarantees
- **Foreign.idr** — Function signatures with ownership and precondition documentation

### Zig FFI (`ffi/zig/`)

C-compatible implementation of the ABI specification:
- **src/main.zig** — Core FFI functions (open, close, count, haskey, crossing_number, writhe, delete)
- **src/schema.sql** — Database schema (must match Julia `src/storage.jl`)
- **test/integration_test.zig** — Integration tests

### Generated Headers (`generated/abi/`)

- **skein.h** — C header for consuming the FFI from C/C++/Python/etc.

## Building

```bash
cd ffi/zig
zig build           # builds libskein_ffi.so / .dylib / .dll
zig build test      # runs integration tests
```

Requires system SQLite3 (`sqlite3.h` and `libsqlite3`).

## Usage from C

```c
#include "skein.h"

int main() {
    skein_db_t db = skein_open(":memory:", 0);
    if (!db) return 1;

    int32_t trefoil[] = {1, -2, 3, -1, 2, -3};
    int cn = skein_crossing_number(trefoil, 6);
    // cn == 3

    int count = skein_count(db);
    // count == 0

    skein_close(db);
    return 0;
}
```

## Database Compatibility

The FFI layer creates and reads the same SQLite schema as the Julia implementation (schema version 2). Databases created by either implementation are fully interoperable.

## Status

The FFI layer implements a subset of the full Julia API:
- Database lifecycle (open, close)
- Pure invariant computation (crossing_number, writhe)
- Basic queries (count, haskey, delete)
- Store and fetch operations are defined in the ABI but not yet implemented in the Zig FFI

For the complete API, use the Julia implementation directly.
