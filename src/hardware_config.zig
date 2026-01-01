const std = @import("std");
const microzig = @import("microzig");
const rp2xxx = microzig.hal;
const time = rp2xxx.time;
const gpio = rp2xxx.gpio;
const i2c = rp2xxx.i2c;

const i2c0 = i2c.instance.num(0);

pub const OLED = microzig.drivers.display.sh1106.SH1106(.{
    .mode = .i2c,
    .Datagram_Device = rp2xxx.drivers.I2C_Datagram_Device,
});

pub fn init_oled_config() !OLED {
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
    // const SH1106_I2C = microzig.drivers.display.sh1106.SH1106(.{
    //     .mode = .i2c,
    //     .Datagram_Device = @TypeOf(i2c_dd),
    // });

    return try OLED.init(i2c_dd);
}
