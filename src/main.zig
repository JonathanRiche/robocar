const std = @import("std");
const microzig = @import("microzig");
const rp2xxx = microzig.hal;
const time = rp2xxx.time;
const gpio = rp2xxx.gpio;
const i2c = rp2xxx.i2c;

const font8x8 = @import("font8x8");
const oled = @import("modules/oled_SH1106.zig");

const wifi = @import("modules/wifi.zig");
const hardware_config = @import("hardware_config.zig");

const i2c0 = i2c.instance.num(0);
const empty_row: []const u8 = " " ** 8;
const four_rows = empty_row ** 4;
const default_sleep_time = 2000;

pub fn main() !void {
    // Safe buffer size for rp2xxx to allocate, value can change for other chips
    const buffer_size = 200 * 1024; // 200 KB
    var backing_buffer: [buffer_size]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&backing_buffer);

    // Set up wifi
    const check = wifi.set_up_wifi() catch "No Wifi";

    const lcd = try hardware_config.init_oled_config();

    //TODO: will add some type of controller loop later

    oled.set_text(.{ .fba = &fba, .lcd = lcd, .screen_text = "Connecting to Wifi" });

    //Sleep before an action with RPX
    time.sleep_ms(default_sleep_time);

    lcd.clear_screen(false) catch unreachable;
    oled.set_text(.{ .fba = &fba, .lcd = lcd, .screen_text = check });
}
