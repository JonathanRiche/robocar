const std = @import("std");
const microzig = @import("microzig");
const rp2xxx = microzig.hal;
const time = rp2xxx.time;
const gpio = rp2xxx.gpio;
const i2c = rp2xxx.i2c;

const font8x8 = @import("font8x8");
const oled = @import("modules/oled_SH1106.zig");

const wifi = @import("modules/wifi.zig");

const i2c0 = i2c.instance.num(0);
const empty_row: []const u8 = " " ** 16;
const four_rows = empty_row ** 4;

pub fn main() !void {
    // Safe buffer size for rp2xxx to allocate, value can change for other chips
    const buffer_size = 200 * 1024; // 200 KB
    var backing_buffer: [buffer_size]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&backing_buffer);

    // Set up wifi
    try wifi.set_up_wifi();

    //NOTE: SET PINS Here

    //NOTE: These pins are for oled display
    const sda_pin = gpio.num(8);
    const scl_pin = gpio.num(9);

    //NOTE: These pins are for the i2s mic
    //Serial clock pin
    // const sck_pin = gpio.num(10);
    // //Word select pin
    // const ws_pin = gpio.num(11);
    // //Serial data pin
    // const sd_pin = gpio.num(12);
    //
    inline for (&.{ scl_pin, sda_pin }) |pin| {
        pin.set_slew_rate(.slow);
        pin.set_schmitt_trigger_enabled(true);
        pin.set_function(.i2c);
    }

    // inline for (&.{ sck_pin, ws_pin, sd_pin }) |pin| {
    //     // pin.set_slew_rate(.fast);
    //     // pin.set_schmitt_trigger_enabled(true);
    //     pin.set_function(.pio0);
    // }

    rp2xxx.i2c.I2C.apply(i2c0, .{ .baud_rate = 400_000, .clock_config = rp2xxx.clock_config });

    const i2c_dd = rp2xxx.drivers.I2C_Datagram_Device.init(i2c0, @enumFromInt(0x3C), null);

    // SH1106 driver for I2C mode
    const SH1106_I2C = microzig.drivers.display.sh1106.SH1106(.{
        .mode = .i2c,
        .Datagram_Device = @TypeOf(i2c_dd),
    });
    const lcd = SH1106_I2C.init(i2c_dd) catch unreachable;

    const print_val = four_rows ++ "  Hi there!";
    var buff: [print_val.len * 8]u8 = undefined;

    lcd.clear_screen(false) catch unreachable;
    lcd.write_gdram(font8x8.Fonts.draw(&buff, print_val)) catch unreachable;

    //Sleep before an action with RPX
    time.sleep_ms(2000);

    //NOTE: purposely forcing 9 iterations to test the display if wanted we will make dynamic later and change temp buf
    for (0..10) |i| {
        var aa = std.heap.ArenaAllocator.init(fba.allocator());
        defer aa.deinit();
        var temp_buf: [7]u8 = undefined;
        const str = std.fmt.bufPrint(&temp_buf, "Hello#{}", .{i}) catch unreachable;
        var counter_buf: [80]u8 = undefined;
        const text_centered = oled.center_to_screen(&counter_buf, str, empty_row, four_rows);

        const text = font8x8.Fonts.drawAlloc(aa.allocator(), text_centered) catch continue;

        lcd.clear_screen(false) catch continue;
        lcd.write_gdram(text) catch continue;

        time.sleep_ms(1000);
    }
}
