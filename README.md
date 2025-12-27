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
│   └── root.zig          # Root module
├── docs/
│   └── microzig-targets.md  # MicroZig target reference
├── build.zig             # Build configuration
├── build.zig.zon         # Dependencies
└── README.md
```

## Dependencies

- **MicroZig**: Embedded Zig framework (v0.15.0)
  - Provides hardware abstraction layer (HAL)
  - RP2xxx port for Raspberry Pi Pico support
  - Target definitions and build system integration

## Getting Started

### Prerequisites

- Zig 0.15.1 or later
- USB cable for programming the Pico 2

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

## Features (Planned)

- [ ] Motor control (PWM)
- [ ] Sensor integration (ultrasonic, IR, etc.)
- [ ] Wireless control interface
- [ ] Autonomous navigation
- [ ] Battery monitoring
- [ ] LED status indicators

## Documentation

- [MicroZig Targets Reference](docs/microzig-targets.md) - Detailed information about available targets and configurations

## Resources

- [MicroZig](https://github.com/ZigEmbeddedGroup/microzig) - Embedded Zig framework
- [Raspberry Pi Pico 2](https://www.raspberrypi.com/products/raspberry-pi-pico2/) - Hardware documentation
- [RP2350 Datasheet](https://datasheets.raspberrypi.com/rp2350/rp2350-datasheet.pdf) - Chip documentation
- [Zig Language](https://ziglang.org/) - Zig programming language

## License

[Add your license here]

## Contributing

[Add contribution guidelines here]
