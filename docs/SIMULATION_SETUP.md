# Simulation Tool Setup Guide

## Overview

You have multiple options for running the testbenches. Choose based on your needs:

| Tool | Size | Speed | SV Support | Cost | Best For |
|------|------|-------|------------|------|----------|
| **Icarus Verilog** | 50MB | Fast | Good | Free | Development ⭐ |
| **Vivado XSim** | 40GB | Medium | Full | Free | Final Synthesis |
| **Verilator** | 100MB | Fastest | Good | Free | Performance |
| **ModelSim** | 2GB | Fast | Full | $$ | Professional |

---

## Option 1: Icarus Verilog (Recommended for Quick Start)

### Windows Installation

**Method 1: Installer (Easiest)**
1. Download from: https://bleyer.org/icarus/
2. Run installer (iverilog-v12-20220611-x64.exe or newer)
3. Add to PATH during installation

**Method 2: Package Manager**
```bash
# Using winget
winget install IcarusVerilog

# Using Chocolatey
choco install iverilog
```

**Verify Installation:**
```bash
iverilog -v
# Should show: Icarus Verilog version 12.0 or newer
```

### Linux Installation

```bash
# Ubuntu/Debian
sudo apt-get update
sudo apt-get install iverilog gtkwave

# Fedora/RHEL
sudo dnf install iverilog gtkwave

# Arch
sudo pacman -S iverilog gtkwave
```

### Running Tests with Icarus

```bash
cd r:\fpga\fpga-power-test-accel
scripts\run_iverilog_tests.bat
```

### Viewing Waveforms

Each test generates a `.vcd` file. View with GTKWave:

```bash
# Install GTKWave (if not already installed)
# Download from: https://gtkwave.sourceforge.net/

# View waveforms
gtkwave tb_memory_controller.vcd
```

---

## Option 2: Vivado XSim (Full Xilinx Tool Chain)

### Installation

1. Download Vivado from: https://www.xilinx.com/support/download.html
2. Install "Vivado ML Standard" (free WebPack license)
3. Size: ~40GB installed
4. Installation time: 1-2 hours

### Setup PATH (Windows)

After installation, you need to source the environment:

**Option A: Use Vivado Command Prompt**
- Start Menu → Xilinx Design Tools → Vivado 2024.x → Vivado 2024.x Tcl Shell

**Option B: Manual PATH Setup**
Add to your system PATH:
```
C:\Xilinx\Vivado\2024.1\bin
```

Create batch file `setup_vivado.bat`:
```batch
@echo off
set XILINX_VIVADO=C:\Xilinx\Vivado\2024.1
set PATH=%XILINX_VIVADO%\bin;%PATH%
echo Vivado environment loaded
```

### Running Tests with XSim

```bash
cd r:\fpga\fpga-power-test-accel

# Option 1: Use original script
scripts\run_all_tests.bat

# Option 2: Manual
xvlog -sv common/rtl/accel_pkg.sv common/rtl/bram_bank.sv ...
xelab tb_memory_controller
xsim tb_memory_controller -R
```

---

## Option 3: Verilator (Advanced - Best Performance)

### Installation

**Windows:**
```bash
# Using MSYS2
pacman -S mingw-w64-x86_64-verilator

# Or download from: https://github.com/verilator/verilator
```

**Linux:**
```bash
sudo apt-get install verilator
```

### Note on Verilator

Verilator requires C++ testbenches, which is more complex. I can help convert the testbenches if you choose this option, but **Icarus is easier to start with**.

---

## Option 4: ModelSim/Questa (Professional)

### Free Student Edition

1. Register for Intel FPGA University Program
2. Download ModelSim-Intel FPGA Starter Edition
3. Size: ~2GB
4. Free but requires registration

### Commercial Version

- Full featured, expensive
- Usually provided by employers/universities

---

## Recommended Setup for Your Project

For **development and testing** (Week 1-6):
```
Icarus Verilog + GTKWave
```
- Fast iteration
- Small download
- Good enough for functional testing

For **synthesis and Basys 3 deployment**:
```
Vivado (required)
```
- Needed for bitstream generation
- Use later when ready to deploy to FPGA

---

## Quick Start: Install Icarus Now

### Windows (5 minutes)
```bash
# 1. Download installer
# Visit: https://bleyer.org/icarus/
# Download: iverilog-v12-20220611-x64.exe

# 2. Run installer (check "Add to PATH")

# 3. Open new command prompt and test
iverilog -v

# 4. Run tests
cd r:\fpga\fpga-power-test-accel
scripts\run_iverilog_tests.bat
```

### Linux (2 minutes)
```bash
sudo apt-get install iverilog gtkwave
cd /path/to/fpga-power-test-accel
bash scripts/run_iverilog_tests.sh
```

---

## Troubleshooting

### "iverilog not found"
- **Windows**: Check PATH contains Icarus installation directory
- **Linux**: Install with package manager
- Verify: `where iverilog` (Windows) or `which iverilog` (Linux)

### "xvlog not found"
- Vivado not installed or not in PATH
- Use Icarus instead, or setup Vivado environment

### SystemVerilog Features Not Working
- Icarus has limited support for some SV features
- The testbenches are designed to work with Icarus
- If issues occur, use Vivado XSim instead

### Compilation Errors
- Check log files in `build/test_results/`
- Most errors will show missing modules or syntax issues
- Ensure all source files are listed in compile command

---

## What I Recommend

**For you right now:**
1. Install **Icarus Verilog** (5 min download)
2. Run `scripts\run_iverilog_tests.bat`
3. Iterate quickly on MLP development

**When ready for FPGA:**
1. Install **Vivado** (for synthesis)
2. Generate bitstream
3. Program Basys 3 board

You can develop with Icarus and only use Vivado for final synthesis!

---

## Next Steps

After installing your chosen simulator:

1. **Verify installation:**
   ```bash
   iverilog -v  # or xvlog -version
   ```

2. **Run tests:**
   ```bash
   scripts\run_iverilog_tests.bat  # or run_all_tests.bat
   ```

3. **Check output:**
   - All tests should pass
   - Logs in `build/test_results/`
   - VCD waveforms for debugging

4. **Start MLP development** (Week 2)
