# I2S Microphone Module Usage Guide

## Overview

The `mic_i2s.zig` module provides a PIO-based I2S microphone driver for the Raspberry Pi Pico 2. It uses the Programmable I/O (PIO) to generate precise I2S timing signals and capture audio data from MEMS I2S microphones.

## Hardware Setup

### Pin Configuration (Already set in main.zig)

| Signal | GPIO Pin | Direction | Description |
|--------|----------|-----------|-------------|
| SCK (BCLK) | GPIO 10 | Output | Bit Clock - synchronizes data transmission |
| WS (LRCLK) | GPIO 11 | Output | Word Select - left/right channel indicator |
| SD (DOUT) | GPIO 12 | Input | Serial Data - audio data from microphone |

### Typical MEMS I2S Microphone Wiring

```
MEMS I2S Mic          Pico 2 W
------------          ---------
VDD         ------>   3.3V
GND         ------>   GND
SCK/BCLK    <------   GPIO 10
WS/LRCLK    <------   GPIO 11  
SD/DOUT     ------>   GPIO 12
```

**Common I2S Microphones:**
- Adafruit I2S MEMS Microphone Breakout (SPH0645LM4H)
- Sparkfun MEMS Microphone Breakout (INMP441)
- Other I2S MEMS microphones

## Basic Usage

### 1. Import the Module

```zig
const i2s_mic = @import("modules/mic_i2s.zig");
```

### 2. Initialize with Default Settings (16kHz, 16-bit)

```zig
pub fn main() void {
    // Initialize I2S microphone with default config
    const mic = i2s_mic.I2SMic.init(.{}) catch unreachable;
    
    // Your code here...
}
```

### 3. Read Audio Samples

#### Blocking Read (waits for data)

```zig
// Read a single stereo sample
const sample = mic.read_sample();
std.debug.print("Left: {}, Right: {}\n", .{sample.left, sample.right});

// Convert to mono
const mono = i2s_mic.I2SMic.sample_to_mono(sample);
```

#### Non-Blocking Read (returns null if no data)

```zig
if (mic.read_sample_nonblocking()) |sample| {
    // Process sample
    std.debug.print("Got sample: L={}, R={}\n", .{sample.left, sample.right});
} else {
    // No data available yet
}
```

### 4. Read Multiple Samples into Buffer

```zig
// Allocate buffer for samples
var sample_buffer: [256]i2s_mic.Sample = undefined;

// Blocking read - fills entire buffer
const count = mic.read_samples(&sample_buffer);
std.debug.print("Read {} samples\n", .{count});

// Non-blocking read - reads only available samples
const available_count = mic.read_samples_available(&sample_buffer);
std.debug.print("Read {} available samples\n", .{available_count});
```

## Configuration Options

### Using Preset Sample Rates

```zig
const mic = i2s_mic.I2SMic.init(.{
    .sample_rate = i2s_mic.SampleRate.RATE_44KHZ,  // 44.1kHz
    .bits_per_sample = 16,
}) catch unreachable;
```

**Available Presets:**
- `RATE_8KHZ` - 8000 Hz (voice, low quality)
- `RATE_16KHZ` - 16000 Hz (voice, good quality) **[DEFAULT]**
- `RATE_22KHZ` - 22050 Hz (music, medium quality)
- `RATE_44KHZ` - 44100 Hz (CD quality audio)
- `RATE_48KHZ` - 48000 Hz (professional audio)

### Custom Configuration

```zig
const mic = i2s_mic.I2SMic.init(.{
    .sck_pin = 10,              // Serial clock pin
    .ws_pin = 11,               // Word select pin
    .sd_pin = 12,               // Serial data pin
    .sample_rate = 16000,       // 16kHz sample rate
    .bits_per_sample = 16,      // 16-bit samples
    .clock_div = 0.0,           // 0 = auto-calculate, or manual override
    .system_clock_hz = 150_000_000,  // RP2350 @ 150MHz
}) catch unreachable;
```

### Manual Clock Divider (Advanced)

If you know your exact system clock and want to manually set the divider:

```zig
// Formula: clkdiv = System_Clock / (bits_per_sample × 2 × sample_rate)
// Example for 150MHz @ 16kHz 16-bit:
// clkdiv = 150_000_000 / (16 × 2 × 16000) = 292.97

const mic = i2s_mic.I2SMic.init(.{
    .clock_div = 292.97,        // Manual override
    .sample_rate = 16000,
    .bits_per_sample = 16,
}) catch unreachable;
```

## Audio Processing Functions

### Check for Available Data

```zig
if (mic.is_data_available()) {
    // Data is ready to read
    const sample = mic.read_sample();
}
```

### Get FIFO Level

```zig
const level = mic.get_fifo_level();  // Returns 0-8 (number of samples in buffer)
```

### Convert to Mono

```zig
const sample = mic.read_sample();
const mono = i2s_mic.I2SMic.sample_to_mono(sample);  // Average of L+R
```

### Convert to Float [-1.0, 1.0]

```zig
const sample = mic.read_sample();
const left_float = i2s_mic.I2SMic.sample_to_float(sample.left);
const right_float = i2s_mic.I2SMic.sample_to_float(sample.right);
```

### Get Peak Amplitude

