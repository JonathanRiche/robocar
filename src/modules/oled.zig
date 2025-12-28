const std = @import("std");
const microzig = @import("microzig");
const rp2xxx = microzig.hal;
const i2c = rp2xxx.i2c;
const gpio = rp2xxx.gpio;

/// SSD1306 OLED Display Configuration
pub const Config = struct {
    /// I2C address (typically 0x3C or 0x3D)
    address: u7 = 0x3C,
    /// I2C bus to use (0 or 1)
    i2c_bus: u1 = 0,
    /// SDA pin (GPIO)
    sda_pin: u5 = 4,
    /// SCL pin (GPIO)
    scl_pin: u5 = 5,
    /// I2C baudrate in Hz
    baudrate: u32 = 400_000,
};

/// Display dimensions
pub const WIDTH: usize = 128;
pub const HEIGHT: usize = 64;
pub const PAGES: usize = HEIGHT / 8; // 8 pages
pub const BUFFER_SIZE: usize = WIDTH * PAGES; // 1024 bytes

/// SSD1306 Commands
const Command = enum(u8) {
    DISPLAY_OFF = 0xAE,
    DISPLAY_ON = 0xAF,
    SET_MEMORY_MODE = 0x20,
    SET_COLUMN_ADDR = 0x21,
    SET_PAGE_ADDR = 0x22,
    SET_START_LINE = 0x40,
    SET_CONTRAST = 0x81,
    CHARGE_PUMP = 0x8D,
    SEG_REMAP = 0xA1,
    SET_MULTIPLEX = 0xA8,
    COM_SCAN_DEC = 0xC8,
    SET_DISPLAY_OFFSET = 0xD3,
    SET_COM_PINS = 0xDA,
    SET_VCOM_DETECT = 0xDB,
    SET_DISPLAY_CLOCK = 0xD5,
    SET_PRECHARGE = 0xD9,
    NORMAL_DISPLAY = 0xA6,
    ENTIRE_DISPLAY_ON = 0xA4,
    SET_PAGE_START = 0xB0,
    SET_LOW_COLUMN = 0x00,
    SET_HIGH_COLUMN = 0x10,
};

