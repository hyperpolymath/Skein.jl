// SPDX-License-Identifier: PMPL-1.0-or-later
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>

const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Shared library: libskein_ffi
    const lib = b.addSharedLibrary(.{
        .name = "skein_ffi",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Link against SQLite3 (system library)
    lib.linkSystemLibrary("sqlite3");
    lib.linkLibC();

    b.installArtifact(lib);

    // Static library variant
    const static_lib = b.addStaticLibrary(.{
        .name = "skein_ffi",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    static_lib.linkSystemLibrary("sqlite3");
    static_lib.linkLibC();

    b.installArtifact(static_lib);

    // Tests
    const tests = b.addTest(.{
        .root_source_file = b.path("test/integration_test.zig"),
        .target = target,
        .optimize = optimize,
    });

    tests.linkSystemLibrary("sqlite3");
    tests.linkLibC();

    const run_tests = b.addRunArtifact(tests);
    const test_step = b.step("test", "Run FFI integration tests");
    test_step.dependOn(&run_tests.step);
}
