const std = @import("std");
const microzig = @import("microzig");
const rp2xxx = microzig.hal;
const gpio = rp2xxx.gpio;
const clocks = rp2xxx.clocks;

/// I2S Microphone driver adapted from synth-workshop I2S implementation
/// Supports variable bit-depth (16/24/32-bit) samples for microphone input
/// Optimized for INMP441 microphone (24-bit output)
pub fn I2SMicrophone(comptime Sample: type, comptime args: struct {
    sample_rate: u32,
}) type {
    // Validate sample rate
    switch (args.sample_rate) {
        8_000,
        16_000,
        32_000,
        44_100,
        48_000,
        88_200,
        96_000,
        => {},
        else => @compileError("sample_rate must be 8kHz, 16kHz, 32kHz, 44.1kHz, 48kHz, 88.2kHz or 96kHz"),
    }

    // Validate sample type
    switch (Sample) {
        i16, i24, i32 => {},
        else => @compileError("Sample type must be i16, i24, or i32"),
    }

    const sample_width = @bitSizeOf(Sample);

    // Generate PIO program with dynamic sample width
    const output = comptime rp2xxx.pio.assemble(std.fmt.comptimePrint(
        \\.program i2s_rx
        \\.side_set 2
        \\
        \\.define SAMPLE_BITS {d}
        \\
        \\; I2S microphone input program (RX mode)
        \\; Side-set pins: bit 0 = SCK (bit clock), bit 1 = WS (word select)
        \\; IN pin: SD (serial data from microphone)
        \\; Pin order must be: [SCK, WS, SD] consecutive
        \\
        \\  set pindirs, 0x6         side 0x1 ; SCK=out, WS=out (0b110), SD=in
        \\.wrap_target
        \\  set x, (SAMPLE_BITS - 2) side 0x1 ; Load bit counter for left channel
        \\left_channel:
        \\  in pins, 1               side 0x0 ; Sample data bit, SCK=0, WS=0
        \\  jmp x-- left_channel     side 0x1 ; Loop, SCK=1
        \\  in pins, 1               side 0x2 ; Last bit of left, WS toggles
        \\
        \\  set x, (SAMPLE_BITS - 2) side 0x3 ; Load bit counter for right channel
        \\right_channel:
        \\  in pins, 1               side 0x2 ; Sample data bit, SCK=0, WS=1
        \\  jmp x-- right_channel    side 0x3 ; Loop, SCK=1
        \\  in pins, 1               side 0x0 ; Last bit of right, WS toggles back
        \\.wrap
    , .{sample_width}), .{});

    const i2s_program = comptime output.get_program_by_name("i2s_rx");

    return struct {
        pio: rp2xxx.pio.Pio,
        sm: rp2xxx.pio.StateMachine,

        const Self = @This();

        pub const InitOptions = struct {
            clock_config: clocks.GlobalConfiguration,
            clk_pin: gpio.Pin,
            word_select_pin: gpio.Pin,
            data_pin: gpio.Pin,
        };

        pub const StereoSample = struct {
            left: Sample,
            right: Sample,
        };

        /// Initialize I2S microphone with strict pin ordering
        /// Pins must be consecutive: [CLK, WS, DATA]
        pub fn init(pio_instance: rp2xxx.pio.Pio, comptime opts: InitOptions) Self {
            // Enforce consecutive pin ordering (same as synth-workshop)
            if (@intFromEnum(opts.word_select_pin) != @intFromEnum(opts.clk_pin) + 1)
                @panic("word select pin must be clk pin + 1");

            if (@intFromEnum(opts.data_pin) != @intFromEnum(opts.word_select_pin) + 1)
                @panic("data pin must be word_select pin + 1");

            // Initialize GPIO pins for PIO control
            pio_instance.gpio_init(opts.data_pin);
            pio_instance.gpio_init(opts.clk_pin);
            pio_instance.gpio_init(opts.word_select_pin);

            // Claim state machine
            const sm = pio_instance.claim_unused_state_machine() catch @panic("No available PIO state machine");

            // Calculate clock divider (2 PIO cycles per I2S clock cycle)
            const clkdiv = comptime rp2xxx.pio.ClkDivOptions.from_float(div: {
                const sys_clk_freq = @as(f32, @floatFromInt(opts.clock_config.sys.?.output_freq));
                const i2s_clk_freq = @as(f32, @floatFromInt(args.sample_rate * sample_width * 2));
                const pio_clk_freq = 2 * i2s_clk_freq;
                break :div sys_clk_freq / pio_clk_freq;
            });

            // Load and configure PIO program
            pio_instance.sm_load_and_start_program(sm, i2s_program, .{
                .clkdiv = clkdiv,
                .shift = .{
                    .autopush = true, // Auto-push to RX FIFO when threshold reached
                    .push_threshold = @as(u5, @truncate(sample_width)), // Push after N bits
                    .join_rx = true, // Join RX FIFOs for 8-entry buffer
                    .in_shiftdir = .left, // MSB first (I2S standard)
                },
                .pin_mappings = .{
                    .set = .{
                        .base = @intFromEnum(opts.clk_pin),
                        .count = 3, // Control all 3 pins (CLK, WS, DATA)
                    },
                    .side_set = .{
                        .base = @intFromEnum(opts.clk_pin),
                        .count = 2, // CLK and WS controlled via side-set
                    },
                    .in_base = @intFromEnum(opts.data_pin), // Data input pin
                },
            }) catch @panic("Failed to load I2S PIO program");

            pio_instance.sm_set_enabled(sm, true);

            return Self{
                .pio = pio_instance,
                .sm = sm,
            };
        }

        /// Check if samples are available in RX FIFO
        /// With joined RX FIFO, we want at least 2 entries (left + right)
        pub fn is_readable(self: Self) bool {
            return self.pio.sm_fifo_level(self.sm, .rx) >= 2;
        }

        /// Convert FIFO entry to sample value
        /// Handles alignment for different bit widths
        const UnsignedSample = std.meta.Int(.unsigned, @bitSizeOf(Sample));
        fn fifo_entry_to_sample(raw: u32) Sample {
            // I2S data is left-aligned in 32-bit word
            // Shift right to get proper alignment, then sign-extend
            const sample_shift = comptime 32 - sample_width;
            const unsigned_sample = @as(UnsignedSample, @truncate(raw >> sample_shift));
            return @as(Sample, @bitCast(unsigned_sample));
        }

        /// Read mono sample (blocking)
        /// Reads both channels but returns only left channel
        pub fn read_mono(self: Self) Sample {
            const left = self.pio.sm_blocking_read(self.sm);
            _ = self.pio.sm_blocking_read(self.sm); // Discard right channel
            return fifo_entry_to_sample(left);
        }

        /// Read stereo sample (blocking)
        pub fn read_stereo(self: Self) StereoSample {
            const left = self.pio.sm_blocking_read(self.sm);
            const right = self.pio.sm_blocking_read(self.sm);
            return StereoSample{
                .left = fifo_entry_to_sample(left),
                .right = fifo_entry_to_sample(right),
            };
        }

        /// Read stereo sample (non-blocking)
        /// Returns null if insufficient data available
        pub fn read_stereo_nonblocking(self: Self) ?StereoSample {
            if (!self.is_readable()) return null;

            const left = self.pio.sm_read(self.sm);
            const right = self.pio.sm_read(self.sm);
            return StereoSample{
                .left = fifo_entry_to_sample(left),
                .right = fifo_entry_to_sample(right),
            };
        }

        /// Get RX FIFO level (0-8 entries)
        pub fn get_fifo_level(self: Self) u4 {
            return self.pio.sm_fifo_level(self.sm, .rx);
        }

        /// Check if RX FIFO is empty
        pub fn is_fifo_empty(self: Self) bool {
            return self.pio.sm_is_rx_fifo_empty(self.sm);
        }

        /// Get mono audio by averaging left and right channels
        pub fn sample_to_mono(sample: StereoSample) Sample {
            // Average left and right channels
            const left_i32 = @as(i32, sample.left);
            const right_i32 = @as(i32, sample.right);
            const avg = @divTrunc(left_i32 + right_i32, 2);
            return @as(Sample, @truncate(avg));
        }

        /// Convert sample to normalized float [-1.0, 1.0]
        pub fn sample_to_float(sample: Sample) f32 {
            const max_value = comptime @as(f32, @floatFromInt((@as(i64, 1) << (sample_width - 1)) - 1));
            return @as(f32, @floatFromInt(sample)) / max_value;
        }

        /// Get peak amplitude from stereo sample
        pub fn get_peak_amplitude(sample: StereoSample) struct { left: Sample, right: Sample } {
            const abs_left = if (sample.left < 0) -sample.left else sample.left;
            const abs_right = if (sample.right < 0) -sample.right else sample.right;
            return .{ .left = abs_left, .right = abs_right };
        }

        /// Read multiple samples into a buffer (blocking)
        pub fn read_samples(self: Self, buffer: []StereoSample) void {
            for (buffer) |*sample| {
                sample.* = self.read_stereo();
            }
        }

        /// Read available samples into buffer (non-blocking)
        /// Returns number of samples actually read
        pub fn read_samples_available(self: Self, buffer: []StereoSample) usize {
            var count: usize = 0;
            for (buffer) |*sample| {
                if (self.read_stereo_nonblocking()) |s| {
                    sample.* = s;
                    count += 1;
                } else {
                    break;
                }
            }
            return count;
        }
    };
}

