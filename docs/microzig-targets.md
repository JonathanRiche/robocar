# MicroZig Target Types Reference

This document provides information about MicroZig target types, specifically for the RP2xxx (Raspberry Pi Pico) family of microcontrollers.

## Target Type Definition

The `Target` type is defined in the MicroZig build-internals package:
- **Location**: `~/.cache/zig/p/mz_buildinternals-*/build.zig:22`
- **Import**: Accessed via `@import("build-internals")` in MicroZig port packages

### Target Structure

```zig
pub const Target = struct {
    /// The `*std.Build.Dependency` belonging of the port that created this target.
    dep: *Build.Dependency,

    /// The preferred binary format of this MicroZig target, if it has one.
    preferred_binary_format: ?BinaryFormat = null,

    /// The cpu target for the firmware.
    zig_target: std.Target.Query,

    /// (optional) If set, overrides the default cpu module that microzig provides.
    cpu: ?Cpu = null,

    /// The chip this target uses.
    chip: Chip,

    /// Usually, embedded projects are single-threaded and single-core applications.
    single_threaded: bool = true,

    /// Determines whether the compiler_rt package is bundled with the application.
    bundle_compiler_rt: bool = true,

    /// Determines whether the artifact will exist solely in RAM.
    ram_image: bool = false,

    /// (optional) Provides a default hardware abstraction layer.
    hal: ?HardwareAbstractionLayer = null,

    /// (optional) Provides description of external hardware and connected devices.
    board: ?Board = null,

    /// Provides a custom linker script for the hardware.
    linker_script: LinkerScript = .{},

    /// Determines the location of the stack.
    stack: Stack = .{ .ram_region_index = 0 },

    /// (optional) Explicitly set the entry point.
    entry: ?Build.Step.Compile.Entry = null,

    /// (optional) Post processing step that will patch up and modify the elf file.
    patch_elf: ?*const fn (*Build.Dependency, LazyPath) LazyPath = null,
};
```

## Available RP2xxx Targets

The RP2xxx port provides targets for various Raspberry Pi Pico boards.

### Chips

Access via `mb.ports.rp2xxx.chips.*`:

| Chip | Architecture | Flash | RAM | CPU | Binary Format |
|------|-------------|-------|-----|-----|---------------|
| `rp2040` | ARM Cortex-M0+ | 2MB | 256KB | Thumb | UF2 (RP2040) |
| `rp2350_arm` | ARM Cortex-M33 | 2MB | 512KB + 8KB | Thumb + FPU | UF2 (RP2350_ARM_S) |
| `rp2350_riscv` | RISC-V Hazard3 | 2MB | 512KB + 8KB | RV32IMAC + extensions | UF2 (RP2350_RISC_V) |

#### RP2350 CPU Features
- **ARM variant**: Hardware floating-point (FP ARMv8 D16 SP)
- **RISC-V variant**: Extensions - A, M, C, Zba, Zbb, Zbs, Zcb, Zcmp, Zbkb, Zifencei

### Raspberry Pi Boards

Access via `mb.ports.rp2xxx.boards.raspberrypi.*`:

