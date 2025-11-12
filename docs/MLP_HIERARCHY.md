// MLP Accelerator Hierarchical Design

## Architecture Overview

The MLP accelerator has been refactored into a clean hierarchical design with four main modules:

```
mlp_top
├── mlp_memory_subsystem    (Memory management)
├── mlp_compute_datapath    (MAC + Activation)
└── mlp_controller          (FSM + Control logic)
```

---

## Module Descriptions

### 1. `mlp_top.sv` - Top-Level Integration

**Purpose**: Integrates all subsystems and manages data flow

**Responsibilities**:
- Instantiate memory, datapath, and controller modules
- Connect inter-module signals
- Manage data loading from memory to datapath
- Expose external interfaces (host and output)

**Interfaces**:
- Host interface: Load inputs, weights, biases
- Control: start, done, busy
- Output: result data and valid signal

---

### 2. `mlp_memory_subsystem.sv` - Memory Management

**Purpose**: Manage all BRAM blocks for the MLP accelerator

**Memory Blocks**:
| Memory | Size | Purpose |
|--------|------|---------|
| Input BRAM | 4K × 8-bit | Store input feature vector |
| Weight BRAM | 16K × 8-bit | Store weight matrix |
| Bias BRAM | 256 × 8-bit | Store bias vector |
| Output BRAM | 4K × 8-bit | Store output results |

**Features**:
- Dual-port BRAMs (host write, compute read)
- Independent read/write addressing
- Single-cycle read latency

**Interfaces**:
```systemverilog
// Host write ports (for data loading)
input  [15:0] input_addr, weight_addr, bias_addr
input  [7:0]  input_data, weight_data, bias_data
input         input_we, weight_we, bias_we

// Compute read ports (for accelerator)
input  [15:0] input_rd_addr, weight_rd_addr
input  [7:0]  bias_rd_addr
output [7:0]  input_rd_data, weight_rd_data, bias_rd_data

// Output write port (from compute)
input  [15:0] output_wr_addr
input  [7:0]  output_wr_data
input         output_wr_en
```

---

### 3. `mlp_compute_datapath.sv` - Compute Pipeline

**Purpose**: Perform MAC operations and activation

**Components**:
- `mac_array_8x` - 8-way parallel MAC
- `activation_unit` - ReLU/tanh/sigmoid
- Accumulator - 16-bit accumulator
- Bias adder - Q4.4 fixed-point addition

**Pipeline Stages**:
1. **MAC**: 8 parallel multiplies (DSP48E1)
2. **Reduction**: Tree-structured sum (7 adders)
3. **Accumulate**: Add partial sum to accumulator
4. **Bias**: Add bias with Q4.4 scaling
5. **Activation**: Apply ReLU (or tanh/sigmoid)
6. **Saturate**: Clamp to 8-bit output

**Latency**: ~6 cycles (MAC: 4, Activation: 2)

**Interfaces**:
```systemverilog
// Control
input         mac_enable, mac_clear
input         activation_enable
input  [1:0]  activation_type

// Data inputs (8-way parallel)
input  [7:0]  data_in[0:7]
input  [7:0]  weight_in[0:7]
input  [7:0]  bias_in

// Outputs
output [7:0]  result_out
output        result_valid
output [15:0] accumulator      // For debugging
output        mac_valid
```

---

### 4. `mlp_controller.sv` - Control FSM

**Purpose**: Orchestrate memory access and compute operations

**FSM States**:
```
IDLE → INIT_NEURON → LOAD_DATA → COMPUTE → ACTIVATE → STORE_OUTPUT → DONE
       ↑______________________________________________|
```

**State Functions**:
| State | Action |
|-------|--------|
| IDLE | Wait for start signal |
| INIT_NEURON | Clear accumulator, initialize addresses |
| LOAD_DATA | Fetch 8 inputs and 8 weights from memory |
| COMPUTE | Trigger MAC operation, update addresses |
| ACTIVATE | Apply ReLU activation |
| STORE_OUTPUT | Write result to output BRAM |
| DONE | Signal completion, wait for start deassert |

**Control Signals**:
```systemverilog
// Memory control
output [15:0] input_rd_addr, weight_rd_addr
output [7:0]  bias_rd_addr
output [15:0] output_wr_addr
output        output_wr_en

// Datapath control
output        mac_enable, mac_clear
output        activation_enable
output [1:0]  activation_type

// Status
output        done, busy
```

---

## Data Flow

### Forward Path (Computation)

```
1. Controller → Memory: Read addresses
                  ↓
2. Memory → Datapath: Input/weight data (8 parallel)
                  ↓
3. Datapath (MAC): Multiply & accumulate
                  ↓
4. Datapath (Activation): ReLU(accumulator + bias)
                  ↓
5. Datapath → Memory: Write result
                  ↓
6. Controller: Increment neuron index, repeat
```

### Load Path (Host → Memory)

```
Host → mlp_top → Memory Subsystem → BRAM
      (addr/data/we)
```

---

## Timing Diagram

