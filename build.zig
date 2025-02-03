// This file is part of the Kirin Chess project.
//
// Kirin Chess is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Kirin Chess is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with Kirin Chess.  If not, see <https://www.gnu.org/licenses/>.

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

    // Set stack size to 256MB (adjust as needed)
    exe.stack_size = 1024 * 1024;

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

    const unit_tests = b.addTest(.{
        .root_source_file = b.path("src/tests.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Create a step for unit tests
    const run_unit_tests = b.addRunArtifact(unit_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit_tests.step);

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
