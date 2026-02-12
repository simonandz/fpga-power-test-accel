# Research Plan: Design Space Exploration of Neural Network Accelerators on Low-Cost FPGAs

## Paper Working Title
**"Power-Performance Design Space Exploration of Neural Network Accelerators on Resource-Constrained FPGAs with Physical Measurement Validation"**

## Target Venues
- **Primary:** IEEE Access, ACM TRETS
- **Backup (shorter paper):** IEEE Embedded Systems Letters (4-page), IEEE TCAS-II (brief paper)

## Thesis Statement
We present the first systematic, physically-measured power-performance-area design space exploration of parameterized MLP, CNN, and RNN accelerators on a low-cost Artix-7 FPGA, producing Pareto-optimal design guidelines for edge AI deployment and quantifying the accuracy gap between Vivado power estimation and real silicon.

---

## Phase 1: RTL Parameterization (Weeks 1-3)

### 1.1 Parameterize MAC Array Width
**Current state:** Fixed `mac_array_8x` (MLP) and `mac_array_9x` (CNN).

**Goal:** Create a single parameterized `mac_array #(N)` that supports N = 1, 2, 4, 8 parallel MACs.

**What to do:**
- [ ] Create `common/rtl/mac_array.sv` with parameter `NUM_MACS`
- [ ] Reduction tree must adapt: for N=1 no reduction, N=2 one adder, N=4 two-stage, N=8 three-stage
- [ ] Keep the existing 9x array for CNN (3x3 kernel is fixed) OR make CNN use a parameterized version that handles the 3x3 specially
- [ ] Update `mlp_compute_datapath.sv` to use the parameterized MAC
- [ ] Update `mlp_controller.sv` — the `load_offset` width, `load_counter` bounds, and `input_idx` stride all depend on NUM_MACS
- [ ] Update `mlp_top.sv` to expose NUM_MACS as a top-level parameter
- [ ] Testbench: extend `tb_mac_array_8x.sv` to test all NUM_MACS values

**Configurations to sweep:**
| NUM_MACS | Expected DSP usage | Expected behavior |
|----------|-------------------|-------------------|
| 1        | 1 DSP48E1         | Sequential, lowest power, slowest |
| 2        | 2 DSP48E1         | 2-way parallel |
| 4        | 4 DSP48E1         | 4-way parallel |
| 8        | 8 DSP48E1         | Current design (baseline) |

### 1.2 Parameterize Bit-Width
**Current state:** Fixed INT8 inputs/weights, INT16 accumulator.

**Goal:** Support DATA_WIDTH = 4, 8, 16 for inputs/weights, with accumulator width = 2*DATA_WIDTH.

**What to do:**
- [ ] Add parameter `DATA_WIDTH` to `mac_array.sv` — multiply `signed [DATA_WIDTH-1:0]` values
- [ ] Update `activation_unit.sv` — input width becomes `2*DATA_WIDTH`, output width becomes `DATA_WIDTH`. Adjust ReLU/tanh/sigmoid thresholds to scale with DATA_WIDTH
- [ ] Update `mlp_memory_subsystem.sv` — BRAM data width changes with DATA_WIDTH
- [ ] Update `mlp_top.sv`, `mlp_controller.sv` — propagate DATA_WIDTH parameter
- [ ] Update `mlp_power_test_wrapper.sv` — weight/bias/input patterns must fit within DATA_WIDTH
- [ ] For INT4: pack two values per byte in BRAM, or use 4-bit-wide BRAMs (Artix-7 supports RAMB18E1 in various widths)
- [ ] Testbench: verify correct arithmetic at each bit-width, especially overflow/saturation

**Configurations to sweep:**
| DATA_WIDTH | Accumulator | Expected effect |
|------------|-------------|-----------------|
| 4          | 8-bit       | Smallest area, lowest power, least accuracy |
| 8          | 16-bit      | Current baseline |
| 16         | 32-bit      | Highest accuracy, most area/power |

### 1.3 Parameterize Network Size
**Current state:** Fixed 8 inputs, 4 outputs.

**Goal:** Sweep `NUM_INPUTS` and `NUM_OUTPUTS` to vary computation intensity.