```
Clock:     __|‾‾|__|‾‾|__|‾‾|__|‾‾|__|‾‾|__|‾‾|__|‾‾|__|‾‾|__|‾‾|__|‾‾|__|‾‾|

start:     __________|‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾

State:     IDLE____|INIT_|LOAD_|COMPUTE__|ACTIV|STORE|INIT_|...

mac_enable: ______________|‾‾‾‾|_______|‾‾‾‾|____________

mac_valid:  ____________________|‾‾|_________|‾‾|________

act_enable: __________________________|‾‾|_______________

result_valid: ____________________________|‾‾|___________

done:       _______________________________________________|‾‾‾‾‾‾‾
```

---

## Resource Breakdown

| Module | LUTs | FFs | DSPs | BRAM |
|--------|------|-----|------|------|
| **mlp_memory_subsystem** | ~50 | ~100 | 0 | 4 |
| - Input BRAM (4K) | - | - | - | 1 |
| - Weight BRAM (16K) | - | - | - | 2 |
| - Bias BRAM (256) | - | - | - | 0.125 |
| - Output BRAM (4K) | - | - | - | 1 |
| **mlp_compute_datapath** | ~400 | ~300 | 8 | 0 |
| - mac_array_8x | ~200 | ~150 | 8 | 0 |
| - activation_unit | ~150 | ~100 | 0 | 0 |
| - Accumulator | ~50 | ~50 | 0 | 0 |
| **mlp_controller** | ~300 | ~200 | 0 | 0 |
| **mlp_top** (glue logic) | ~50 | ~50 | 0 | 0 |
| **Total** | **~800** | **~650** | **8** | **~4** |

---

## Benefits of Hierarchical Design

### 1. Modularity
- Each module has clear responsibility
- Easier to understand and maintain
- Can test modules independently

### 2. Reusability
- Memory subsystem can be reused for CNN/RNN
- Datapath can be instantiated multiple times
- Controller pattern applicable to other accelerators

### 3. Design Verification
- Unit test each module separately
- `tb_mlp_memory_subsystem.sv`
- `tb_mlp_compute_datapath.sv`
- `tb_mlp_controller.sv`
- `tb_mlp_top.sv` (integration test)

### 4. Flexibility
- Easy to swap activation functions
- Can change memory sizes
- Controller FSM can be modified independently

### 5. Synthesis Optimization
- Each module can be optimized separately
- Better floorplanning with hierarchy
- Easier to add pipeline registers

---

## Comparison: Monolithic vs Hierarchical

| Aspect | mlp_core.sv (Monolithic) | mlp_top.sv (Hierarchical) |
|--------|-------------------------|---------------------------|
| **Lines of Code** | 308 lines | 200 lines (top) + 4 modules |
| **Testability** | Must test entire design | Unit test each module |
| **Readability** | Everything in one file | Clear separation of concerns |
| **Reusability** | Hard to reuse parts | Memory/datapath reusable |
| **Maintenance** | Find bugs in large file | Isolate issues to modules |
| **Synthesis** | One large block | Hierarchical optimization |

---

## File Structure

```
mlp/rtl/
├── mlp_top.sv                  ← Top-level integration
├── mlp_memory_subsystem.sv     ← Memory management
├── mlp_compute_datapath.sv     ← Compute pipeline
├── mlp_controller.sv           ← Control FSM
├── mlp_core.sv                 ← Original (monolithic)
└── mlp_core_refactored.sv      ← Refactored (monolithic with shared modules)

common/rtl/
├── fixed_point_pkg.sv          ← Used by datapath
├── mac_array_8x.sv             ← Used by datapath
└── activation_unit.sv          ← Used by datapath
```

---

## Usage Example

```systemverilog
mlp_top mlp_inst (
    .clk(clk),
    .rst_n(rst_n),

    // Control
    .start(start),
    .done(done),
    .busy(busy),

    // Configuration
    .num_inputs(16'd16),    // 16 inputs
    .num_outputs(16'd8),    // 8 outputs

    // Load inputs
    .input_addr(input_addr),
    .input_data(input_data),
    .input_we(input_we),

    // Load weights
    .weight_addr(weight_addr),
    .weight_data(weight_data),
    .weight_we(weight_we),

    // Load biases
    .bias_addr(bias_addr),
    .bias_data(bias_data),
    .bias_we(bias_we),

    // Outputs
    .output_data(output_data),
    .output_valid(output_valid)
);
```

---

## Future Enhancements

1. **Multi-layer Support**: Add layer chaining capability
2. **Batch Processing**: Process multiple inputs in parallel
3. **Dynamic Configuration**: Runtime layer size changes
4. **Power Gating**: Add power domains for unused blocks
5. **Performance Counters**: Add cycle counters for profiling

---

## Summary

The hierarchical MLP design provides:
✅ Clear module boundaries
✅ Independent testability
✅ Reusable components
✅ Better maintainability
✅ Synthesis optimization opportunities
✅ Scalable architecture for CNN/RNN integration
