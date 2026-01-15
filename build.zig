const std = @import("std");

pub fn build(b: *std.Build) void {
    const exe = b.addExecutable(.{
        .name = "sdl-zig",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = b.graph.host,
            .link_libc = true,
        }),
    });

    exe.root_module.linkSystemLibrary("c", .{});
    exe.root_module.linkSystemLibrary("SDL3", .{});
    exe.root_module.linkSystemLibrary("SDL3_ttf", .{});
    //exe.root_module.linkSystemLibrary("vulkan", .{});
    //exe.root_module.linkLibC();

    b.installArtifact(exe);
}
