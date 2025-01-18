const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Create the main module
    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Create the executable
    const exe = b.addExecutable(.{
        .name = "kirin-chess",
        .root_module = exe_mod,
    });

    // Install the executable
    b.installArtifact(exe);

    // Create and configure the run command
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    // Add run step
    const run_step = b.step("run", "Run Kirin Chess");
    run_step.dependOn(&run_cmd.step);

    // Create unit tests
    const exe_unit_tests = b.addTest(.{
        .root_module = exe_mod,
    });

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    // Add test step
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_exe_unit_tests.step);

    // Add perft step
    const perft = b.step("perft", "Run perft tests");
    const perft_cmd = b.addRunArtifact(exe);
    perft_cmd.addArg("--perft");
    perft.dependOn(&perft_cmd.step);

    // Add magic number generation step
    const magic = b.step("magic", "Generate magic numbers");
    const magic_exe = b.addExecutable(.{
        .name = "magic-gen",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/magics.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const magic_cmd = b.addRunArtifact(magic_exe);
    magic.dependOn(&magic_cmd.step);
}
