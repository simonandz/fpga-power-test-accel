# Quick Simulator Installation

You have a few options to get started with testing:

## Option 1: Install/Fix Icarus Verilog (Fastest - 5 minutes)

### If you think it's already installed:
1. Open **Windows Command Prompt** (not Git Bash)
2. Type: `where iverilog`
3. If found, note the path (e.g., `C:\iverilog\bin\iverilog.exe`)
4. Add that bin directory to your PATH

### If not installed, install now:

**Method A: Direct Download (Recommended)**
1. Visit: https://bleyer.org/icarus/
2. Download latest version (e.g., `iverilog-v12-20220611-x64.exe`)
3. Run installer
4. ✅ **Check "Add to PATH"** during installation
5. Restart terminal

**Method B: Using winget**
```powershell
# Open PowerShell as Administrator
winget install IcarusVerilog
```

### Verify Installation:
```bash
# Open NEW command prompt
iverilog -v
```

Should show version info like:
```
Icarus Verilog version 12.0 (stable)
```

### Run Tests:
```bash
cd r:\fpga\fpga-power-test-accel
scripts\run_iverilog_tests.bat
```

---

## Option 2: Use Vivado XSim (if you have Vivado installed)

### Check if Vivado is installed:
```bash
# Look for Vivado directory
dir "C:\Xilinx\Vivado" 2>nul
```

### Setup Vivado Environment:

**Create a file: `setup_vivado.bat`**
```batch
@echo off
REM Adjust version number if different
set VIVADO_VER=2024.1
set XILINX_VIVADO=C:\Xilinx\Vivado\%VIVADO_VER%

if exist "%XILINX_VIVADO%\bin" (
    set PATH=%XILINX_VIVADO%\bin;%PATH%
    echo Vivado %VIVADO_VER% environment loaded
    echo.
) else (
    echo ERROR: Vivado not found at %XILINX_VIVADO%
    echo Please adjust VIVADO_VER in this script
)
```

**Run tests:**
```bash
# First load Vivado environment
setup_vivado.bat

# Then run tests
scripts\run_all_tests.bat
```

---

## Option 3: Manual Test (No installation needed)

If you just want to verify the RTL syntax without running tests:

### Use an online simulator:
- **EDA Playground**: https://www.edaplayground.com/
  1. Upload your `.sv` files
  2. Select "Icarus Verilog" as simulator
  3. Run online

### Just check for syntax errors:
I can help you review the code manually if simulators aren't working.

---

## Recommendation

For **quickest start** and best development experience:

1. **Install Icarus** (Option 1) - takes 5 minutes
2. **Run tests** with `scripts\run_iverilog_tests.bat`
3. **Develop MLP** with fast simulation feedback
4. **Install Vivado later** when you're ready for synthesis

---

## What to do now:

1. Try Option 1 (Icarus installation)
2. After installation, open **new** Command Prompt
3. Navigate to project: `cd r:\fpga\fpga-power-test-accel`
4. Run: `scripts\run_iverilog_tests.bat`
5. You should see all tests pass!

Let me know if you hit any issues!