**What to do:**
- [ ] This is already parameterized at the `mlp_top` level via `num_inputs`/`num_outputs`
- [ ] Update `mlp_power_test_wrapper.sv` to accept these as top-level parameters instead of localparams
- [ ] Adjust BRAM depth allocations to accommodate larger networks
- [ ] Ensure weight loading logic in the wrapper scales correctly

**Configurations to sweep:**
| Inputs | Outputs | Weights | Compute intensity |
|--------|---------|---------|-------------------|
| 8      | 4       | 32      | Minimal (baseline) |
| 16     | 8       | 128     | Small |
| 32     | 16      | 512     | Medium |
| 64     | 32      | 2048    | Large |
| 128    | 64      | 8192    | Stress test (if fits) |

### 1.4 Complete CNN Accelerator
**Current state:** Core RTL exists (cnn_controller, cnn_compute_datapath, cnn_memory_subsystem, cnn_top), power test wrappers exist. Needs verification and parameterization.

**What to do:**
- [ ] Verify CNN builds and simulates correctly end-to-end
- [ ] Add same parameterization (DATA_WIDTH, NUM_MACS equivalent for CNN)
- [ ] CNN-specific sweep: vary feature map size (8x8, 16x16, 32x32), enable/disable max pooling
- [ ] Run CNN benchmark scripts (`scripts/cnn/run_cnn_benchmark.tcl`)

### 1.5 Add Basic RNN/LSTM Accelerator
**Current state:** Placeholder directory only.

**Goal:** Implement a minimal Elman RNN layer: `h_t = tanh(W_h * h_{t-1} + W_x * x_t + b)`

**What to do:**
- [ ] Create `rnn/rtl/rnn_top.sv`, `rnn_controller.sv`, `rnn_compute_datapath.sv`, `rnn_memory_subsystem.sv`
- [ ] Reuse parameterized MAC array and activation unit (tanh mode already exists)
- [ ] Key difference from MLP: hidden state feedback loop — output feeds back as input for next timestep
- [ ] Add `rnn_power_test_wrapper.sv` following the MLP wrapper pattern
- [ ] Testbench: `rnn/tb/tb_rnn_top.sv`
- [ ] Parameterize: hidden size, sequence length, DATA_WIDTH

**Architecture sketch:**
```
For each timestep t = 0..T-1:
  1. Load x_t from input BRAM
  2. Load h_{t-1} from hidden state BRAM (or register)
  3. Compute W_x * x_t (reuse MAC array)
  4. Compute W_h * h_{t-1} (reuse MAC array)
  5. Add bias, apply tanh activation
  6. Store h_t back to hidden state BRAM
  7. Store output
```

---

## Phase 2: Measurement Infrastructure (Weeks 2-4, overlaps with Phase 1)

### 2.1 Automated Build Sweep Script
**Current state:** Individual TCL build scripts per configuration.

**Goal:** Single master script that iterates over all parameter combinations and produces bitstreams + reports.

**What to do:**
- [ ] Create `scripts/sweep/run_dse_sweep.tcl` (or Python wrapper calling Vivado in batch mode)
- [ ] For each configuration: set parameters → synthesize → implement → generate reports → extract metrics
- [ ] Output: one row per configuration in a CSV file
- [ ] Estimated number of builds: ~60-80 total across all dimensions (this will take time — consider running overnight)

**Script pseudocode:**
```
for arch in [MLP, CNN, RNN]:
  for data_width in [4, 8, 16]:
    for num_macs in [1, 2, 4, 8]:
      for network_size in [small, medium, large]:
        1. Set parameters in TCL
        2. Run synthesis + implementation
        3. Generate power report (default activity)
        4. Generate SAIF from simulation
        5. Generate power report (SAIF-based)
        6. Extract: LUTs, FFs, BRAMs, DSPs, power, timing
        7. Append to results CSV
```

### 2.2 Physical Measurement Protocol
**Goal:** Standardized, repeatable USB power meter measurements for each configuration.

**What to do:**
- [ ] Document exact measurement setup (USB meter model, cable, ambient temperature)
- [ ] For each bitstream:
  1. Program FPGA
  2. Wait 30 seconds for thermal stabilization
  3. Record idle power (SW1 = 0) for 60 seconds, average
  4. Record active power (SW1 = 1, randomize ON) for 60 seconds, average
  5. Record active power (SW1 = 1, randomize OFF) for 60 seconds, average
  6. Log: config ID, idle power, active power (random), active power (fixed), ambient temp
