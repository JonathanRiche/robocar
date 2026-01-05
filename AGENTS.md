# Agent Guidelines for Robocar

This document provides guidelines for AI coding agents working on the Robocar embedded systems project.

## Project Overview

Robocar is a Raspberry Pi Pico 2 W (RP2350) based robot car firmware written in Zig using the MicroZig framework. The project uses embedded systems programming patterns with hardware abstraction layers for peripherals like OLED displays, WS2812B LEDs, WiFi, and I2S microphones.

## Build Commands

### Standard Build
```bash
zig build
```

Outputs:
- `zig-out/firmware/robocar.uf2` - UF2 format for direct flashing
- `zig-out/firmware/robocar.elf` - ELF format for debugging

### Build with WiFi Credentials
```bash
zig build -Dssid="YourSSID" -Dpass="YourPassword"
```

### Clean Build
```bash
rm -rf zig-cache zig-out
zig build
```

### Flash to Device
1. Hold BOOTSEL button while plugging in Pico 2
2. Copy firmware: `cp zig-out/firmware/robocar.uf2 /path/to/RPI-RP2`

## Testing

Currently, the project has minimal test infrastructure. The `src/root.zig` contains example tests:

```bash
zig build test
```

**Note**: Testing embedded firmware is limited. Most validation happens on-device.

## Code Style Guidelines

### File Organization

- `src/main.zig` - Main firmware entry point
- `src/root.zig` - Root module for library exports and tests
- `src/hardware_config.zig` - Hardware initialization and pin configuration
- `src/modules/` - Reusable hardware driver modules

### Imports

Follow this consistent import order:
1. Standard library
2. MicroZig framework and HAL
3. External dependencies (font8x8, etc.)
4. Local modules

Example:
```zig
const std = @import("std");
const microzig = @import("microzig");
const rp2xxx = microzig.hal;
const time = rp2xxx.time;
const gpio = rp2xxx.gpio;

const font8x8 = @import("font8x8");
const hardware_config = @import("hardware_config.zig");
const oled = @import("modules/oled_SH1106.zig");
```

### Naming Conventions

- **Types/Structs**: PascalCase - `WS2812B`, `Text_Config`, `OLED`
- **Functions**: snake_case - `set_up_wifi()`, `init_oled_config()`, `set_color()`
- **Constants**: SCREAMING_SNAKE_CASE or PascalCase - `WIFI_SSID`, `EMPTY_ROW`, `Colors.RED`
- **Variables**: snake_case - `led_pin`, `clock_div`, `num_leds`
- **Module names**: snake_case - `led_ws2812b.zig`, `oled_SH1106.zig`

### Types

- Use explicit types for configuration: `u5`, `u8`, `u24`, `u32`, `f32`
- GPIO pins are typed as `gpio.Pin`
- Use `usize` for array lengths and indices
- Prefer `u24` for RGB colors (0xRRGGBB format)
- Use structs for configuration options with sensible defaults

Example:
```zig
pub const Config = struct {
    pin: u5 = 2,
    num_leds: usize = 4,
    clock_div: f32 = 15.625,
};
```

### Error Handling

- Use Zig's error union types: `!void`, `!Type`
- Use `try` for propagating errors upward
- Use `catch unreachable` only for genuinely unreachable error conditions
- Use `catch` with fallback values for recoverable errors
- Log errors with `std.log.err()` before returning

Example:
```zig
pub fn init(config: Config) !WS2812B {
    const sm = try pio_instance.claim_unused_state_machine();
    return WS2812B{ .pio_instance = pio_instance, .sm = sm, .config = config };
}

pub fn set_up_wifi() ![]const u8 {
    if (!wifi.is_connected()) {
        std.log.err("Connection timeout!", .{});
        return "Not Connected";
    }
    return "Connected";
}

// Genuinely unreachable
lcd.clear_screen(false) catch unreachable;
```

### Comments and Documentation

- Use `///` for public API documentation
- Use `//` for implementation comments
- Document hardware-specific details (timing, pins, protocols)
- Include references to datasheets where relevant
- Use `NOTE:` and `TODO:` prefixes for action items

Example:
```zig
/// WS2812B PIO Program
/// This implements the precise timing required for WS2812B:
/// - T0H: 0.4us (high for 0 bit)
/// - T0L: 0.85us (low for 0 bit)
const ws2812_program = blk: { ... };

//NOTE: These pins are for the i2s mic
const sck_pin = gpio.num(10);

//TODO: will add some type of controller loop later
```

### Formatting

- Use 4 spaces for indentation (Zig standard)
- Run `zig fmt` before committing (Zig auto-formats)
- Maximum line length: ~100 characters (not strict)
- Use blank lines to separate logical sections
- Align struct fields when it improves readability

### Hardware Patterns

#### Pin Configuration
```zig
const sda_pin = gpio.num(8);
const scl_pin = gpio.num(9);

inline for ([_]gpio.Pin{ sda_pin, scl_pin }) |pin| {
    pin.set_slew_rate(.slow);
    pin.set_schmitt_trigger_enabled(true);
    pin.set_function(.i2c);
}
```

#### PIO State Machines
```zig
const pio_instance = pio.num(0);
const sm = try pio_instance.claim_unused_state_machine();

try pio_instance.sm_load_and_start_program(sm, program, .{
    .clkdiv = clkdiv,
    .pin_mappings = .{ ... },
    .shift = .{ ... },
});

pio_instance.sm_set_enabled(sm, true);
```

#### Memory Management
```zig
// Use FixedBufferAllocator for embedded systems
const buffer_size = 200 * 1024; // 200 KB
var backing_buffer: [buffer_size]u8 = undefined;
var fba = std.heap.FixedBufferAllocator.init(&backing_buffer);

// Use ArenaAllocator for scoped allocations
var aa = std.heap.ArenaAllocator.init(fba.allocator());
defer aa.deinit();
```

## Dependencies

### Critical: MicroZig Version

**This project requires the latest MicroZig from the main branch** (not v0.15.0) for WiFi support.

MicroZig must be cloned as a sibling directory:
```
hardware/
├── robocar/     (this project)
└── microzig/    (latest main branch)
```

Configured in `build.zig.zon`:
```zig
.microzig = .{
    .path = "../microzig",
},
```

### External Dependencies
- **font8x8**: Git dependency for OLED text rendering
- **MicroZig**: Framework providing HAL and drivers

## Hardware Configuration

Current pin assignments in `src/hardware_config.zig`:

- **I2S Microphone**: GPIO 10 (SCK), 11 (WS), 12 (SD)
- **OLED Display**: GPIO 8 (SDA), 9 (SCL) - I2C0 @ 400kHz
- **WS2812B LEDs**: GPIO 2 (Data) - PIO0

Refer to `docs/Raspberry-Pi-Pico-2-W-Pinout.jpg` for complete pinout.

## Common Patterns

### Module Structure
Each hardware module should export:
1. Configuration struct with defaults
2. Driver struct with methods
3. Initialization function returning `!DriverType`
4. Public API methods

### Timing
Use `time.sleep_ms()` for delays (defined in `rp2xxx.time`).

Default sleep time: 1000-2000ms for display operations.

## Git Workflow

- Commit messages: Concise, descriptive (e.g., "Add WS2812B LED driver")
- No secrets in commits (WiFi credentials passed via build flags)
- Format code with `zig fmt` before committing
