/* SPDX-License-Identifier: PMPL-1.0-or-later */
/* Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk> */

/*
 * skein.h — C-compatible interface for the Skein knot database.
 *
 * Generated from Idris2 ABI definitions (src/abi/Foreign.idr).
 * Implemented by Zig FFI (ffi/zig/src/main.zig).
 *
 * Usage:
 *   #include "skein.h"
 *   void *db = skein_open(":memory:", 0);
 *   int cn = skein_crossing_number(crossings, 6);
 *   skein_close(db);
 */

#ifndef SKEIN_H
#define SKEIN_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/* Error codes */
#define SKEIN_OK           0
#define SKEIN_ERR_OPEN     1
#define SKEIN_ERR_QUERY    2
#define SKEIN_ERR_NOT_FOUND 3
#define SKEIN_ERR_DUPLICATE 4
#define SKEIN_ERR_READ_ONLY 5
#define SKEIN_ERR_INVALID  6

/* Opaque database handle */
typedef void* skein_db_t;

/*
 * Database lifecycle
 */

/* Open or create a Skein database.
 * path: file path or ":memory:" for in-memory.
 * readonly: 0 for read-write, 1 for read-only.
 * Returns: database handle, or NULL on failure. */
skein_db_t skein_open(const char *path, int readonly);

/* Close a database handle and free resources. */
void skein_close(skein_db_t db);

/*
 * Invariant computation (pure functions, no database required)
 */

/* Compute crossing number from a Gauss code array.
 * crossings: array of signed int32 values.
 * length: number of elements.
 * Returns: crossing number (>= 0), or -1 on error. */
int skein_crossing_number(const int32_t *crossings, int length);

/* Compute writhe from a Gauss code array.
 * Returns: writhe value, or INT32_MIN on error. */
int skein_writhe(const int32_t *crossings, int length);

/*
 * Database operations
 */

/* Count knots in the database.
 * Returns: count (>= 0), or -1 on error. */
int skein_count(skein_db_t db);

/* Check if a knot with the given name exists.
 * Returns: 1 if exists, 0 if not, -1 on error. */
int skein_haskey(skein_db_t db, const char *name);

/* Delete a knot by name.
 * Returns: error code. */
int skein_delete(skein_db_t db, const char *name);

#ifdef __cplusplus
}
#endif

#endif /* SKEIN_H */
