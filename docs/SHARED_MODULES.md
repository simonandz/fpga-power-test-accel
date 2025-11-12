# Shared Accelerator Modules

## Overview

Common hardware modules shared across MLP, CNN, and RNN accelerators to promote code reuse, reduce development time, and ensure consistent behavior across different accelerator types.

## Module Hierarchy

```
common/rtl/
├── fixed_point_pkg.sv      - Q4.4 fixed-point arithmetic utilities
├── mac_array_8x.sv         - 8-way parallel MAC array
├── activation_unit.sv      - Multi-function activation unit
└── bram_bank.sv            - Memory block (existing)

mlp/rtl/
├── mlp_core.sv             - Original MLP implementation
└── mlp_core_refactored.sv  - MLP using shared modules
```

---

## 1. Fixed-Point Package (`fixed_point_pkg.sv`)

**Purpose**: Centralized Q4.4 fixed-point arithmetic utilities.

**Q4.4 Format**:
- 4 integer bits, 4 fractional bits
- Range: -8.0 to +7.9375
- Precision: 0.0625 (1/16)

**Key Functions**:

| Function | Description | Example |
|----------|-------------|---------|
| `int_to_q44()` | Convert integer to Q4.4 | `int_to_q44(5)` → `0x50` (5.0) |
| `q44_to_int()` | Convert Q4.4 to integer | `q44_to_int(0x50)` → `5` |
| `add_bias_q44()` | Add bias with scaling | Adds bias << 4 to accumulator |
| `saturate_to_q44()` | Saturate 16-bit to 8-bit | Clamps to [0, 255] |
| `relu_q44()` | ReLU activation | max(0, x) with saturation |
| `mul_q44()` | Multiply Q4.4 values | Returns saturated Q4.4 |
| `max_q44()`/`min_q44()` | Max/min of two values | For pooling operations |
| `float_to_q44()` | Float to Q4.4 (testbench) | For test data generation |
| `q44_to_float()` | Q4.4 to float (testbench) | For result verification |

**Constants**:
```systemverilog
Q44_ZERO   = 8'h00   // 0.0
Q44_ONE    = 8'h10   // 1.0
Q44_HALF   = 8'h08   // 0.5
Q44_NEG_ONE = 8'hF0  // -1.0
Q44_MAX    = 8'h7F   // 7.9375
Q44_MIN    = 8'h80   // -8.0
```

**Usage Example**:
```systemverilog
import fixed_point_pkg::*;

// In your module
logic signed [15:0] biased_result;
logic [7:0] output_val;

biased_result = add_bias_q44(accumulator, bias);
output_val = relu_q44(biased_result);
```

---

## 2. MAC Array (`mac_array_8x.sv`)

**Purpose**: 8-way parallel multiply-accumulate operations using DSP48E1 blocks.

**Features**:
- Processes 8 input×weight pairs simultaneously
- Pipelined 4-stage design for high throughput
- Tree-structured reduction for optimal timing
- Clear accumulator control for starting new computations

**Interface**:
```systemverilog
module mac_array_8x (
    input  logic         clk,
    input  logic         rst_n,
    input  logic         enable,         // Start MAC operation
    input  logic         clear_acc,      // Reset accumulator
    input  logic [7:0]   data_in[0:7],   // 8 input values
    input  logic [7:0]   weight_in[0:7], // 8 weights
    output logic signed [15:0] mac_out[0:7],    // Individual products
    output logic signed [15:0] partial_sum,     // Sum of all 8 products
    output logic         valid           // Output valid flag
);
```

**Pipeline Stages**:
1. **Stage 1**: Multiply (8 DSP blocks) - `products[i] = data_in[i] * weight_in[i]`
2. **Stage 2**: Reduce 8→4 (4 adders) - `sum_stage1[i] = products[2*i] + products[2*i+1]`
3. **Stage 3**: Reduce 4→2 (2 adders) - `sum_stage2[i] = sum_stage1[2*i] + sum_stage1[2*i+1]`
4. **Stage 4**: Reduce 2→1 (1 adder) - `partial_sum = sum_stage2[0] + sum_stage2[1]`

**Latency**: 4 clock cycles from `enable` to `valid`

**Throughput**: 1 MAC operation per cycle (after pipeline fill)

**Resource Usage**:
- 8× DSP48E1 blocks (for multipliers)
- 7× fabric adders (for tree reduction)
- ~200 LUTs, ~150 FFs

**Usage Example**:
```systemverilog
mac_array_8x mac_inst (
    .clk(clk),
    .rst_n(rst_n),
    .enable(mac_enable),
    .clear_acc(1'b0),
    .data_in(inputs),      // Load 8 inputs
    .weight_in(weights),   // Load 8 weights
    .mac_out(products),    // Individual products available
    .partial_sum(sum),     // Total sum output
    .valid(mac_valid)      // Result ready
);

// Accumulate results over multiple MAC operations
if (mac_valid) begin
    accumulator <= accumulator + sum;
end
```

---

## 3. Activation Unit (`activation_unit.sv`)

**Purpose**: Configurable activation functions for neural networks.

**Supported Activations**:

| Type | Code | Function | Use Case |
|------|------|----------|----------|
| ReLU | `2'b00` | max(0, x) | MLP, CNN (default) |
| tanh | `2'b01` | 3-segment PWL tanh | RNN (LSTM, GRU) |
| Sigmoid | `2'b10` | 3-segment PWL sigmoid | RNN gates |
| None | `2'b11` | Pass-through | Testing, linear layers |

