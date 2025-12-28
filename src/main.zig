const std = @import("std");
const microzig = @import("microzig");
const rp2xxx = microzig.hal;
const time = rp2xxx.time;

const oled = @import("modules/oled.zig");

pub fn main() !void {
    // Initialize the OLED display
    var display = try oled.SSD1306.init(.{
        .address = 0x3C,
        .i2c_bus = 0,
        .sda_pin = 4,
        .scl_pin = 5,
        .baudrate = 400_000,
    });

    // Clear the display
    display.clear();

    // Draw some text
    display.draw_string_centered(0, "ROBOCAR");
    display.draw_string_centered(16, "Pico 2 W");
    display.draw_string_centered(32, "Ready!");
    display.draw_string(0, 48, "Hello World!");

    // Update the display
    try display.update();

    // Main loop - keep the display on
    while (true) {
        time.sleep_ms(1000);
    }
}