/// SSD1306 OLED Display Driver
pub const SSD1306 = struct {
    config: Config,
    i2c_instance: i2c.I2C,
    framebuffer: [BUFFER_SIZE]u8,

    /// Initialize the SSD1306 display
    pub fn init(config: Config) !SSD1306 {
        // Configure I2C pins
        const sda_pin = gpio.num(config.sda_pin);
        const scl_pin = gpio.num(config.scl_pin);

        // Set pins to I2C function
        sda_pin.set_function(.i2c);
        scl_pin.set_function(.i2c);

        // Initialize I2C
        const i2c_instance = i2c.instance.num(config.i2c_bus);
        i2c_instance.apply(.{
            .clock_config = rp2xxx.clock_config,
        });

        // Set baudrate (assuming 125MHz system clock)
        try i2c_instance.set_baudrate(config.baudrate, 125_000_000);

        var display = SSD1306{
            .config = config,
            .i2c_instance = i2c_instance,
            .framebuffer = [_]u8{0} ** BUFFER_SIZE,
        };

        // Verify device is present
        try display.ping();

        // Run initialization sequence
        try display.init_sequence();

        return display;
    }

    /// Ping the device to check if it's present
    fn ping(self: *SSD1306) !void {
        // Try to write to the device address
        const test_data = [_]u8{0x00};
        const addr: i2c.Address = @enumFromInt(self.config.address);
        self.i2c_instance.write_blocking(addr, &test_data, null) catch {
            return error.DeviceNotFound;
        };
    }

    /// Send a command to the display
    fn send_command(self: *SSD1306, cmd: u8) !void {
        const data = [_]u8{ 0x00, cmd };
        const addr: i2c.Address = @enumFromInt(self.config.address);
        try self.i2c_instance.write_blocking(addr, &data, null);
    }

    /// Send multiple commands to the display
    fn send_commands(self: *SSD1306, cmds: []const u8) !void {
        for (cmds) |cmd| {
            try self.send_command(cmd);
        }
    }

    /// Initialize the display with the required command sequence
    fn init_sequence(self: *SSD1306) !void {
        // Display off
        try self.send_command(@intFromEnum(Command.DISPLAY_OFF));

        // Set memory addressing mode to horizontal
        try self.send_command(@intFromEnum(Command.SET_MEMORY_MODE));
        try self.send_command(0x00); // Horizontal addressing mode

        // Set page start address
        try self.send_command(@intFromEnum(Command.SET_PAGE_START));

        // Set COM output scan direction (flip vertically)
        try self.send_command(@intFromEnum(Command.COM_SCAN_DEC));

        // Set low column address
        try self.send_command(@intFromEnum(Command.SET_LOW_COLUMN));

        // Set high column address
        try self.send_command(@intFromEnum(Command.SET_HIGH_COLUMN));

        // Set display start line
        try self.send_command(@intFromEnum(Command.SET_START_LINE));

        // Set contrast
        try self.send_command(@intFromEnum(Command.SET_CONTRAST));
        try self.send_command(0x7F); // 127

        // Set segment re-map (flip horizontally)
        try self.send_command(@intFromEnum(Command.SEG_REMAP));

        // Set normal display
        try self.send_command(@intFromEnum(Command.NORMAL_DISPLAY));

        // Set multiplex ratio
        try self.send_command(@intFromEnum(Command.SET_MULTIPLEX));
        try self.send_command(0x3F); // 64

        // Output follows RAM content
        try self.send_command(@intFromEnum(Command.ENTIRE_DISPLAY_ON));

        // Set display offset
        try self.send_command(@intFromEnum(Command.SET_DISPLAY_OFFSET));
        try self.send_command(0x00);

        // Set display clock divide ratio
        try self.send_command(@intFromEnum(Command.SET_DISPLAY_CLOCK));
        try self.send_command(0x80);

        // Set pre-charge period
        try self.send_command(@intFromEnum(Command.SET_PRECHARGE));
        try self.send_command(0x22);

        // Set COM pins hardware configuration
        try self.send_command(@intFromEnum(Command.SET_COM_PINS));
        try self.send_command(0x12);

        // Set VCOMH deselect level
        try self.send_command(@intFromEnum(Command.SET_VCOM_DETECT));
        try self.send_command(0x20);

        // Enable charge pump (CRUCIAL!)
        try self.send_command(@intFromEnum(Command.CHARGE_PUMP));
        try self.send_command(0x14);

        // Display on
        try self.send_command(@intFromEnum(Command.DISPLAY_ON));
    }

    /// Clear the framebuffer (fill with zeros)
    pub fn clear(self: *SSD1306) void {
        @memset(&self.framebuffer, 0);
    }

    /// Fill the framebuffer with a specific pattern
    pub fn fill(self: *SSD1306, pattern: u8) void {
        @memset(&self.framebuffer, pattern);
    }

    /// Set a pixel at (x, y)
    pub fn set_pixel(self: *SSD1306, x: usize, y: usize, on: bool) void {
        if (x >= WIDTH or y >= HEIGHT) return;

        const page = y / 8;
        const bit = @as(u3, @intCast(y % 8));
        const index = page * WIDTH + x;

        if (on) {
            self.framebuffer[index] |= (@as(u8, 1) << bit);
        } else {
            self.framebuffer[index] &= ~(@as(u8, 1) << bit);
        }
    }

    /// Update the display with the current framebuffer content
    pub fn update(self: *SSD1306) !void {
        // Set column address range (0 to 127)
        try self.send_command(@intFromEnum(Command.SET_COLUMN_ADDR));
        try self.send_command(0);
        try self.send_command(127);

        // Set page address range (0 to 7)
        try self.send_command(@intFromEnum(Command.SET_PAGE_ADDR));
        try self.send_command(0);
        try self.send_command(7);

        // Send framebuffer data
        // Data writes start with 0x40
        var buffer: [BUFFER_SIZE + 1]u8 = undefined;
        buffer[0] = 0x40; // Data mode
        @memcpy(buffer[1..], &self.framebuffer);

        const addr: i2c.Address = @enumFromInt(self.config.address);
        try self.i2c_instance.write_blocking(addr, &buffer, null);
    }

    /// Draw a character at the given position
    pub fn draw_char(self: *SSD1306, x: usize, y: usize, char: u8) void {
        if (char < 32 or char > 126) return; // Only printable ASCII

        const font_index = char - 32;
        const char_data = &font5x7[font_index];

        for (char_data, 0..) |col, i| {
            const px = x + i;
            if (px >= WIDTH) break;

            for (0..7) |bit| {
                const py = y + bit;
                if (py >= HEIGHT) break;

                const pixel_on = (col & (@as(u8, 1) << @as(u3, @intCast(bit)))) != 0;
                self.set_pixel(px, py, pixel_on);
            }
        }
    }

    /// Draw a string at the given position
    pub fn draw_string(self: *SSD1306, x: usize, y: usize, text: []const u8) void {
        var cursor_x = x;
        for (text) |char| {
            if (cursor_x + 6 > WIDTH) break; // Character + spacing
            self.draw_char(cursor_x, y, char);
            cursor_x += 6; // 5 pixels + 1 pixel spacing
        }
    }

    /// Draw a string centered on the screen
    pub fn draw_string_centered(self: *SSD1306, y: usize, text: []const u8) void {
        const text_width = text.len * 6; // 5 pixels per char + 1 spacing
        if (text_width >= WIDTH) {
            self.draw_string(0, y, text);
            return;
        }
        const x = (WIDTH - text_width) / 2;
        self.draw_string(x, y, text);
    }
};