| Board | Chip | Description | URL |
|-------|------|-------------|-----|
| `pico` | RP2040 | Original Raspberry Pi Pico | [Product Page](https://www.raspberrypi.com/products/raspberry-pi-pico/) |
| `pico_flashless` | RP2040 | Pico with RAM-only image | Same as above |
| `pico2_arm` | RP2350 (ARM) | Raspberry Pi Pico 2 (ARM Cortex-M33) | [Product Page](https://www.raspberrypi.com/products/raspberry-pi-pico2/) |
| `pico2_arm_flashless` | RP2350 (ARM) | Pico 2 ARM with RAM-only image | Same as above |
| `pico2_riscv` | RP2350 (RISC-V) | Raspberry Pi Pico 2 (RISC-V Hazard3) | Same as above |
| `pico2_riscv_flashless` | RP2350 (RISC-V) | Pico 2 RISC-V with RAM-only image | Same as above |

**Note**: The Pico 2 W (with wireless) is not yet explicitly supported in this MicroZig version. Use the regular `pico2_arm` target for Pico 2 W hardware - wireless functionality will need to be configured separately.

### Adafruit Boards

Access via `mb.ports.rp2xxx.boards.adafruit.*`:

| Board | Chip | Description | URL |
|-------|------|-------------|-----|
| `metro_rp2350` | RP2350 (ARM) | Adafruit Metro RP2350 | [Product Page](https://www.adafruit.com/product/6267) |

### Waveshare Boards

Access via `mb.ports.rp2xxx.boards.waveshare.*`:

| Board | Chip | Flash Size | Description | URL |
|-------|------|-----------|-------------|-----|
| `rp2040_plus_4m` | RP2040 | 4MB | Waveshare RP2040-Plus | [Product Page](https://www.waveshare.com/rp2040-plus.htm) |
| `rp2040_plus_16m` | RP2040 | 16MB | Waveshare RP2040-Plus | [Product Page](https://www.waveshare.com/rp2040-plus.htm) |
| `rp2040_eth` | RP2040 | Standard | Waveshare RP2040-ETH Mini | [Product Page](https://www.waveshare.com/rp2040-eth.htm) |
| `rp2040_matrix` | RP2040 | Standard | Waveshare RP2040-Matrix | [Product Page](https://www.waveshare.com/rp2040-matrix.htm) |

## Usage Examples

### Basic Usage (Pico 2 W)

```zig
const std = @import("std");
const microzig = @import("microzig");

const MicroBuild = microzig.MicroBuild(.{
    .rp2xxx = true,
});

pub fn build(b: *std.Build) void {
    const mz_dep = b.dependency("microzig", .{});
    const mb = MicroBuild.init(b, mz_dep) orelse return;

    const firmware = mb.add_firmware(.{
        .name = "robocar",
        .target = mb.ports.rp2xxx.boards.raspberrypi.pico2_arm,
        .optimize = .ReleaseSmall,
        .root_source_file = b.path("src/main.zig"),
    });

    mb.install_firmware(firmware, .{});
    mb.install_firmware(firmware, .{ .format = .elf });
}
```

### Using RISC-V Instead of ARM

```zig
.target = mb.ports.rp2xxx.boards.raspberrypi.pico2_riscv,
```

### Using Original Pico

```zig
.target = mb.ports.rp2xxx.boards.raspberrypi.pico,
```

### Using Chip Directly (No Board)

```zig
.target = mb.ports.rp2xxx.chips.rp2350_arm,
```

## Binary Formats

MicroZig supports multiple output formats:

- **UF2**: USB Flashing Format (default for RP2xxx)
  - RP2040: `.uf2 = .RP2040`
  - RP2350 ARM: `.uf2 = .RP2350_ARM_S`
  - RP2350 RISC-V: `.uf2 = .RP2350_RISC_V`
- **ELF**: Executable and Linkable Format
- **BIN**: Raw binary
- **HEX**: Intel HEX format
- **DFU**: Device Firmware Upgrade
- **ESP**: ESP bootloader format
- **Custom**: User-defined formats

## Board Configuration Files

Board-specific configuration is minimal. For example, `raspberry_pi_pico2.zig` only contains:

```zig
pub const xosc_freq = 12_000_000; // 12MHz external crystal
```

Most configuration is handled by the chip and HAL definitions.

## Target Derivation

You can create custom targets by deriving from existing ones:

```zig
const custom_target = mb.ports.rp2xxx.boards.raspberrypi.pico2_arm.derive(.{
    .preferred_binary_format = .bin,
    .single_threaded = false,
    // ... other options
});
```

## Related Types

- **Chip**: Defines the microcontroller (RP2040, RP2350)
- **Cpu**: Optional CPU module override
- **HardwareAbstractionLayer**: HAL root source file and imports
- **Board**: Board-specific configuration (pins, peripherals, etc.)
- **MemoryRegion**: Flash and RAM regions with access permissions
- **LinkerScript**: Custom linker script configuration
- **Stack**: Stack location configuration

## References

- MicroZig build-internals: `~/.cache/zig/p/mz_buildinternals-*/build.zig`
- RP2xxx port: `~/.cache/zig/p/mz_port_raspberrypi_rp2xxx-*/build.zig`
- Board definitions: `~/.cache/zig/p/mz_port_raspberrypi_rp2xxx-*/src/boards/`
