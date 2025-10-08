# Accelerator Framework - Shared Infrastructure

## Overview

This document describes the shared infrastructure components for the unified accelerator framework. These components provide common functionality for all three accelerator types (MLP, CNN, RNN) and implement power optimization features.

## Architecture Components

### 1. Package: `accel_pkg.sv`

**Purpose**: Central package containing all common types, parameters, and utility functions.

**Key Definitions**:
- **Data Types**: 8-bit data, 16-bit accumulators
- **Memory Banks**: 19 BRAM banks with defined roles
  - Banks 0-1: Input buffers (ping-pong)
  - Banks 2-3: Output buffers (ping-pong)
  - Banks 4-15: Weight storage
  - Banks 16-17: Intermediate activations
  - Bank 18: Bias values
- **FSM States**: Unified state enumeration for all accelerators
- **Fixed-Point Format**: Q4.4 (4 integer bits, 4 fractional bits)

**Utility Functions**:
- `saturate()`: Saturate 16-bit accumulator to 8-bit with overflow protection
- `relu()`: ReLU activation function
- `tanh_approx()`: 3-segment piecewise linear tanh approximation

### 2. Memory Controller: `memory_controller.sv`

**Purpose**: Manages all BRAM banks with power-aware access control.

**Features**:
- 19 independent BRAM bank interfaces
- Bank selection based on address mapping
- Power-down control for unused banks
- 1-cycle read latency
- Assertions for out-of-bounds detection

**Interface**:
```systemverilog
input  mem_req_t     req        // Memory request (addr, data, we, re, bank_sel)
output mem_resp_t    resp       // Memory response (data, valid, ready)
input  [18:0]        bank_power_en  // Per-bank power control
```

### 3. Address Generation Unit: `addr_gen_unit.sv`

**Purpose**: Generates addresses for different memory access patterns.

**Access Patterns**:
1. **Sequential** (MLP): Linear incrementing addresses
2. **Sliding 2D** (CNN): 2D convolution window with configurable stride
3. **Circular** (RNN): Circular buffer for sequence processing

**Configuration**:
- Base address and length
- Pattern-specific parameters (stride, image dimensions, kernel size)
- Handshake protocol with addr_valid/addr_ready

### 4. Accelerator Controller: `accel_controller.sv`

**Purpose**: Unified FSM framework managing the accelerator execution flow.

**State Machine**:
```
IDLE → LOAD_WEIGHTS → LOAD_INPUT → COMPUTE → STORE_OUTPUT → DONE → IDLE
```

**Responsibilities**:
- Orchestrate memory transfers using AGU
- Control compute unit activation
- Monitor completion and errors
- Generate memory requests based on current state

### 5. Power Manager: `power_manager.sv`

**Purpose**: Centralized power optimization control.

**Power Saving Techniques**:
1. **Clock Gating**: Disable clocks to inactive accelerators
2. **BRAM Banking**: Power down unused memory banks based on state
3. **DSP Operand Isolation**: Zero inputs to unused DSP slices

**State-Aware Power Control**:
- IDLE: Only I/O banks powered
- LOAD_WEIGHTS: Weight banks + I/O banks
- COMPUTE: All banks active
- DONE: Only output banks for readout

### 6. Clock Gate Cell: `clock_gate.sv`

**Purpose**: Safe clock gating implementation to prevent glitches.

**Implementation**:
- Latch-based enable on negative clock edge
- Test enable bypass for scan testing
- Prevents clock glitches during enable transitions

### 7. BRAM Bank: `bram_bank.sv`

**Purpose**: Single 18Kb BRAM block configured as 2048 × 8-bit.

**Features**:
- Registered output (1-cycle latency)
- Block RAM inference with `(* ram_style = "block" *)`
- Zero-initialized for simulation

### 8. Top-Level Integration: `accel_top.sv`

**Purpose**: Integrates all infrastructure components with memory-mapped interface.