- [ ] Create `scripts/measurement_log_template.csv` with columns for all data points
- [ ] Take 3 measurements per configuration and average (for error bars)

### 2.3 SAIF-Based Power Estimation for All Configs
**Current state:** SAIF generation works for MLP baseline.

**What to do:**
- [ ] Create parameterized SAIF testbenches for each architecture
- [ ] Run simulations to generate SAIF files for each configuration
- [ ] Feed SAIF into Vivado power analysis
- [ ] This gives you three power numbers per config: default estimate, SAIF estimate, physical measurement

---

## Phase 3: Data Collection & Analysis (Weeks 4-6)

### 3.1 Metrics to Collect Per Configuration

| Metric | Source | Unit |
|--------|--------|------|
| LUT utilization | Vivado utilization report | count and % |
| FF utilization | Vivado utilization report | count and % |
| BRAM utilization | Vivado utilization report | count |
| DSP48E1 utilization | Vivado utilization report | count |
| Fmax | Vivado timing report | MHz |
| Inference latency | Perf counters / simulation | cycles |
| Throughput | Calculated: 1/latency * Fmax | inferences/sec |
| GOPS | Calculated: (MACs per inference * 2) * throughput | GOPS |
| Vivado default power | Vivado power report | mW |
| Vivado SAIF power | Vivado power report w/ SAIF | mW |
| Physical total power | USB meter (active - idle) | mW |
| Energy efficiency | GOPS / physical power | GOPS/W |

### 3.2 Extend Python Analysis Script
**Current state:** `extract_per_metrics.py` parses basic Vivado reports.

**What to do:**
- [ ] Extend to parse all report types automatically
- [ ] Add physical measurement data import (from CSV log)
- [ ] Compute derived metrics (GOPS, GOPS/W, efficiency)
- [ ] Output unified results table

### 3.3 Generate Figures

**Must-have figures for the paper:**
1. **Pareto front: GOPS/W vs. GOPS** — each point is one configuration, colored by architecture (MLP/CNN/RNN). This is THE key figure.
2. **Pareto front: Area (LUTs) vs. GOPS/W** — shows area-efficiency tradeoff
3. **Bar chart: Power breakdown** — static vs. dynamic (logic, signal, DSP, BRAM) for selected configurations
4. **Line plot: Bit-width scaling** — power vs. DATA_WIDTH for each architecture, with MAC count as separate lines
5. **Scatter: Vivado estimated vs. physical measured power** — ideally on a y=x line, deviations show estimation error
6. **Heatmap: Parallelism vs. bit-width** — color = GOPS/W, one heatmap per architecture
7. **Table: Top-5 Pareto-optimal configurations** — the "design guidelines" takeaway

**Tools:** Python + matplotlib/seaborn, or LaTeX pgfplots for publication quality.

---

## Phase 4: Paper Writing (Weeks 5-8, overlaps with Phase 3)

### 4.1 Paper Structure (IEEE Access format)

1. **Abstract** (~150 words)
   - Problem: No systematic physical power characterization exists for NN accelerators on low-cost FPGAs
   - Method: Parameterized MLP/CNN/RNN accelerators, swept across bit-width/parallelism/network size
   - Key results: Pareto-optimal configurations, Vivado estimation accuracy gap

2. **Introduction** (1-1.5 pages)
   - Edge AI needs power-efficient inference
   - FPGAs offer reconfigurability but design space is large
   - Gap: existing work uses high-end FPGAs or only EDA-estimated power
   - Contribution: first physically-measured DSE on low-cost FPGA across 3 NN architectures

3. **Related Work** (1-1.5 pages)
   - FPGA NN accelerator surveys
   - Power characterization methods (SAIF, physical measurement)
   - Existing DSE work (mostly on Zynq/high-end — differentiate from yours)

4. **Accelerator Architecture** (2-3 pages)
   - Parameterized design: MAC array, activation unit, memory subsystem, controller
   - MLP, CNN, RNN variants and what differs
   - Parameterization strategy (DATA_WIDTH, NUM_MACS, network size)

