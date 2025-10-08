# Accelerator Framework Quick Start Guide

## Created Infrastructure Components

### Core Modules (Week 1 Complete)

| File | Purpose | Lines |
|------|---------|-------|
| `accel_pkg.sv` | Common types, parameters, and utilities | ~180 |
| `memory_controller.sv` | 19-bank BRAM manager with power control | ~120 |
| `addr_gen_unit.sv` | Configurable address generator (3 patterns) | ~210 |
| `accel_controller.sv` | Unified FSM for all accelerators | ~200 |
| `power_manager.sv` | Clock gating and power optimization | ~140 |
| `clock_gate.sv` | Safe clock gating cell | ~25 |
| `bram_bank.sv` | 2048×8 BRAM block | ~40 |
| `accel_top.sv` | Top-level integration | ~240 |

### Test Suite (5 Comprehensive Testbenches)

| File | Purpose | Lines |
|------|---------|-------|
| `tb_memory_controller.sv` | BRAM banking and power-down tests | ~230 |
| `tb_addr_gen_unit.sv` | All 3 address patterns + backpressure | ~270 |
| `tb_accel_controller.sv` | FSM transitions and bank routing | ~280 |
| `tb_power_manager.sv` | Clock gating and power states | ~250 |
| `tb_accel_top.sv` | End-to-end integration test | ~180 |

**Total: ~2645 lines of SystemVerilog (RTL + Tests)**

## Key Features Implemented

### ✅ Memory Architecture
- 19 BRAM banks (50 × 18Kb blocks available on Basys 3)
- Ping-pong input/output buffers (banks 0-3)
- Weight storage (banks 4-15)
- Activation buffers (banks 16-17)
- Bias storage (bank 18)

### ✅ Unified Control Flow
```
IDLE → LOAD_WEIGHTS → LOAD_INPUT → COMPUTE → STORE_OUTPUT → DONE
```

### ✅ Address Generation Patterns
1. **Sequential**: Linear addressing for MLP
2. **Sliding 2D**: Convolution windows for CNN
3. **Circular**: Ring buffer for RNN sequences

### ✅ Power Optimization
- Clock gating for idle accelerators
- State-based BRAM bank power-down
- DSP operand isolation

### ✅ Fixed-Point Arithmetic
- Q4.4 format (4 integer, 4 fractional bits)
- Range: -8.0 to +7.9375
- Saturation logic for overflow protection

## Quick Verification

### Prerequisites - Choose a Simulator

**Option 1: Icarus Verilog** ⭐ Recommended for development
- Windows: https://bleyer.org/icarus/ or `winget install IcarusVerilog`
- Linux: `sudo apt-get install iverilog gtkwave`
- Size: 50MB, Free

**Option 2: Vivado XSim** (Needed for synthesis later)
- Download: https://www.xilinx.com/support/download.html
- Size: 40GB, Free

📖 See [SIMULATION_SETUP.md](SIMULATION_SETUP.md) for complete setup guide.

### Run All Tests

**With Icarus Verilog (after installation):**
```bash
# Windows
cd r:\fpga\fpga-power-test-accel
scripts\run_iverilog_tests.bat

# Linux/Mac
bash scripts/run_iverilog_tests.sh
```

**With Vivado XSim (after setting up PATH):**
```bash
# Windows
scripts\run_all_tests.bat

# Linux/Mac
bash scripts/run_all_tests.sh
```

This runs all 5 testbenches and produces a summary report.

### Run Individual Test (Icarus)
```bash
# Example: Test memory controller only
iverilog -g2012 -o test.vvp \
    common/rtl/accel_pkg.sv \
    common/rtl/bram_bank.sv \
    common/rtl/memory_controller.sv \
    common/tb/tb_memory_controller.sv

vvp test.vvp
```

