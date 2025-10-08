# FPGA Power Test Accelerator

Power analysis framework for FPGA designs using Xilinx Vivado toolchain with SAIF-based activity simulation.

## Project Overview

This project implements power estimation methodologies for FPGA designs, focusing on accurate switching activity capture through SAIF (Switching Activity Interchange Format) files and comprehensive power reporting.

**Target Device**: Xilinx Artix-7 (xc7a35tcpg236-1)
**Board**: Basys-3
**Tools**: Vivado 2024.2

## Directory Structure

```
fpga-power-test-accel/
├── common/
│   ├── rtl/              # RTL source files (SystemVerilog)
│   ├── tb/               # Testbenches
│   └── constraints/      # XDC constraint files
├── scripts/
│   └── power_test_scripts/  # Power analysis automation scripts
├── build/                # Build outputs (ignored in git)
├── reports/              # Power analysis reports
└── docs/                 # Documentation
```

## Power Analysis Workflows

### Method 1: SAIF-Based Power Analysis (Recommended)

Uses post-synthesis simulation to generate SAIF activity files.

**Steps:**
```bash
# 1. Build the design
vivado -mode batch -source scripts/power_test_scripts/build_hello.tcl

# 2. Generate SAIF from simulation
vivado -mode tcl -source scripts/power_test_scripts/build_power_analysis.tcl

# 3. Generate power report
vivado -mode batch -source scripts/power_test_scripts/vivado_power_report.tcl
```

**Result**: ~51% net matching with "High" confidence rating

### Method 2: Hybrid Power Analysis

Combines SAIF measurements with calculated defaults for unmatched nets.

```bash
vivado -mode batch -source scripts/power_test_scripts/hybrid_fixed.tcl
```

**Result**: 51% measured activity + 49% statistical defaults

### Method 3: Manual Activity Specification

100% user-specified activity based on design knowledge (no SAIF).

```bash
vivado -mode batch -source scripts/power_test_scripts/manual_activity_correct.tcl
```

**Result**: 100% activity specification with calculated toggle rates

## Key Scripts

| Script | Purpose |
|--------|---------|
| `build_hello.tcl` | Synthesize, place & route the design |
| `build_power_analysis.tcl` | Run post-synthesis simulation, generate SAIF |
| `vivado_power_report.tcl` | Generate power report from SAIF |
| `hybrid_fixed.tcl` | Hybrid SAIF + default activity approach |
| `manual_activity_correct.tcl` | 100% manual activity specification |

## Cleaning Up

Run cleanup before committing:
```bash
# Windows
cleanup.bat

# Linux/Mac
./cleanup.sh
```

This removes:
- Log files and backup journals
- Temporary simulation files
- Intermediate build files

**Preserved**:
- Source code (RTL, testbenches, constraints)
- Final power reports
- Scripts

## Design: hello_top

Simple counter-based LED blinker design for power analysis validation.

**Features**:
- 26-bit counter at 100 MHz
- Constant LED output (led_on)
- Blinking LED output (led_blink) at ~1.5 Hz
- Minimal logic for clear power profiling

## Power Analysis Results

Typical power consumption (post-implementation):
- **Total On-Chip Power**: ~69 mW
- **Dynamic Power**: ~1 mW
- **Static Power**: ~68 mW
- **Confidence Level**: High

Power breakdown:
- Clocks: <1 mW
- Logic: <1 mW
- I/O: <1 mW
- Device Static: 68 mW

## Requirements

- Xilinx Vivado 2024.2 (or compatible version)
- Basys-3 board (for hardware deployment)
- Git (for version control)

## Contributing

This is a research/educational project. Feel free to:
- Extend power analysis methodologies
- Add new test designs
- Improve automation scripts

## License

[Specify your license here]

## References

- Xilinx UG907: Power Analysis and Optimization User Guide
- Xilinx UG835: Vivado Design Suite Tcl Command Reference