/// Common sample rate constants
pub const SampleRate = struct {
    pub const RATE_8KHZ: u32 = 8000;
    pub const RATE_16KHZ: u32 = 16000;
    pub const RATE_32KHZ: u32 = 32000;
    pub const RATE_44_1KHZ: u32 = 44100;
    pub const RATE_48KHZ: u32 = 48000;
    pub const RATE_88_2KHZ: u32 = 88200;
    pub const RATE_96KHZ: u32 = 96000;
};

// Example usage:
// const mic_i2s = @import("modules/mic_i2s.zig");
// const rp2xxx = microzig.hal;
//
// // For INMP441 (24-bit microphone)
// const I2S_Mic_24bit = mic_i2s.I2SMicrophone(i24, .{
//     .sample_rate = mic_i2s.SampleRate.RATE_16KHZ,
// });
//
// const microphone = I2S_Mic_24bit.init(rp2xxx.pio.num(0), .{
//     .clock_config = rp2xxx.clock_config,
//     .clk_pin = rp2xxx.gpio.num(10),
//     .word_select_pin = rp2xxx.gpio.num(11),
//     .data_pin = rp2xxx.gpio.num(12),
// });
//
// // Read audio samples
// while (true) {
//     const sample = microphone.read_stereo();
//     const mono = I2S_Mic_24bit.sample_to_mono(sample);
//     // Process audio...
// }
