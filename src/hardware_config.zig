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

pub fn init_i2s_mic_config() void {
    //NOTE: These pins are for the i2s mic
    //Serial clock pin
    const sck_pin = gpio.num(10);
    // //Word select pin
    const ws_pin = gpio.num(11);
    // //Serial data pin
    const sd_pin = gpio.num(12);
    //
    const pin_array = [_]gpio.Pin{ sck_pin, ws_pin, sd_pin };
    inline for (pin_array) |pin| {
        // pin.set_slew_rate(.fast);
        // pin.set_schmitt_trigger_enabled(true);
        pin.set_function(.pio0);
    }
}

pub fn init_oled_config() !OLED {

    //NOTE: These pins are for oled display
    const sda_pin = gpio.num(8);
    const scl_pin = gpio.num(9);

    const pin_array = [_]gpio.Pin{ sda_pin, scl_pin };

    inline for (pin_array) |pin| {
        pin.set_slew_rate(.slow);
        pin.set_schmitt_trigger_enabled(true);
        pin.set_function(.i2c);
    }

    rp2xxx.i2c.I2C.apply(i2c0, .{ .baud_rate = 400_000, .clock_config = rp2xxx.clock_config });

    const i2c_dd = rp2xxx.drivers.I2C_Datagram_Device.init(i2c0, @enumFromInt(0x3C), null);

    return try OLED.init(i2c_dd);
}
