const std = @import("std");

pub fn build(b: *std.Build) void {
    const lh_test_step = b.step("test-lh", "Run LinkedHash unit tests");
    const run_step = b.step("run", "Run the app");
    const docs_step = b.step("docs", 
    "Install generated docs into zig-out/prefix");

    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const vaxis = b.dependency("vaxis", .{
        .optimize = optimize,
        .target = target,
    });
    const exe_module = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .optimize = optimize,
        .target = target,
    });
    exe_module.addImport("vaxis", vaxis.module("vaxis"));
    
    const exe = b.addExecutable(.{
        .root_module = exe_module,
        .name = "zhist",
    });

    b.installArtifact(exe);
    const run_exe = b.addRunArtifact(exe);
    if (b.args) |args| {
        run_exe.addArgs(args);
    }
    run_step.dependOn(&run_exe.step);

    // Docs
    const install_docs = b.addInstallDirectory(.{
        .source_dir = exe.getEmittedDocs(),
        .install_dir = .prefix,
        .install_subdir = "docs",
    });
    docs_step.dependOn(&install_docs.step);

    //LinkedHash tests
    const lh_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("./src/LinkedHash.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_lh_tests = b.addRunArtifact(lh_tests);
    lh_test_step.dependOn(&run_lh_tests.step);
}
