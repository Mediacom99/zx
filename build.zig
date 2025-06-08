const std = @import("std");

pub fn build(b: *std.Build) void {
    // const lh_test_step = b.step("test-lh", "Run LinkedHash unit tests");
    const run_step = b.step("run", "Run the app");
    const docs_step = b.step("docs", 
    "Install generated docs into zig-out/prefix");
    const unicode_tests_step = b.step("unicode-tests", "Run unicode.zig tests");
    const history_tests_step = b.step("history-tests", "Run History.zig tests");
    const fuzzy_tests_step = b.step("fuzzy-tests", "Run fuzzy tests", );

    const deps_args = .{ 
        .optimize = b.standardOptimizeOption(.{}),
        .target = b.standardTargetOptions(.{}),
    };
    const vaxis = b.dependency("vaxis", deps_args);
    const exe_module = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .optimize = deps_args.optimize,
        .target = deps_args.target,
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

    // Unicode tests
    const unicode_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("./src/unicode.zig"),
            .target = deps_args.target,
            .optimize = deps_args.optimize,
        }),
    });
    const run_unicode_tests = b.addRunArtifact(unicode_tests);
    unicode_tests_step.dependOn(&run_unicode_tests.step);

    //History tests
    const history_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("./src/History.zig"),
            .target = deps_args.target,
            .optimize = deps_args.optimize,
        }),
    });
    const run_history_tests = b.addRunArtifact(history_tests);
    history_tests_step.dependOn(&run_history_tests.step);

    const fuzzy_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("./src/fuzzy/fuzzy.zig"),
            .target = deps_args.target,
            .optimize = deps_args.optimize,
        }),
    });
    const run_fuzzy_tests = b.addRunArtifact(fuzzy_tests);
    fuzzy_tests_step.dependOn(&run_fuzzy_tests.step);
}
