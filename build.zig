const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const lib_mod = b.createModule(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const lib = b.addLibrary(.{
        .linkage = .static,
        .name = "levenshtien",
        .root_module = lib_mod,
    });

    b.installArtifact(lib);

    // Examples
    const basic_example = b.addExecutable(.{
        .name = "basic",
        .root_source_file = b.path("examples/basic.zig"),
        .target = target,
        .optimize = optimize,
    });
    basic_example.root_module.addImport("lev", lib_mod);
    b.installArtifact(basic_example);

    const guess_name_example = b.addExecutable(.{
        .name = "guess_name",
        .root_source_file = b.path("examples/guess_name.zig"),
        .target = target,
        .optimize = optimize,
    });
    guess_name_example.root_module.addImport("lev", lib_mod);
    b.installArtifact(guess_name_example);

    const lib_unit_tests = b.addTest(.{
        .root_module = lib_mod,
    });

    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);
}
