// SPDX-License-Identifier: PMPL-1.0-or-later
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>

//! Skein FFI — C-compatible bindings for the Skein knot database.
//!
//! This module implements the foreign function interface specified by
//! the Idris2 ABI definitions in src/abi/Foreign.idr. It provides
//! C-callable functions for opening databases, storing/fetching knots,
//! and computing invariants.
//!
//! The canonical implementation is in Julia (src/*.jl). This FFI layer
//! enables other languages (C, C++, Rust, Python via ctypes, etc.) to
//! use Skein databases without a Julia runtime.

const std = @import("std");
const c = @cImport({
    @cInclude("sqlite3.h");
});

// -- Error codes (matching Foreign.idr SkeinError) --

pub const SKEIN_OK: c_int = 0;
pub const SKEIN_ERR_OPEN: c_int = 1;
pub const SKEIN_ERR_QUERY: c_int = 2;
pub const SKEIN_ERR_NOT_FOUND: c_int = 3;
pub const SKEIN_ERR_DUPLICATE: c_int = 4;
pub const SKEIN_ERR_READ_ONLY: c_int = 5;
pub const SKEIN_ERR_INVALID: c_int = 6;

// -- Opaque handle --

const SkeinDB = struct {
    db: ?*c.sqlite3,
    readonly: bool,
};

// -- Database lifecycle --

/// Open or create a Skein database.
///
/// path: null-terminated file path, or ":memory:" for in-memory.
/// readonly: 0 for read-write, 1 for read-only.
/// Returns: opaque handle, or null on failure.
export fn skein_open(path: [*:0]const u8, readonly: c_int) callconv(.C) ?*SkeinDB {
    const flags: c_int = if (readonly != 0)
        c.SQLITE_OPEN_READONLY
    else
        c.SQLITE_OPEN_READWRITE | c.SQLITE_OPEN_CREATE;

    var sqlite_db: ?*c.sqlite3 = null;
    const rc = c.sqlite3_open_v2(path, &sqlite_db, flags, null);
    if (rc != c.SQLITE_OK) {
        if (sqlite_db) |db| c.sqlite3_close(db);
        return null;
    }

    // Enable WAL mode and foreign keys
    _ = c.sqlite3_exec(sqlite_db, "PRAGMA journal_mode=WAL", null, null, null);
    _ = c.sqlite3_exec(sqlite_db, "PRAGMA foreign_keys=ON", null, null, null);

    if (readonly == 0) {
        // Create tables
        _ = c.sqlite3_exec(sqlite_db, @embedFile("schema.sql"), null, null, null);
    }

    const handle = std.heap.c_allocator.create(SkeinDB) catch return null;
    handle.* = .{
        .db = sqlite_db,
        .readonly = readonly != 0,
    };
    return handle;
}

/// Close a database handle and free resources.
export fn skein_close(handle: ?*SkeinDB) callconv(.C) void {
    const h = handle orelse return;
    if (h.db) |db| _ = c.sqlite3_close(db);
    std.heap.c_allocator.destroy(h);
}

// -- Invariant computation (pure, no database) --

/// Compute the crossing number from a raw Gauss code array.
///
/// crossings: pointer to signed int32 array.
/// length: number of elements.
/// Returns: crossing number (>= 0), or -1 on error.
export fn skein_crossing_number(crossings: ?[*]const i32, length: c_int) callconv(.C) c_int {
    if (length < 0) return -1;
    if (length == 0) return 0;
    const data = crossings orelse return -1;
    const len: usize = @intCast(length);

    // Count distinct absolute values
    var seen = std.AutoHashMap(u32, void).init(std.heap.c_allocator);
    defer seen.deinit();

    for (0..len) |i| {
        const abs_val: u32 = @intCast(@abs(data[i]));
        seen.put(abs_val, {}) catch return -1;
    }

    return @intCast(seen.count());
}

/// Compute the writhe from a raw Gauss code array.
///
/// crossings: pointer to signed int32 array.
/// length: number of elements.
/// Returns: writhe value, or std.math.minInt(i32) on error.
export fn skein_writhe(crossings: ?[*]const i32, length: c_int) callconv(.C) c_int {
    if (length < 0) return std.math.minInt(c_int);
    if (length == 0) return 0;
    const data = crossings orelse return std.math.minInt(c_int);
    const len: usize = @intCast(length);

    var first_sign = std.AutoHashMap(u32, i32).init(std.heap.c_allocator);
    defer first_sign.deinit();

    var w: c_int = 0;

    for (0..len) |i| {
        const val = data[i];
        const idx: u32 = @intCast(@abs(val));
        const sgn: i32 = if (val > 0) 1 else -1;

        if (first_sign.get(idx)) |fs| {
            w += fs;
            _ = fs;
        } else {
            first_sign.put(idx, sgn) catch return std.math.minInt(c_int);
        }
    }

    return w;
}

/// Count knots in the database.
///
/// Returns: count (>= 0), or -1 on error.
export fn skein_count(handle: ?*SkeinDB) callconv(.C) c_int {
    const h = handle orelse return -1;
    const db = h.db orelse return -1;

    var stmt: ?*c.sqlite3_stmt = null;
    const rc = c.sqlite3_prepare_v2(db, "SELECT COUNT(*) FROM knots", -1, &stmt, null);
    if (rc != c.SQLITE_OK) return -1;
    defer _ = c.sqlite3_finalize(stmt);

    if (c.sqlite3_step(stmt) == c.SQLITE_ROW) {
        return c.sqlite3_column_int(stmt, 0);
    }
    return -1;
}

/// Check if a knot with the given name exists.
///
/// Returns: 1 if exists, 0 if not, -1 on error.
export fn skein_haskey(handle: ?*SkeinDB, name: [*:0]const u8) callconv(.C) c_int {
    const h = handle orelse return -1;
    const db = h.db orelse return -1;

    var stmt: ?*c.sqlite3_stmt = null;
    const rc = c.sqlite3_prepare_v2(db, "SELECT 1 FROM knots WHERE name = ? LIMIT 1", -1, &stmt, null);
    if (rc != c.SQLITE_OK) return -1;
    defer _ = c.sqlite3_finalize(stmt);

    _ = c.sqlite3_bind_text(stmt, 1, name, -1, null);

    if (c.sqlite3_step(stmt) == c.SQLITE_ROW) {
        return 1;
    }
    return 0;
}

/// Delete a knot by name.
///
/// Returns: error code.
export fn skein_delete(handle: ?*SkeinDB, name: [*:0]const u8) callconv(.C) c_int {
    const h = handle orelse return SKEIN_ERR_INVALID;
    if (h.readonly) return SKEIN_ERR_READ_ONLY;
    const db = h.db orelse return SKEIN_ERR_INVALID;

    var stmt: ?*c.sqlite3_stmt = null;
    const rc = c.sqlite3_prepare_v2(db, "DELETE FROM knots WHERE name = ?", -1, &stmt, null);
    if (rc != c.SQLITE_OK) return SKEIN_ERR_QUERY;
    defer _ = c.sqlite3_finalize(stmt);

    _ = c.sqlite3_bind_text(stmt, 1, name, -1, null);

    if (c.sqlite3_step(stmt) != c.SQLITE_DONE) {
        return SKEIN_ERR_QUERY;
    }
    return SKEIN_OK;
}
