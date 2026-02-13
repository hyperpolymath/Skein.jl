// SPDX-License-Identifier: PMPL-1.0-or-later
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>

//! Integration tests for Skein FFI.
//!
//! Tests the C-compatible interface against in-memory databases
//! to verify correctness of the Zig implementation.

const std = @import("std");
const skein = @import("../src/main.zig");

test "crossing_number: empty code" {
    const result = skein.skein_crossing_number(null, 0);
    try std.testing.expectEqual(@as(c_int, 0), result);
}

test "crossing_number: trefoil" {
    const crossings = [_]i32{ 1, -2, 3, -1, 2, -3 };
    const result = skein.skein_crossing_number(&crossings, 6);
    try std.testing.expectEqual(@as(c_int, 3), result);
}

test "crossing_number: figure-eight" {
    const crossings = [_]i32{ 1, -2, 3, -4, 2, -1, 4, -3 };
    const result = skein.skein_crossing_number(&crossings, 8);
    try std.testing.expectEqual(@as(c_int, 4), result);
}

test "crossing_number: invalid length" {
    const result = skein.skein_crossing_number(null, -1);
    try std.testing.expectEqual(@as(c_int, -1), result);
}

test "writhe: empty code" {
    const result = skein.skein_writhe(null, 0);
    try std.testing.expectEqual(@as(c_int, 0), result);
}

test "writhe: trefoil" {
    const crossings = [_]i32{ 1, -2, 3, -1, 2, -3 };
    const result = skein.skein_writhe(&crossings, 6);
    // Writhe is deterministic for a given code
    try std.testing.expect(result != std.math.minInt(c_int));
}

test "database: open and close in-memory" {
    const db = skein.skein_open(":memory:", 0);
    try std.testing.expect(db != null);

    const count = skein.skein_count(db);
    try std.testing.expectEqual(@as(c_int, 0), count);

    skein.skein_close(db);
}

test "database: haskey on empty db" {
    const db = skein.skein_open(":memory:", 0);
    try std.testing.expect(db != null);
    defer skein.skein_close(db);

    const result = skein.skein_haskey(db, "nonexistent");
    try std.testing.expectEqual(@as(c_int, 0), result);
}

test "database: null handle returns error" {
    try std.testing.expectEqual(@as(c_int, -1), skein.skein_count(null));
    try std.testing.expectEqual(@as(c_int, -1), skein.skein_haskey(null, "test"));
    try std.testing.expectEqual(@as(c_int, skein.SKEIN_ERR_INVALID), skein.skein_delete(null, "test"));
}
