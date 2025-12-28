# WS2812B LED Setup Guide

This guide explains how to set up and use WS2812B addressable RGB LEDs with the Raspberry Pi Pico 2.

## Hardware Connections

### Wiring Diagram

| WS2812B Pin | Pico 2 Pin | Description |
|-------------|-----------|-------------|
| DIN (Data) | GPIO 2 (Physical Pin 4) | Data signal |
| VCC | VBUS (Physical Pin 40) | 5V power |
| GND | GND (Physical Pin 3) | Ground |

### Important Notes

- **Power**: WS2812B LEDs require 5V. Use VBUS which provides USB 5V power.
- **Current**: Each LED can draw up to 60mA at full white brightness. For multiple LEDs, consider external power.
- **Level Shifting**: The Pico outputs 3.3V logic, but WS2812B typically works fine with 3.3V data signals. For long runs or many LEDs, consider a level shifter.

## Software Implementation

### PIO (Programmable I/O)

The WS2812B requires precise timing (800kHz) that cannot be reliably achieved with CPU bit-banging. The Pico's PIO state machine handles this perfectly.

### Timing Requirements

WS2812B uses the following timing (at 800kHz):

| Signal | High Time | Low Time | Total |
|--------|-----------|----------|-------|
| 0 bit | 0.4µs | 0.85µs | 1.25µs |
| 1 bit | 0.8µs | 0.45µs | 1.25µs |

### Clock Configuration

The PIO program is configured with:
- System clock: 150MHz (RP2350 default)
- Clock divider: 18.75
- This gives us: 150MHz / 18.75 = 8MHz
- Each PIO instruction at 8MHz takes: 125ns
- With 10 cycles per bit: 10 × 125ns = 1.25µs (800kHz) ✓

### Color Format

- **Input format**: RGB (0xRRGGBB) - standard hex color codes
- **WS2812B expects**: GRB order
- **Conversion**: The driver automatically converts RGB to GRB

Example colors:
```zig
0xFF0000  // Red
0x00FF00  // Green
0x0000FF  // Blue
0xFFFF00  // Yellow
0xFF00FF  // Magenta
0x00FFFF  // Cyan
0xFFFFFF  // White
```

## Code Structure

### WS2812B Driver

The `WS2812B` struct in `main.zig` provides:

```zig
pub fn init() !WS2812B
```
Initializes the PIO state machine and configures GPIO.

```zig
pub fn set_color(self: *const WS2812B, rgb: u24) void
```
Sets LED color using standard RGB hex value (e.g., 0xFF0000 for red).

```zig
pub fn set_rgb(self: *const WS2812B, r: u8, g: u8, b: u8) void
```
Sets LED color using separate R, G, B values (0-255 each).

### PIO Program

The PIO assembly program (`ws2812_program`):

```
.program ws2812
.side_set 1

.wrap_target
out x, 1       side 0 [2]  ; Output 1 bit, side-set low, delay 2
jmp !x do_zero side 1 [1]  ; If bit is 0, jump; side-set high, delay 1
do_one:
jmp  bitloop   side 1 [4]  ; Continue high for 1 bit (total ~0.8µs)
do_zero:
nop            side 0 [4]  ; Drive low for 0 bit (total ~0.4µs)
bitloop:
.wrap
```

The side-set pin controls the data output while the delays create the precise timing.

## Usage Example

```zig
const ws2812 = try WS2812B.init();

// Set to red
ws2812.set_color(0xFF0000);

// Set to green using RGB values
ws2812.set_rgb(0, 255, 0);

// Cycle through colors
const colors = [_]u24{
    0xFF0000, // Red
    0x00FF00, // Green
    0x0000FF, // Blue
};

for (colors) |color| {
    ws2812.set_color(color);
    time.sleep_ms(500);
}
```

## Flashing the Firmware

1. Build the firmware:
   ```bash
   zig build
   ```

2. Put Pico 2 into BOOTSEL mode:
   - Hold the BOOTSEL button
   - Plug in USB cable
   - Release BOOTSEL button

3. Copy the UF2 file:
   ```bash
   cp zig-out/firmware/robocar.uf2 /path/to/RPI-RP2/
   ```

4. The Pico will automatically reboot and start running your code.

## Multiple LEDs

To control multiple LEDs, modify `NUM_LEDS` in `main.zig` and call `set_color()` multiple times:

```zig
const NUM_LEDS = 8;

// Set all LEDs to different colors
for (0..NUM_LEDS) |i| {
    const hue = @as(u24, @intCast(i * 255 / NUM_LEDS));
    ws2812.set_color(hue_to_rgb(hue));
}
```

Each `set_color()` call sends 24 bits of data, so multiple calls will address subsequent LEDs in the chain.

## Troubleshooting

### No light output
- Check power connections (5V and GND)
- Verify data is connected to GPIO 2
- Ensure LED strip is powered adequately
- Check LED orientation (DIN vs DOUT)

### Wrong colors
- Verify you're using RGB format (not GRB)
- Check if your LED strips need a different format
- Some WS2812 variants use different protocols

### Flickering
- Add a capacitor (100-1000µF) across power and ground near the LEDs
- Ensure stable power supply
- Check for loose connections

### Only first LED works
- Ensure data cascades through (DOUT of LED1 → DIN of LED2)
- Check for damaged LEDs in the chain
- Verify power is sufficient for all LEDs

## References

- [WS2812B Datasheet](https://cdn-shop.adafruit.com/datasheets/WS2812B.pdf)
- [RP2350 PIO Guide](https://datasheets.raspberrypi.com/rp2350/rp2350-datasheet.pdf#%5B%7B%22num%22%3A683%2C%22gen%22%3A0%7D%2C%7B%22name%22%3A%22XYZ%22%7D%2C115%2C718.013%2Cnull%5D)
- [MicroZig Documentation](https://github.com/ZigEmbeddedGroup/microzig)
