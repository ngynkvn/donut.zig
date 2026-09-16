const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});

    const optimize = b.standardOptimizeOption(.{});

    const exe_options = b.addOptions();
    const tracy = b.option([]const u8, "tracy", "Enable Tracy integration. Supply path to Tracy source");
    const tracy_callstack = b.option(bool, "tracy-callstack", "Include callstack information with Tracy data. Does nothing if -Dtracy is not provided") orelse (tracy != null);
    const tracy_allocation = b.option(bool, "tracy-allocation", "Include allocation information with Tracy data. Does nothing if -Dtracy is not provided") orelse (tracy != null);
    exe_options.addOption(bool, "enable_tracy", tracy != null);
    exe_options.addOption(bool, "enable_tracy_callstack", tracy_callstack);
    exe_options.addOption(bool, "enable_tracy_allocation", tracy_allocation);

    const exe = b.addExecutable(.{
        .name = "donut.zig",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    addOptionalTracy(b, exe, target, tracy, exe_options);

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const exe_unit_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    exe_unit_tests.root_module.addOptions("build_options", exe_options);

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    const exe_check = b.addExecutable(.{
        .name = "donut.zig",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    addOptionalTracy(b, exe_check, target, tracy, exe_options);

    const benchmark = b.addExecutable(.{
        .name = "donut-benchmark",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/benchmark.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    addOptionalTracy(b, benchmark, target, tracy, exe_options);
    const run_benchmark = b.addRunArtifact(benchmark);
    b.step("bench", "Measure rendering time and output bytes without terminal I/O").dependOn(&run_benchmark.step);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_exe_unit_tests.step);

    const check_step = b.step("check", "Run checks");
    check_step.dependOn(&exe_check.step);
    check_step.dependOn(&run_exe_unit_tests.step);
}

fn addOptionalTracy(b: *std.Build, exe: *std.Build.Step.Compile, target: std.Build.ResolvedTarget, tracy: ?[]const u8, exe_options: *std.Build.Step.Options) void {
    if (tracy) |tracy_path| {
        const client_cpp = b.pathJoin(
            &[_][]const u8{ tracy_path, "public", "TracyClient.cpp" },
        );

        exe.root_module.addIncludePath(b.path(tracy_path));
        exe.root_module.addCSourceFile(.{ .file = b.path(client_cpp), .flags = &[_][]const u8{ "-DTRACY_ENABLE=1", "-fno-sanitize=undefined" } });
        exe.root_module.linkSystemLibrary("c++", .{ .use_pkg_config = .no });
        exe.root_module.link_libc = true;

        if (target.result.os.tag == .windows) {
            exe.root_module.linkSystemLibrary("dbghelp", .{});
            exe.root_module.linkSystemLibrary("ws2_32", .{});
        }
    }
    exe.root_module.addOptions("build_options", exe_options);
}