5. **Measurement Methodology** (1-2 pages)
   - Physical setup: Basys3, USB power meter, measurement protocol
   - Vivado estimation: default activity vs. SAIF-based
   - How you ensure fair comparison (DONT_TOUCH, same clock, thermal stabilization)

6. **Results and Analysis** (3-4 pages)
   - All the figures from Section 3.3
   - Key findings and design guidelines
   - Vivado estimation accuracy discussion

7. **Discussion** (1 page)
   - Limitations (single FPGA family, small device)
   - Applicability to other devices
   - Recommendations for edge AI designers

8. **Conclusion** (0.5 pages)

### 4.2 Key Claims to Support with Data
- [ ] "INT4 reduces dynamic power by X% compared to INT8 with only Y% accuracy loss"
- [ ] "Doubling MAC parallelism increases throughput by ~2x but power by only Z%"
- [ ] "Vivado default estimation overestimates dynamic power by W% vs. physical measurement"
- [ ] "SAIF-based estimation reduces this gap to V%"
- [ ] "The Pareto-optimal configuration for <1mW dynamic power budget is: ..."
- [ ] "CNN achieves X% better GOPS/W than MLP for equivalent resource usage due to data reuse"

---

## Phase 5 (Stretch Goal): Side-Channel Security Analysis (Option B)

**Only pursue if Phases 1-4 are complete and time permits.**

### Motivation
If power consumption varies measurably with input data, an attacker monitoring FPGA power could infer properties of the input (e.g., sparsity, magnitude distribution). This is a known concern in cryptographic hardware but largely unexplored for NN accelerators on FPGAs.

### What You'd Need
- An oscilloscope + shunt resistor (or current probe) on the FPGA Vccint rail for high-resolution traces
- Alternatively, a higher-resolution USB meter with logging capability (>10 samples/sec)

### Minimal Viable Experiment
1. Fix one accelerator config (e.g., MLP, INT8, 8 MACs)
2. Run inference with controlled input classes:
   - All-zeros input
   - All-ones input (max switching)
   - Sparse input (90% zeros)
   - Dense random input
   - Structured pattern (e.g., ramp)
3. Collect power traces for 100+ inferences per class
4. Apply statistical test (t-test or KL divergence) to check if power distributions differ between classes
5. If significant: report leakage magnitude and discuss implications
6. If not significant: report as a negative result (still publishable — "INT8 accelerators on Artix-7 do not exhibit measurable data-dependent power leakage at USB-meter resolution")

### What This Could Become
- A second paper targeting IEEE HOST, CHES, or TIFS
- A section in the main paper under "Security Implications"
- At minimum: one paragraph in the Discussion section noting that data-dependent power variation was/wasn't observed

---

## Timeline Summary

| Week | Phase 1 (RTL) | Phase 2 (Infra) | Phase 3 (Data) | Phase 4 (Paper) |
|------|--------------|-----------------|----------------|-----------------|
| 1    | Parameterize MAC array | | | |
| 2    | Parameterize bit-width, network size | Build sweep script | | |
| 3    | CNN verification, RNN implementation | Measurement protocol | | |
| 4    | Final RTL testing | SAIF generation | Start measurements | |
| 5    | Bug fixes | | Complete measurements | Start writing |
| 6    | | | Analysis + figures | Architecture + methodology |
| 7    | | | | Results + discussion |
| 8    | | | | Polish + submit |

## Risk Mitigation
- **Risk:** Too many configurations → builds take forever
  - **Mitigation:** Prioritize MLP sweep first (simplest). Do CNN/RNN with fewer configs. Run builds overnight.
- **Risk:** INT4 doesn't work well with Artix-7 BRAMs
  - **Mitigation:** Can pack two INT4 values per byte. Worst case, drop INT4 and report INT8/INT16 only.
- **Risk:** RNN takes too long to implement
  - **Mitigation:** Paper is still strong with MLP + CNN only. RNN is a "nice to have" for the third architecture.
- **Risk:** Physical measurements show too little variation between configs
  - **Mitigation:** Dynamic power is small on Artix-7. Report it as a finding: "static power dominates on low-cost FPGAs, making the choice of accelerator architecture less important than expected for total system power." This is still a publishable insight.
