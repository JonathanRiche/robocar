const std = @import("std");
const microzig = @import("microzig");
const rp2xxx = microzig.hal;
const gpio = rp2xxx.gpio;
const pio = rp2xxx.pio;

/// WS2812B Configuration
pub const Config = struct {
    /// GPIO pin for data output
    pin: u5 = 2,
    /// Number of LEDs in the strip
    num_leds: usize = 4,
    /// Clock divider for timing
    /// - 15.625 for 125MHz system clock
    /// - 18.75 for 150MHz system clock
    clock_div: f32 = 15.625,
};

/// WS2812B PIO Program
/// This implements the precise timing required for WS2812B:
/// - T0H: 0.4us (high for 0 bit)
/// - T0L: 0.85us (low for 0 bit)
/// - T1H: 0.8us (high for 1 bit)
/// - T1L: 0.45us (low for 1 bit)
const ws2812_program = blk: {
    @setEvalBranchQuota(10000);
    break :blk pio.assemble(
        \\.program ws2812
        \\.side_set 1
        \\
        \\.wrap_target
        \\out x, 1       side 0 [2]
        \\jmp !x do_zero side 1 [1]
        \\do_one:
        \\jmp  bitloop   side 1 [4]
        \\do_zero:
        \\nop            side 0 [4]
        \\bitloop:
        \\.wrap
    , .{});
};

/// WS2812B Driver
pub const WS2812B = struct {
    pio_instance: pio.Pio,
    sm: pio.StateMachine,
    config: Config,

    /// Initialize the WS2812B driver with the given configuration
    pub fn init(config: Config) !WS2812B {
        // Use PIO0
        const pio_instance = pio.num(0);

        // Claim an unused state machine
        const sm = try pio_instance.claim_unused_state_machine();

        // Configure GPIO pin for PIO use
        const led_pin = gpio.num(config.pin);
        led_pin.set_function(.pio0);

        // Calculate clock divider for 800kHz signal
        // The PIO program uses 10 cycles per bit
        // WS2812B needs 800kHz (1.25us per bit)
        //
        // If system is 125MHz: 125MHz / (10 * 800kHz) = 15.625
        // If system is 150MHz: 150MHz / (10 * 800kHz) = 18.75
        const clkdiv = pio.ClkDivOptions.from_float(config.clock_div);

        // Load and start the PIO program
        try pio_instance.sm_load_and_start_program(sm, ws2812_program.get_program_by_name("ws2812"), .{
            .clkdiv = clkdiv,
            .pin_mappings = .{
                .side_set = .{
                    .base = config.pin,
                    .count = 1,
                },
            },
            .shift = .{
                .autopull = true,
                .pull_threshold = 24, // Pull every 24 bits (GRB)
                .out_shiftdir = .left, // Shift out MSB first
            },
        });

        // Enable the state machine
        pio_instance.sm_set_enabled(sm, true);

        return WS2812B{
            .pio_instance = pio_instance,
            .sm = sm,
            .config = config,
        };
    }

    /// Set a single LED color
    /// Color format: 0xRRGGBB (standard RGB)
    /// WS2812B expects GRB order
    pub fn set_color(self: *const WS2812B, rgb: u24) void {
        // Convert RGB to GRB
        const r = (rgb >> 16) & 0xFF;
        const g = (rgb >> 8) & 0xFF;
        const b = rgb & 0xFF;
        const grb: u32 = (@as(u32, g) << 16) | (@as(u32, r) << 8) | b;

        // Shift left by 8 bits because we're sending 24 bits
        const grb_shifted = grb << 8;

        // Write to PIO FIFO (will block if FIFO is full)
        self.pio_instance.sm_blocking_write(self.sm, grb_shifted);
    }

    /// Set color with separate R, G, B values (0-255)
    pub fn set_rgb(self: *const WS2812B, r: u8, g: u8, b: u8) void {
        const rgb: u24 = (@as(u24, r) << 16) | (@as(u24, g) << 8) | b;
        self.set_color(rgb);
    }

    /// Set all LEDs to the same color
    pub fn fill(self: *const WS2812B, rgb: u24) void {
        for (0..self.config.num_leds) |_| {
            self.set_color(rgb);
        }
    }

    /// Turn off all LEDs
    pub fn clear(self: *const WS2812B) void {
        self.fill(0x000000);
    }
};

/// Common color constants
pub const Colors = struct {
    pub const RED: u24 = 0xFF0000;
    pub const GREEN: u24 = 0x00FF00;
    pub const BLUE: u24 = 0x0000FF;
    pub const YELLOW: u24 = 0xFFFF00;
    pub const MAGENTA: u24 = 0xFF00FF;
    pub const CYAN: u24 = 0x00FFFF;
    pub const WHITE: u24 = 0xFFFFFF;
    pub const OFF: u24 = 0x000000;
    pub const ORANGE: u24 = 0xFF8000;
    pub const PURPLE: u24 = 0x8000FF;
    pub const PINK: u24 = 0xFF0080;
};
