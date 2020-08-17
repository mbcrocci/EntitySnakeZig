const std = @import("std");
const Builder = std.build.Builder;
const raylib = @import("raylib-zig/lib.zig").Pkg("raylib-zig"); //call .Pkg() with the folder raylib-zig is in relative to project build.zig

pub fn build(b: *Builder) void {
    const mode = b.standardReleaseOptions();
    const target = b.standardTargetOptions(.{
        .default_target = .{
            .cpu_arch = .x86_64,
            .os_tag = .windows,
            .abi = .gnu,
        },
    });

    const system_lib = b.option(bool, "system-raylib", "link to preinstalled raylib libraries") orelse false;

    const exe = b.addExecutable("SnakeRayLib", "src/main.zig");
    exe.setBuildMode(mode);
    exe.setTarget(target);

    raylib.link(exe, system_lib);
    raylib.addAsPackage("raylib", exe);
    raylib.math.addAsPackage("raylib-math", exe);

    //exe.addPackagePath("flecs", "zig-flecs/src/flecs.zig");
    // const flecs_build = @import("zig-flecs/build.zig");
    // flecs_build.linkArtifact2(b, exe, target, flecs_build.LibType.static, "zig-flecs/");

    // exe.addPackagePath("ecs", "zig-ecs/src/ecs.zig");
    const ecs_build = @import("zig-ecs/build.zig");
    ecs_build.linkArtifact(b, exe, target, ecs_build.LibType.static, "zig-ecs/src/");

    const run_cmd = exe.run();
    const run_step = b.step("run", "run SnakeRayLib");
    run_step.dependOn(&run_cmd.step);

    exe.install();
}