```zig
var buffer: [1024]i2s_mic.Sample = undefined;
_ = mic.read_samples(&buffer);

const peak = i2s_mic.I2SMic.get_peak_amplitude(&buffer);
std.debug.print("Peak - L: {}, R: {}\n", .{peak.left, peak.right});
```

### Get RMS Amplitude (Volume Level)

```zig
var buffer: [1024]i2s_mic.Sample = undefined;
_ = mic.read_samples(&buffer);

const rms = i2s_mic.I2SMic.get_rms_amplitude(&buffer);
std.debug.print("RMS - L: {}, R: {}\n", .{rms.left, rms.right});

// RMS is useful for volume meters and voice activity detection
```

## Complete Example: Audio Level Meter

```zig
const std = @import("std");
const microzig = @import("microzig");
const i2s_mic = @import("modules/mic_i2s.zig");
const time = microzig.hal.time;

pub fn main() void {
    // Initialize microphone
    const mic = i2s_mic.I2SMic.init(.{
        .sample_rate = i2s_mic.SampleRate.RATE_16KHZ,
    }) catch unreachable;
    
    // Buffer for 100ms of audio at 16kHz = 1600 samples
    var buffer: [1600]i2s_mic.Sample = undefined;
    
    while (true) {
        // Read samples
        _ = mic.read_samples(&buffer);
        
        // Calculate RMS amplitude
        const rms = i2s_mic.I2SMic.get_rms_amplitude(&buffer);
        
        // Convert to percentage (0-100)
        const volume_left = (rms.left * 100) / 32767;
        const volume_right = (rms.right * 100) / 32767;
        
        std.debug.print("Volume - L: {}% R: {}%\n", .{volume_left, volume_right});
        
        time.sleep_ms(100);  // Update every 100ms
    }
}
```

## Complete Example: Voice Activity Detection

```zig
pub fn main() void {
    const mic = i2s_mic.I2SMic.init(.{}) catch unreachable;
    var buffer: [320]i2s_mic.Sample = undefined;  // 20ms at 16kHz
    
    const VOICE_THRESHOLD: u32 = 1000;  // Adjust based on your microphone
    
    while (true) {
        _ = mic.read_samples(&buffer);
        const rms = i2s_mic.I2SMic.get_rms_amplitude(&buffer);
        
        // Average both channels
        const avg_rms = (rms.left + rms.right) / 2;
        
        if (avg_rms > VOICE_THRESHOLD) {
            std.debug.print("Voice detected! Level: {}\n", .{avg_rms});
        }
        
        time.sleep_ms(20);
    }
}
```

## Data Format

### Sample Structure

```zig
pub const Sample = struct {
    left: i32,    // Left channel: -32768 to 32767 (16-bit signed)
    right: i32,   // Right channel: -32768 to 32767 (16-bit signed)
};
```

**Note:** Many I2S microphones are mono and output the same data on both channels. Check your microphone's datasheet.

### Raw Data Format

The PIO program captures data as 32-bit words:
- Bits [31:16] - Left channel
- Bits [15:0] - Right channel

## Troubleshooting

### No Audio Data

1. **Check pin connections** - Verify GPIO 10, 11, 12 are connected correctly
2. **Check power** - Ensure microphone has 3.3V and GND connected
3. **Check L/R pin** - Some microphones need L/R pin tied to GND or VDD to select channel
4. **Verify sample rate** - Try different sample rates (8kHz, 16kHz, 44.1kHz)

### Noisy Audio

1. **Add decoupling capacitor** - 0.1µF near microphone VDD pin
2. **Check clock divider** - Ensure system clock is correctly configured
3. **Shorten wires** - Keep connections short to reduce noise pickup

### Wrong Sample Rate

The auto-calculated clock divider assumes:
- RP2350 running at 150MHz
- If your system runs at 125MHz, set `system_clock_hz = 125_000_000`

## PIO Resource Usage

- **PIO Block**: PIO0 (can be changed to PIO1 or PIO2 in code)
- **State Machines**: 1 SM required
- **Instruction Memory**: 8 instructions
- **GPIO Pins**: 3 pins (SCK, WS, SD)

## References

- [RP2350 Datasheet - PIO Chapter](https://datasheets.raspberrypi.com/rp2350/rp2350-datasheet.pdf)
- [I2S Bus Specification](https://www.sparkfun.com/datasheets/BreakoutBoards/I2SBUS.pdf)
- [SPH0645LM4H Microphone Datasheet](https://cdn-learn.adafruit.com/assets/assets/000/049/977/original/SPH0645LM4H-B.pdf)

## API Reference

| Function | Description | Blocking |
|----------|-------------|----------|
| `init(config)` | Initialize I2S microphone | No |
| `is_data_available()` | Check if data ready | No |
| `read_sample()` | Read one stereo sample | Yes |
| `read_sample_nonblocking()` | Read one sample if available | No |
| `read_samples(buffer)` | Fill buffer with samples | Yes |
| `read_samples_available(buffer)` | Read available samples | No |
| `get_fifo_level()` | Get RX FIFO level (0-8) | No |
| `sample_to_mono(sample)` | Convert stereo to mono | No |
| `sample_to_float(value)` | Convert to float [-1.0, 1.0] | No |
| `get_peak_amplitude(buffer)` | Get peak values | No |
| `get_rms_amplitude(buffer)` | Get RMS volume level | No |