/// 5x7 Font Data for ASCII characters 32-126
/// Each character is represented by 5 bytes (columns)
/// Each byte represents 8 vertical pixels (LSB at top)
const font5x7 = [_][5]u8{
    .{ 0x00, 0x00, 0x00, 0x00, 0x00 }, // Space (32)
    .{ 0x00, 0x00, 0x5F, 0x00, 0x00 }, // !
    .{ 0x00, 0x07, 0x00, 0x07, 0x00 }, // "
    .{ 0x14, 0x7F, 0x14, 0x7F, 0x14 }, // #
    .{ 0x24, 0x2A, 0x7F, 0x2A, 0x12 }, // $
    .{ 0x23, 0x13, 0x08, 0x64, 0x62 }, // %
    .{ 0x36, 0x49, 0x55, 0x22, 0x50 }, // &
    .{ 0x00, 0x05, 0x03, 0x00, 0x00 }, // '
    .{ 0x00, 0x1C, 0x22, 0x41, 0x00 }, // (
    .{ 0x00, 0x41, 0x22, 0x1C, 0x00 }, // )
    .{ 0x14, 0x08, 0x3E, 0x08, 0x14 }, // *
    .{ 0x08, 0x08, 0x3E, 0x08, 0x08 }, // +
    .{ 0x00, 0x50, 0x30, 0x00, 0x00 }, // ,
    .{ 0x08, 0x08, 0x08, 0x08, 0x08 }, // -
    .{ 0x00, 0x60, 0x60, 0x00, 0x00 }, // .
    .{ 0x20, 0x10, 0x08, 0x04, 0x02 }, // /
    .{ 0x3E, 0x51, 0x49, 0x45, 0x3E }, // 0
    .{ 0x00, 0x42, 0x7F, 0x40, 0x00 }, // 1
    .{ 0x42, 0x61, 0x51, 0x49, 0x46 }, // 2
    .{ 0x21, 0x41, 0x45, 0x4B, 0x31 }, // 3
    .{ 0x18, 0x14, 0x12, 0x7F, 0x10 }, // 4
    .{ 0x27, 0x45, 0x45, 0x45, 0x39 }, // 5
    .{ 0x3C, 0x4A, 0x49, 0x49, 0x30 }, // 6
    .{ 0x01, 0x71, 0x09, 0x05, 0x03 }, // 7
    .{ 0x36, 0x49, 0x49, 0x49, 0x36 }, // 8
    .{ 0x06, 0x49, 0x49, 0x29, 0x1E }, // 9
    .{ 0x00, 0x36, 0x36, 0x00, 0x00 }, // :
    .{ 0x00, 0x56, 0x36, 0x00, 0x00 }, // ;
    .{ 0x08, 0x14, 0x22, 0x41, 0x00 }, // <
    .{ 0x14, 0x14, 0x14, 0x14, 0x14 }, // =
    .{ 0x00, 0x41, 0x22, 0x14, 0x08 }, // >
    .{ 0x02, 0x01, 0x51, 0x09, 0x06 }, // ?
    .{ 0x32, 0x49, 0x79, 0x41, 0x3E }, // @
    .{ 0x7E, 0x11, 0x11, 0x11, 0x7E }, // A
    .{ 0x7F, 0x49, 0x49, 0x49, 0x36 }, // B
    .{ 0x3E, 0x41, 0x41, 0x41, 0x22 }, // C
    .{ 0x7F, 0x41, 0x41, 0x22, 0x1C }, // D
    .{ 0x7F, 0x49, 0x49, 0x49, 0x41 }, // E
    .{ 0x7F, 0x09, 0x09, 0x09, 0x01 }, // F
    .{ 0x3E, 0x41, 0x49, 0x49, 0x7A }, // G
    .{ 0x7F, 0x08, 0x08, 0x08, 0x7F }, // H
    .{ 0x00, 0x41, 0x7F, 0x41, 0x00 }, // I
    .{ 0x20, 0x40, 0x41, 0x3F, 0x01 }, // J
    .{ 0x7F, 0x08, 0x14, 0x22, 0x41 }, // K
    .{ 0x7F, 0x40, 0x40, 0x40, 0x40 }, // L
    .{ 0x7F, 0x02, 0x0C, 0x02, 0x7F }, // M
    .{ 0x7F, 0x04, 0x08, 0x10, 0x7F }, // N
    .{ 0x3E, 0x41, 0x41, 0x41, 0x3E }, // O
    .{ 0x7F, 0x09, 0x09, 0x09, 0x06 }, // P
    .{ 0x3E, 0x41, 0x51, 0x21, 0x5E }, // Q
    .{ 0x7F, 0x09, 0x19, 0x29, 0x46 }, // R
    .{ 0x46, 0x49, 0x49, 0x49, 0x31 }, // S
    .{ 0x01, 0x01, 0x7F, 0x01, 0x01 }, // T
    .{ 0x3F, 0x40, 0x40, 0x40, 0x3F }, // U
    .{ 0x1F, 0x20, 0x40, 0x20, 0x1F }, // V
    .{ 0x3F, 0x40, 0x38, 0x40, 0x3F }, // W
    .{ 0x63, 0x14, 0x08, 0x14, 0x63 }, // X
    .{ 0x07, 0x08, 0x70, 0x08, 0x07 }, // Y
    .{ 0x61, 0x51, 0x49, 0x45, 0x43 }, // Z
    .{ 0x00, 0x7F, 0x41, 0x41, 0x00 }, // [
    .{ 0x02, 0x04, 0x08, 0x10, 0x20 }, // Backslash
    .{ 0x00, 0x41, 0x41, 0x7F, 0x00 }, // ]
    .{ 0x04, 0x02, 0x01, 0x02, 0x04 }, // ^
    .{ 0x40, 0x40, 0x40, 0x40, 0x40 }, // _
    .{ 0x00, 0x01, 0x02, 0x04, 0x00 }, // `
    .{ 0x20, 0x54, 0x54, 0x54, 0x78 }, // a
    .{ 0x7F, 0x48, 0x44, 0x44, 0x38 }, // b
    .{ 0x38, 0x44, 0x44, 0x44, 0x20 }, // c
    .{ 0x38, 0x44, 0x44, 0x48, 0x7F }, // d
    .{ 0x38, 0x54, 0x54, 0x54, 0x18 }, // e
    .{ 0x08, 0x7E, 0x09, 0x01, 0x02 }, // f
    .{ 0x0C, 0x52, 0x52, 0x52, 0x3E }, // g
    .{ 0x7F, 0x08, 0x04, 0x04, 0x78 }, // h
    .{ 0x00, 0x44, 0x7D, 0x40, 0x00 }, // i
    .{ 0x20, 0x40, 0x44, 0x3D, 0x00 }, // j
    .{ 0x7F, 0x10, 0x28, 0x44, 0x00 }, // k
    .{ 0x00, 0x41, 0x7F, 0x40, 0x00 }, // l
    .{ 0x7C, 0x04, 0x18, 0x04, 0x78 }, // m
    .{ 0x7C, 0x08, 0x04, 0x04, 0x78 }, // n
    .{ 0x38, 0x44, 0x44, 0x44, 0x38 }, // o
    .{ 0x7C, 0x14, 0x14, 0x14, 0x08 }, // p
    .{ 0x08, 0x14, 0x14, 0x18, 0x7C }, // q
    .{ 0x7C, 0x08, 0x04, 0x04, 0x08 }, // r
    .{ 0x48, 0x54, 0x54, 0x54, 0x20 }, // s
    .{ 0x04, 0x3F, 0x44, 0x40, 0x20 }, // t
    .{ 0x3C, 0x40, 0x40, 0x20, 0x7C }, // u
    .{ 0x1C, 0x20, 0x40, 0x20, 0x1C }, // v
    .{ 0x3C, 0x40, 0x30, 0x40, 0x3C }, // w
    .{ 0x44, 0x28, 0x10, 0x28, 0x44 }, // x
    .{ 0x0C, 0x50, 0x50, 0x50, 0x3C }, // y
    .{ 0x44, 0x64, 0x54, 0x4C, 0x44 }, // z
    .{ 0x00, 0x08, 0x36, 0x41, 0x00 }, // {
    .{ 0x00, 0x00, 0x7F, 0x00, 0x00 }, // |
    .{ 0x00, 0x41, 0x36, 0x08, 0x00 }, // }
    .{ 0x10, 0x08, 0x08, 0x10, 0x08 }, // ~
};