**External Interface**:
```systemverilog
// Control
input  logic        start
output logic        done, busy

// Configuration
input  logic [1:0]  accel_type      // Select MLP/CNN/RNN
input  logic [15:0] config_data     // Accelerator-specific config

// Memory I/O
input  logic [15:0] input_addr
input  logic [7:0]  input_data
input  logic        input_we
output logic [7:0]  output_data
output logic        output_valid

// Memory regions (configurable base/size)
input  [15:0] weight_base_addr, weight_size
input  [15:0] input_base_addr,  input_size
input  [15:0] output_base_addr, output_size

// Debug
output logic [2:0]  current_state
output logic [7:0]  error_flags
```

**Placeholder Compute Unit**:
- Currently implements a simple counter-based compute_done
- Will be replaced by actual MLP/CNN/RNN cores in subsequent weeks

## Resource Estimates

| Component | LUTs | FFs | DSPs | BRAM |
|-----------|------|-----|------|------|
| Memory Controller | ~300 | ~150 | 0 | 0 |
| AGU | ~200 | ~100 | 0 | 0 |
| Controller FSM | ~150 | ~80 | 0 | 0 |
| Power Manager | ~100 | ~50 | 0 | 0 |
| Clock Gates (×3) | ~30 | ~10 | 0 | 0 |
| BRAM Banks (×19) | 0 | 0 | 0 | 19 |
| **Total Infrastructure** | **~780** | **~390** | **0** | **19** |

*Leaves ~30,000 LUTs and 60 DSPs for compute units*

## Testing

### Testbench: `tb_accel_top.sv`

**Test Coverage**:
1. **FSM Transition Test**: Verify all state transitions
2. **Multi-Accelerator Test**: Switch between MLP/CNN/RNN modes
3. **Power Management Test**: Verify clock gating signals

**Running the Test**:
```bash
xvlog -sv common/rtl/accel_pkg.sv \
          common/rtl/bram_bank.sv \
          common/rtl/memory_controller.sv \
          common/rtl/addr_gen_unit.sv \
          common/rtl/accel_controller.sv \
          common/rtl/power_manager.sv \
          common/rtl/clock_gate.sv \
          common/rtl/accel_top.sv \
          common/tb/tb_accel_top.sv

xelab -debug typical tb_accel_top
xsim tb_accel_top -R
```

## Design Decisions

### Why Unified Controller?
- Consistent power measurement baseline
- Fair comparison between accelerators
- Code reuse and maintainability

### Why Ping-Pong Buffers?
- Allow overlapped computation and data transfer
- Maximize memory bandwidth utilization
- Hide memory access latency

### Why Q4.4 Fixed-Point?
- Balance between range (±8) and precision (1/16)
- Simple overflow detection (bit 7)
- Efficient DSP48E1 utilization

### Why State-Based Power Management?
- Predictable power profiles for measurement
- Maximize power savings in idle periods
- Avoid race conditions with compute units

## Next Steps (Week 2-3)

1. **MLP Core Implementation**:
   - Matrix-vector multiply unit
   - 8-parallel MAC array
   - ReLU activation
   - Integration with shared infrastructure

2. **MLP Testbench**:
   - Small network verification
   - Power measurement validation

3. **Documentation**:
   - MLP architecture details
   - Benchmark dataset preparation

## File Structure

```
common/
├── rtl/
│   ├── accel_pkg.sv           # Package with common types
│   ├── memory_controller.sv   # BRAM bank manager
│   ├── addr_gen_unit.sv       # Address generator
│   ├── accel_controller.sv    # Unified FSM
│   ├── power_manager.sv       # Power optimization
│   ├── clock_gate.sv          # Clock gating cell
│   ├── bram_bank.sv           # Single BRAM block
│   └── accel_top.sv           # Top-level integration
└── tb/
    └── tb_accel_top.sv        # Infrastructure testbench
```

## References

- Basys 3 Reference Manual: [Digilent Documentation](https://digilent.com/reference/basys3/refmanual)
- Artix-7 DSP48E1 User Guide: UG479
- Vivado Power Optimization: UG907
