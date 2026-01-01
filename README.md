# Robocar

A robot car project built with Zig and MicroZig, controlled by a Raspberry Pi Pico 2. A fun father-son project to learn about embedded systems, robotics, and the Zig programming language.

## Overview

Robocar is an embedded systems project built together with my son. We're using MicroZig to create firmware for a Raspberry Pi Pico 2-based robot car. The project leverages Zig's powerful compile-time features and MicroZig's hardware abstraction layer to build efficient, safe embedded code while learning about microcontrollers, motor control, sensors, and wireless communication.

## Hardware

- **Microcontroller**: Raspberry Pi Pico 2 W (RP2350)
- **Architecture**: ARM Cortex-M33 (dual-core, 150MHz)
- **Memory**: 512KB SRAM, 2MB Flash
- **Wireless**: 2.4GHz 802.11n (Pico 2 W variant)

## Project Structure

```
robocar/
├── src/
│   ├── main.zig          # Main firmware entry point
│   ├── root.zig          # Root module
│   └── modules/          # Hardware driver modules
│       ├── led_ws2812b.zig  # WS2812B addressable LED driver
│       └── oled.zig         # SSD1306 OLED display driver
├── docs/
│   ├── microzig-targets.md  # MicroZig target reference
│   ├── ws2812b-setup.md     # WS2812B LED setup guide
│   └── ws2812b-timing-troubleshooting.md  # Timing troubleshooting
├── build.zig             # Build configuration
├── build.zig.zon         # Dependencies
└── README.md
```

### Modular Architecture

The project uses a modular approach where hardware drivers are organized as reusable modules in `src/modules/`:

- **led_ws2812b.zig**: WS2812B addressable RGB LED driver using PIO state machine
- **oled.zig**: SSD1306 128x64 OLED display driver with I2C, framebuffer, and text rendering

Each module is self-contained and can be imported into `main.zig` as needed:

```zig
const led_ws2812b = @import("modules/led_ws2812b.zig");
const oled = @import("modules/oled.zig");
```

## Dependencies

- **MicroZig**: Embedded Zig framework (latest main branch - **NOT v0.15.0**)
  - Provides hardware abstraction layer (HAL)
  - RP2xxx port for Raspberry Pi Pico support
  - Target definitions and build system integration
  - **WiFi driver support** (requires latest code from main branch)
  
  **Important**: You must clone the latest development version from GitHub - see "Getting Started" section below for setup instructions.

## Getting Started

### Prerequisites

- Zig 0.15.1 or later
- USB cable for programming the Pico 2

### Important: MicroZig Setup

**This project requires the latest development version of MicroZig** (not the released version) because it depends on the WiFi driver which is only available in the main branch.

1. Clone MicroZig as a sibling directory to this project:

```bash
# Navigate to the parent directory (e.g., hardware/)
cd ..

# Clone the latest MicroZig from the main branch
git clone https://github.com/ZigEmbeddedGroup/microzig.git

# Your directory structure should look like:
# hardware/
# ├── robocar/     (this project)
# └── microzig/    (latest main branch)
```

2. The `build.zig.zon` file is already configured to use the local MicroZig installation via a relative path (`../microzig`).

**Note**: The released version (v0.15.0) does not include WiFi support. You MUST use the latest code from the main branch.

### Building

Build the firmware:

```bash
zig build
```

This will generate:
- `zig-out/firmware/robocar.uf2` - UF2 format for direct flashing
- `zig-out/firmware/robocar.elf` - ELF format for debugging

### Flashing

1. Hold the BOOTSEL button on your Pico 2 while plugging it into USB
2. The Pico will appear as a USB mass storage device
3. Copy the `.uf2` file to the drive:
   ```bash
   cp zig-out/firmware/robocar.uf2 /path/to/RPI-RP2
   ```
4. The Pico will automatically reboot and run your firmware

## Development

### Build Options

The project uses `ReleaseSmall` optimization by default for minimal binary size. You can change this in `build.zig`.

### Target Configuration

The current target is set to `pico2_arm` (ARM Cortex-M33). If you want to use RISC-V instead:

```zig
.target = mb.ports.rp2xxx.boards.raspberrypi.pico2_riscv,
```

See `docs/microzig-targets.md` for more target options.

### Debugging

ELF files can be used with debuggers like OpenOCD and GDB for debugging via SWD.

## Features

### Implemented
- [x] **WS2812B LED Driver** - PIO-based addressable RGB LED control with precise 800kHz timing
- [x] **SSD1306 OLED Display** - I2C OLED driver with 1024-byte framebuffer and text rendering
- [x] **Modular Architecture** - Reusable hardware driver modules

### Planned
- [ ] Motor control (PWM)
- [ ] Sensor integration (ultrasonic, IR, etc.)
- [ ] Wireless control interface
- [ ] Autonomous navigation
- [ ] Battery monitoring

## Hardware Modules

### WS2812B Addressable LEDs
- **GPIO**: 2 (Data)
- **Features**: PIO state machine, RGB color control, color cycling
- **Docs**: [WS2812B Setup Guide](docs/ws2812b-setup.md)

### SSD1306 OLED Display
- **I2C Bus**: I2C0
- **GPIO**: 4 (SDA), 5 (SCL)
- **Resolution**: 128x64 pixels
- **Features**: Text rendering, 5x7 font, framebuffer, pixel control

## Documentation

- [MicroZig Targets Reference](docs/microzig-targets.md) - Detailed information about available targets and configurations
- [WS2812B Setup Guide](docs/ws2812b-setup.md) - WS2812B LED hardware and software setup
- [WS2812B Timing Troubleshooting](docs/ws2812b-timing-troubleshooting.md) - Clock speed and timing fixes

## Resources

- [MicroZig](https://github.com/ZigEmbeddedGroup/microzig) - Embedded Zig framework
- [Raspberry Pi Pico 2](https://www.raspberrypi.com/products/raspberry-pi-pico2/) - Hardware documentation
- [RP2350 Datasheet](https://datasheets.raspberrypi.com/rp2350/rp2350-datasheet.pdf) - Chip documentation
- [Zig Language](https://ziglang.org/) - Zig programming language

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Contributing

[Add contribution guidelines here]
