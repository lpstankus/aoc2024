const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const check_step = b.step("check", "Check if the project builds without codegen (faster)");

    inline for (1..20) |idx| {
        const file = std.fmt.comptimePrint("{d:0>2}", .{idx});

        const exe = b.addExecutable(.{
            .name = "aoc2024-" ++ file,
            .root_source_file = b.path("src/" ++ file ++ ".zig"),
            .target = target,
            .optimize = optimize,
        });
        b.installArtifact(exe);
        const run_cmd = b.addRunArtifact(exe);
        const run_step = b.step("run-" ++ file, "Run aoc challange " ++ file);
        run_step.dependOn(&run_cmd.step);

        exe.root_module.addAnonymousImport("input", .{
            .root_source_file = b.path("src/inputs/" ++ file ++ ".txt"),
        });
        exe.root_module.addAnonymousImport("example", .{
            .root_source_file = b.path("src/examples/" ++ file ++ ".txt"),
        });

        const check_exe = b.addExecutable(.{
            .name = "aoc2024-" ++ file,
            .root_source_file = b.path("src/" ++ file ++ ".zig"),
            .target = target,
            .optimize = .Debug,
        });
        check_step.dependOn(&check_exe.step);

        check_exe.root_module.addAnonymousImport("input", .{
            .root_source_file = b.path("src/inputs/" ++ file ++ ".txt"),
        });
        check_exe.root_module.addAnonymousImport("example", .{
            .root_source_file = b.path("src/examples/" ++ file ++ ".txt"),
        });
    }
}