### Expected Output (run_all_tests)
```
=======================================================
  Accelerator Infrastructure Test Suite
=======================================================

Running: Memory Controller Test
-------------------------------------------------------
  ✓ PASSED

Running: Address Generator Test
-------------------------------------------------------
  ✓ PASSED

Running: Accelerator Controller Test
-------------------------------------------------------
  ✓ PASSED

Running: Power Manager Test
-------------------------------------------------------
  ✓ PASSED

Running: Integration Test
-------------------------------------------------------
  ✓ PASSED

=======================================================
  Test Summary
=======================================================
Passed: 5
Failed: 0
Total:  5

All tests passed!
```

## Integration Points for Compute Units

When implementing MLP/CNN/RNN cores (Weeks 2-6), connect to these interfaces:

### From `accel_top.sv`:
```systemverilog
// Compute interface
input  logic        compute_start     // Pulse to start computation
input  logic [15:0] compute_config    // Accelerator-specific config
output logic        compute_done      // Assert when finished
output logic [7:0]  compute_error     // Error flags

// Power control
input  logic        mlp_clk_en        // Clock enable for MLP
input  logic        cnn_clk_en        // Clock enable for CNN
input  logic        rnn_clk_en        // Clock enable for RNN
input  logic        mlp_dsp_en        // DSP isolation control
input  logic        cnn_dsp_en
input  logic        rnn_dsp_en

// Memory access (via memory controller)
output mem_req_t    mem_req          // Memory request
input  mem_resp_t   mem_resp         // Memory response
```

### Memory Request Structure:
```systemverilog
typedef struct packed {
    logic [15:0]  addr;       // Address within bank
    logic [7:0]   data;       // Write data
    logic         we;         // Write enable
    logic         re;         // Read enable
    logic [4:0]   bank_sel;   // Bank selection (0-18)
} mem_req_t;
```

## Resource Budget

| Component | LUTs Used | Available | % Used |
|-----------|-----------|-----------|--------|
| Infrastructure | ~780 | 33,280 | 2.3% |
| **Available for Compute** | **32,500** | **33,280** | **97.7%** |

| Component | DSPs Used | Available | % Used |
|-----------|-----------|-----------|--------|
| Infrastructure | 0 | 60 | 0% |
| **Available for Compute** | **60** | **60** | **100%** |

| Component | BRAM Used | Available | % Used |
|-----------|-----------|-----------|--------|
| Infrastructure | 19 | 50 | 38% |
| **Available for Compute** | **31** | **50** | **62%** |

## Next Steps (Week 2)

1. **Implement MLP Core** (`mlp/rtl/mlp_core.sv`):
   - 8-parallel MAC units (8 DSPs)
   - Matrix-vector multiply engine
   - ReLU activation
   - Integration with infrastructure

2. **Create MLP Testbench**:
   - Small network (64→32→10)
   - MNIST subset testing
   - Power measurement validation

3. **Prepare Benchmark Data**:
   - Convert weights to Q4.4 format
   - Generate test vectors
   - Create memory initialization files

## File Locations

```
fpga-power-test-accel/
├── common/
│   ├── rtl/
│   │   ├── accel_pkg.sv           ← Common package
│   │   ├── accel_top.sv           ← Top-level wrapper
│   │   ├── accel_controller.sv    ← FSM controller
│   │   ├── memory_controller.sv   ← BRAM manager
│   │   ├── addr_gen_unit.sv       ← Address generator
│   │   ├── power_manager.sv       ← Power optimization
│   │   ├── clock_gate.sv          ← Clock gating
│   │   └── bram_bank.sv           ← BRAM block
│   └── tb/
│       └── tb_accel_top.sv        ← Infrastructure test
├── mlp/                            ← Week 2-3 (TODO)
├── cnn/                            ← Week 4-5 (TODO)
├── rnn/                            ← Week 6 (TODO)
└── docs/
    ├── INFRASTRUCTURE.md           ← Detailed documentation
    └── QUICKSTART.md               ← This file
```

## Questions?

- See [INFRASTRUCTURE.md](INFRASTRUCTURE.md) for detailed architecture
- Check individual module headers for interface descriptions
- Review `tb_accel_top.sv` for usage examples