**Interface**:
```systemverilog
module activation_unit (
    input  logic         clk,
    input  logic         rst_n,
    input  logic [1:0]   activation_type,  // Select activation
    input  logic         enable,           // Enable computation
    input  logic signed [15:0] data_in,    // 16-bit input (with bias)
    output logic [7:0]   data_out,         // 8-bit activated output
    output logic         valid             // Output valid
);
```

**ReLU Implementation**:
```systemverilog
if (data_in < 0)
    result = 0
else
    result = saturate(data_in)
```

**tanh Approximation** (Piecewise Linear):
- Region 1: `|x| < 0.5` → `tanh(x) ≈ x` (linear)
- Region 2: `0.5 ≤ |x| ≤ 2.0` → `tanh(x) ≈ sign(x) * (0.5 + 0.25*|x|)`
- Region 3: `|x| > 2.0` → `tanh(x) ≈ sign(x)` (saturate to ±1.0)

**Sigmoid Approximation**:
- `σ(x) ≈ 0.5 + x/4` for `|x| < 2`
- `σ(x) ≈ 1.0` for `x > 2`
- `σ(x) ≈ 0.0` for `x < -2`

**Latency**: 2 clock cycles

**Resource Usage**: ~150 LUTs, ~100 FFs

**Usage Example**:
```systemverilog
activation_unit act_inst (
    .clk(clk),
    .rst_n(rst_n),
    .activation_type(2'b00),      // ReLU
    .enable(compute_done),
    .data_in(acc_with_bias),      // 16-bit accumulator + bias
    .data_out(activated_output),  // 8-bit result
    .valid(activation_valid)
);
```

---

## 4. Integration Example: MLP Core

**Original MLP** (`mlp_core.sv`):
- Self-contained MAC operations
- Inline ReLU implementation
- ~11KB of code

**Refactored MLP** (`mlp_core_refactored.sv`):
- Uses `mac_array_8x` for computation
- Uses `activation_unit` for ReLU
- Uses `fixed_point_pkg` utilities
- ~8KB of code
- More maintainable and testable

**Comparison**:

| Aspect | Original | Refactored | Benefit |
|--------|----------|------------|---------|
| Code size | 11KB | 8KB | 27% reduction |
| MAC implementation | Inline | Module | Reusable |
| Activation | Inline | Module | Configurable |
| Fixed-point ops | Manual | Package | Consistent |
| Testability | Monolithic | Modular | Unit testable |
| CNN/RNN reuse | No | Yes | Faster development |

---

## 5. Benefits for CNN and RNN

**CNN Accelerator** can reuse:
- `mac_array_8x` for 3×3 convolution (9 MACs needed, use 2 arrays)
- `activation_unit` for ReLU after convolution
- `fixed_point_pkg` for pooling operations (`max_q44` for max pooling)

**RNN Accelerator** can reuse:
- `mac_array_8x` for input and recurrent matrix multiplications
- `activation_unit` with tanh/sigmoid for gates
- `fixed_point_pkg` for element-wise operations

---

## 6. Testing Strategy

**Unit Tests** (create in `common/tb/`):
- `tb_mac_array_8x.sv` - Test MAC with known vectors
- `tb_activation_unit.sv` - Test all activation functions
- `tb_fixed_point_pkg.sv` - Test utility functions

**Integration Test**:
- `tb_mlp_core_refactored.sv` - Verify refactored MLP matches original

**Test Vectors**:
```systemverilog
import fixed_point_pkg::*;

// Generate test data
logic [7:0] test_input  = float_to_q44(2.5);   // 2.5 → 0x28
logic [7:0] test_weight = float_to_q44(-1.0);  // -1.0 → 0xF0

// Verify results
real result = q44_to_float(output);
if (abs(result - expected) < 0.1) $display("PASS");
```

---

## 7. Migration Guide

**For existing accelerators**:

1. **Add package import**:
   ```systemverilog
   import fixed_point_pkg::*;
   ```

2. **Replace MAC loops** with `mac_array_8x` instantiation

3. **Replace activation logic** with `activation_unit` instantiation

4. **Use package functions** for fixed-point operations

5. **Test thoroughly** - verify results match original implementation

**For new accelerators**:

1. Start with shared modules from day 1
2. Focus on accelerator-specific control logic
3. Reuse MAC and activation modules directly
4. Add new functions to package if needed

---

## 8. File Locations

```
common/rtl/
├── fixed_point_pkg.sv        - Import this in all accelerators
├── mac_array_8x.sv           - Instantiate for MAC operations
├── activation_unit.sv        - Instantiate for activation
└── bram_bank.sv              - Memory blocks

mlp/rtl/
├── mlp_core.sv               - Original (keep for reference)
└── mlp_core_refactored.sv    - New implementation

cnn/rtl/
└── cnn_core.sv               - Will use shared modules

rnn/rtl/
└── rnn_core.sv               - Will use shared modules
```

---

## 9. Next Steps

- [ ] Create unit testbenches for shared modules
- [ ] Validate refactored MLP against original
- [ ] Update simulation scripts to include shared modules
- [ ] Document CNN integration with shared modules
- [ ] Document RNN integration with shared modules
- [ ] Create synthesis scripts that include shared modules
- [ ] Measure resource savings from code reuse

---

## 10. Summary

**Shared modules provide**:
- ✅ Code reuse across MLP, CNN, RNN
- ✅ Consistent fixed-point behavior
- ✅ Unit-testable components
- ✅ Faster development for new accelerators
- ✅ Easier maintenance and debugging
- ✅ Resource-efficient implementations

**Usage pattern**:
1. Import `fixed_point_pkg` for utilities
2. Instantiate `mac_array_8x` for parallel MAC
3. Instantiate `activation_unit` for activation
4. Focus on accelerator-specific control FSM

This modular approach significantly reduces development time and ensures consistent behavior across all accelerator types!
