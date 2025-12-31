const std = @import("std");
const microzig = @import("microzig");

const MicroBuild = microzig.MicroBuild(.{
    .rp2xxx = true,
});

pub fn build(b: *std.Build) void {
    const mz_dep = b.dependency("microzig", .{});
    const mb = MicroBuild.init(b, mz_dep) orelse return;

    const font8x8_dep = b.dependency("font8x8", .{});

    // 1. Define the command-line options
    const ssid = b.option([]const u8, "ssid", "WiFi SSID") orelse "DEFAULT_SSID";
    const pass = b.option([]const u8, "pass", "WiFi Password") orelse "DEFAULT_PASSWORD";

    // 2. Create the Options object
    const opts = b.addOptions();
    opts.addOption([]const u8, "ssid", ssid);
    opts.addOption([]const u8, "pass", pass);

    const firmware = mb.add_firmware(.{
        .name = "robocar",
        .target = mb.ports.rp2xxx.boards.raspberrypi.pico2_arm,
        .optimize = .ReleaseSmall,
        .root_source_file = b.path("src/main.zig"),
        .imports = &.{
            .{ .name = "font8x8", .module = font8x8_dep.module("font8x8") },
            // 3. Add the options as a module named "config"
            .{ .name = "config", .module = opts.createModule() },
        },
    });

    // We call this twice to demonstrate that the default binary output for
    // RP2040 is UF2, but we can also output other formats easily
    mb.install_firmware(firmware, .{});
    mb.install_firmware(firmware, .{ .format = .elf });
}
