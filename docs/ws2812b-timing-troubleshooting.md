# WS2812B Timing Troubleshooting Guide

## The Problem: Clock Speed Uncertainty

The WS2812B LEDs require **very precise timing** (800kHz ±150kHz tolerance). If the RP2350's system clock isn't what we expect, the timing will be wrong and the LEDs won't work.

## Possible Clock Speeds

The RP2350 can run at different speeds:
- **125 MHz** - Common default, same as RP2040
- **150 MHz** - RP2350's rated maximum
- **Other** - Could be configured differently

## Current Configuration

The code is now set for **125 MHz** with a clock divider of **15.625**:

```
125 MHz ÷ (10 cycles × 800 kHz) = 15.625
```

## If LEDs Still Don't Work: Try These Values

Edit `src/main.zig` and change this line:

```zig
const clkdiv = pio.ClkDivOptions.from_float(15.625);
```

### Try These Values in Order:

| Clock Divider | Assumed System Clock | Notes |
|---------------|---------------------|-------|
| **15.625** | 125 MHz | Current setting (most likely) |
| **18.75** | 150 MHz | RP2350 maximum speed |
| **12.5** | 100 MHz | Conservative/underclocked |
| **16.0** | 128 MHz | Close to 125 MHz |
| **20.0** | 160 MHz | Overclocked? |

### How to Test

1. Change the `clkdiv` value
2. Rebuild: `zig build`
3. Flash the new firmware
4. Check if LEDs work

If one of these values makes the LEDs work, that tells you what clock speed your Pico is actually running at!

## Why This Happens

Without explicit clock initialization code, the RP2350 uses its default boot clock, which might be:
- Set by the bootloader
- Affected by your power supply
- Different between chip revisions
- Changed by MicroZig's initialization

## The Math Explained

WS2812B timing: **1.25 µs per bit** (800 kHz)

Our PIO program uses **10 cycles per bit**:
```
Instruction         Cycles
-----------         ------
out x, 1   [2]      3 cycles
jmp !x ... [1]      2 cycles  
jmp/nop    [4]      5 cycles
                    -------
Total:              10 cycles
```

So we need the PIO to run at: **10 × 800 kHz = 8 MHz**

Clock divider formula:
```
divider = System Clock ÷ PIO Clock
divider = System Clock ÷ 8 MHz
```

Examples:
- 125 MHz ÷ 8 MHz = **15.625**
- 150 MHz ÷ 8 MHz = **18.75**

## Verifying the Actual Clock Speed

If you want to measure it precisely, you could:

1. **Use a logic analyzer** - Measure the actual output frequency on GPIO 2
2. **Use an oscilloscope** - Look at the timing of the signal
3. **Add clock reporting code** - Have the Pico report its own clock speed

## Advanced: Make Clock Speed Configurable

You can add this at the top of `main.zig` to easily switch:

```zig
// Clock configuration - change this to match your actual system clock
const SYSTEM_CLOCK_MHZ = 125; // Try: 125, 150, 100, etc.
const WS2812B_FREQ_KHZ = 800;
const CYCLES_PER_BIT = 10;

// Auto-calculate divider
const clkdiv_value = @as(f32, SYSTEM_CLOCK_MHZ * 1000) / 
                     @as(f32, WS2812B_FREQ_KHZ * CYCLES_PER_BIT);
```

Then use: `const clkdiv = pio.ClkDivOptions.from_float(clkdiv_value);`

## Still Not Working?

If trying different clock dividers doesn't help, the issue is likely:
1. ✅ Soldering (check continuity)
2. ✅ Wrong pin connections
3. ✅ Dead/damaged LED
4. ✅ LED strip connected backwards (DIN vs DOUT)
5. ✅ Insufficient power

## Quick Reference: Expected Signal Timing

Perfect WS2812B timing at 800kHz:

| Bit | High Time | Low Time | Total |
|-----|-----------|----------|-------|
| 0   | 0.4 µs    | 0.85 µs  | 1.25 µs |
| 1   | 0.8 µs    | 0.45 µs  | 1.25 µs |

With ±150kHz tolerance (625-975kHz), total bit time can be: **1.026 - 1.600 µs**

That's why getting the clock divider right is critical!
