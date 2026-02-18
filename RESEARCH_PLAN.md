# Research Plan: Timeloop/Accelergy-Driven CNN Accelerator DSE with Physical Measurement Validation

## Paper Working Title
**"Closing the Loop: Validating Timeloop/Accelergy Energy Models Against Physical FPGA Measurements for CNN Accelerator Design Space Exploration"**

## Target Venues
- **Primary:** IEEE Access, ACM TRETS
- **Backup (shorter):** IEEE Embedded Systems Letters (4-page), IEEE TCAS-II (brief)

## Core Thesis
We model a parameterized CNN accelerator in Timeloop/Accelergy, use its mapper to identify Pareto-optimal dataflow mappings, implement those configurations on a Basys3 Artix-7 FPGA, and validate the analytical energy predictions against both Vivado power estimates and physical USB power meter measurements — providing the first three-way comparison for CNN accelerators on low-cost FPGAs.

## Why This Is Publishable
1. **Timeloop/Accelergy is widely used but rarely validated against physical hardware** — especially not FPGAs
2. **Three-way comparison** (analytical model vs. EDA tool vs. silicon) doesn't exist in literature
3. **Pareto curves grounded in real measurements** are immediately useful to edge AI designers
4. **Low-cost FPGA focus** (Artix-7) fills a gap — most Timeloop papers target ASIC or high-end FPGA

---

## Phase 1: Timeloop/Accelergy Setup & Architecture Modeling (Weeks 1-2)

### 1.1 Install Timeloop/Accelergy Infrastructure

**What to do:**
- [ ] Install via Docker: `docker pull accelergy/timeloop-accelergy-infrastructure`
  - OR install natively (Python + C++ build, more involved)
  - Docker is recommended — avoids dependency hell
- [ ] Clone exercise repo: `git clone https://github.com/Accelergy-Project/timeloop-accelergy-exercises`
- [ ] Run the provided simple examples (1D conv, simple PE array) to learn the YAML format
- [ ] Read the ISPASS 2020 tutorial slides for conceptual understanding:
  - Part 1: https://accelergy.mit.edu/ispass2020/2020_08_23_timeloop_accelergy_tutorial_part1.pdf
  - Part 2: https://accelergy.mit.edu/ispass2020/2020_08_23_timeloop_accelergy_tutorial_part2.pdf

### 1.2 Model Your CNN Accelerator Architecture in Timeloop YAML

Your CNN accelerator has this hierarchy (from `cnn_top.sv`):
```
Off-chip (host loads via wrapper)
  └── Input BRAM     (256 × 8-bit, 16×16 feature map)
  └── Kernel BRAM    (9 × 8-bit, 3×3 weights)
  └── Bias register  (1 × 8-bit)
  └── Output BRAM    (256 × 8-bit, output feature map)
  └── MAC array      (9-way parallel, one-shot convolution)
      └── 9× DSP48E1 multipliers
      └── Reduction tree (4→2→1 adder stages)
```

**What to create — `timeloop/arch/cnn_accel.yaml`:**
```yaml
architecture:
  version: 0.4
  nodes:
    - !Container
      name: system
      - !Component
        name: DRAM           # Represents off-chip (host load interface)
        class: DRAM
        attributes:
          width: 8
          datawidth: 8

    - !Container
      name: global_buffer    # Your BRAM subsystem
      - !Component
        name: ifmap_sram
        class: SRAM
        attributes:
          depth: 256         # 16×16 feature map
          width: 8
          word-bits: 8
          block-size: 1
      - !Component
        name: weight_sram
        class: SRAM
        attributes:
          depth: 9           # 3×3 kernel
          width: 8
          word-bits: 8
      - !Component
        name: ofmap_sram
        class: SRAM
        attributes:
          depth: 256         # output feature map
          width: 8
          word-bits: 8

    - !Container
      name: PE
      spatial: {meshX: 9}   # 9 parallel MACs
      - !Component
        name: mac
        class: intmac
        attributes:
          datawidth: 8       # INT8
```

**Key decisions:**
- Model the 9-way MAC array as 9 spatial PEs (each with one MAC) — this matches your `mac_array_9x.sv`
- BRAM modeled as SRAM with Artix-7 energy characteristics
- Weight SRAM is small (9 entries) — kernel is fully loaded before compute

### 1.3 Create Artix-7 Energy Tables for Accelergy

Accelergy doesn't have built-in FPGA component models. You need to provide energy-per-access values using the **table-based plug-in**.

**What to create — `timeloop/energy/artix7_components.csv`:**

| Component | Action | Energy (pJ) | Source |
|-----------|--------|-------------|--------|
| BRAM (RAMB18E1) read | read | ~5-10 pJ | Xilinx DS181 datasheet + Vivado power breakdown |
| BRAM (RAMB18E1) write | write | ~5-10 pJ | Xilinx DS181 datasheet |
| DSP48E1 multiply | compute | ~3-5 pJ | Xilinx DS181 datasheet |
| Register read | read | ~0.5 pJ | Estimated from CLB power |
| Register write | write | ~0.5 pJ | Estimated from CLB power |
| Interconnect/routing | transfer | ~1-2 pJ | From Vivado signal power |

**How to get these numbers:**
- [ ] Extract from your existing Vivado power reports (`reports/benchmark/power_saif.txt`) — they break down power by component type (BRAM, DSP, Signal, Logic)
- [ ] Cross-reference with Xilinx DS181 (Artix-7 DC/AC Switching Characteristics) datasheet
- [ ] Calculate: energy_per_access = (component_power_mW) / (access_rate_MHz) × 1000 to get pJ
- [ ] These don't need to be perfectly accurate — the whole point of the paper is comparing these estimates against your physical measurements

### 1.4 Define the CNN Workload in Timeloop Format

Your CNN computes: 3×3 convolution on a 16×16 input with stride=1, padding=1.

**What to create — `timeloop/problem/conv2d_3x3.yaml`:**
```yaml
problem:
  shape:
    name: Conv2D
    dimensions: [R, S, P, Q, C, K, N]
    coefficients:
      - name: Wstride
        default: 1
      - name: Hstride
        default: 1
    data-spaces:
      - name: Weights
        projection: [[C], [K], [R], [S]]
      - name: Inputs
        projection: [[N], [C], [R, Hstride, P], [S, Wstride, Q]]
      - name: Outputs
        projection: [[N], [K], [P], [Q]]
  instance:
    R: 3              # kernel height
    S: 3              # kernel width
    P: 16             # output height (with pad=1, stride=1, same as input)
    Q: 16             # output width
    C: 1              # input channels (single-channel for now)
    K: 1              # output channels (single filter)
    N: 1              # batch size
    Wstride: 1
    Hstride: 1
```

**Additional workload variants to sweep:**
| Config | P×Q (output) | C | K | Description |
|--------|-------------|---|---|-------------|
| tiny   | 8×8         | 1 | 1 | Minimal workload |
| base   | 16×16       | 1 | 1 | Current design (baseline) |
| multi-C| 16×16       | 3 | 1 | Multi-channel input (RGB) |
| multi-K| 16×16       | 1 | 4 | Multiple output filters |
| large  | 32×32       | 1 | 1 | Larger feature map |
| real   | 16×16       | 3 | 8 | Realistic first conv layer |

---

## Phase 2: Timeloop Mapper — Design Space Exploration (Weeks 2-3)

### 2.1 Run Timeloop Mapper to Find Optimal Mappings

**What to do:**
- [ ] Configure the mapper to explore:
  - Loop orderings (which dimension is innermost/outermost)
  - Tiling factors (how data is partitioned across memory levels)
  - Spatial mappings (how work is distributed across the 9 MACs)
- [ ] Run: `timeloop-mapper arch.yaml problem.yaml mapper.yaml`
- [ ] Timeloop outputs for each mapping: energy, cycles, data movement per level

**What to create — `timeloop/mapper/mapper_config.yaml`:**
```yaml
mapper:
  optimization-metrics: [delay, energy]
  num-threads: 8
  timeout: 1000        # seconds
  victory-condition: 500
```

### 2.2 Generate Pareto-Optimal Set from Timeloop

**What to do:**
- [ ] Collect all Timeloop mapping results
- [ ] Plot energy vs. latency (cycles) — Timeloop does this internally
- [ ] Identify the Pareto front: mappings where no other mapping is better in both energy AND latency
- [ ] Select 8-12 representative Pareto-optimal points to implement on FPGA

**Key dataflow families to identify on the Pareto front:**
| Dataflow style | Behavior | Expected tradeoff |
|---------------|----------|-------------------|
| Output-stationary | Accumulate into output, reload inputs/weights | Low output BRAM traffic, more input reads |
| Weight-stationary | Keep weights in registers, stream inputs | Low weight BRAM reads, good for reuse |
| Row-stationary (Eyeriss-style) | Maximize all reuse within PE | Best energy, possibly more complex control |
| Input-stationary | Keep input patch, cycle through filters | Useful for multi-K configs |

### 2.3 Sweep Architecture Variants in Timeloop

Beyond dataflow, also sweep hardware parameters:

**What to vary:**
- [ ] Number of MACs: 1, 3, 9 (1×1, 1×3, 3×3 spatial)
- [ ] Buffer sizes: vary BRAM allocation between input/weight/output
- [ ] Bit-width: model INT4, INT8, INT16 (change `datawidth` in YAML, adjust energy tables)

For each combination: run mapper → get Pareto front → select best points.

**Estimated total Timeloop runs:** ~30-50 (fast — minutes each, not hours)

---

## Phase 3: FPGA Implementation of Pareto-Optimal Configs (Weeks 3-5)

### 3.1 Map Timeloop Configurations to RTL Parameters

Each Pareto-optimal point from Timeloop implies specific RTL parameter settings.

**Mapping table:**
| Timeloop parameter | RTL parameter | File to modify |
|-------------------|---------------|----------------|
| Spatial PEs = N | NUM_MACS (new param) | `mac_array_9x.sv` → parameterized `mac_array.sv` |
| Input buffer depth | BRAM depth | `cnn_memory_subsystem.sv` |
| Datawidth = W | DATA_W parameter | `cnn_top.sv` (already has DATA_W=8) |
| Feature map P×Q | IMG_W, IMG_H params | `cnn_top.sv` (already parameterized) |
| Loop ordering | Controller FSM schedule | `cnn_controller.sv` |

### 3.2 Parameterize CNN RTL (if not already)

Your CNN is already well-parameterized (`cnn_top.sv` has IMG_W, IMG_H, KER_SIZE, STRIDE, PAD, DATA_W, ACC_W as parameters). Main work needed:

**What to do:**
- [ ] **Parameterize MAC count:** Create `mac_array_Nx.sv` with parameter `NUM_MACS`. For N < 9, the controller must iterate multiple cycles to accumulate the full 3×3 convolution (partial sum accumulation). Update `cnn_controller.sv` to handle partial MAC passes.
- [ ] **Parameterize bit-width:** DATA_W already exists in `cnn_top.sv`. Propagate it down to:
  - `mac_array.sv` (multiply width)
  - `activation_unit.sv` (threshold scaling)
  - `cnn_memory_subsystem.sv` (BRAM data width)
  - `cnn_power_test_wrapper.sv` (weight/input patterns)
- [ ] **Verify each configuration builds and simulates** — use `scripts/cnn/test_all_cnn_modules.tcl`

### 3.3 Automated Build Sweep

**What to create — `scripts/sweep/run_cnn_dse.tcl` (or `run_cnn_dse.py`):**

```
For each Pareto-optimal config from Timeloop:
  1. Set RTL parameters (DATA_W, IMG_W, IMG_H, NUM_MACS)
  2. Run synthesis + implementation
  3. Generate SAIF from simulation
  4. Generate Vivado power report (default + SAIF)
  5. Extract: LUTs, FFs, BRAMs, DSPs, Fmax, power
  6. Append to results/cnn_dse_results.csv
```

- [ ] Create the sweep script based on existing `scripts/mlp/run_benchmark.tcl` (adapt for CNN + parameterized configs)
- [ ] Estimated builds: 8-12 Pareto-optimal configs × (default + SAIF power) = 16-24 Vivado runs
- [ ] Each build takes ~10-20 min → run overnight (~4-8 hours total)

### 3.4 Physical Measurements

**What to do for each configuration:**
- [ ] Program Basys3 with the bitstream
- [ ] Measurement protocol (same as MLP, from existing infrastructure):
  1. Wait 30 seconds for thermal stabilization
  2. Idle power: SW1=0, record 60 seconds, average
  3. Active power (random inputs): SW1=1, SW15=1, record 60 seconds, average
  4. Active power (fixed inputs): SW1=1, SW15=0, record 60 seconds, average
  5. Repeat 3× per config for error bars
- [ ] Log all measurements in `results/physical_measurements.csv`

**Columns:**
```
config_id, num_macs, data_width, img_size, timeloop_energy_pJ, vivado_power_default_mW, vivado_power_saif_mW, physical_idle_mW, physical_active_random_mW, physical_active_fixed_mW, luts, ffs, brams, dsps, fmax_mhz, latency_cycles
```

---

## Phase 4: Three-Way Comparison & Analysis (Weeks 5-6)

### 4.1 Metrics to Compare

For each Pareto-optimal configuration, you have THREE energy estimates:

| Source | What it gives | Granularity |
|--------|--------------|-------------|
| **Timeloop/Accelergy** | Energy per inference (pJ), broken down by component and data movement | Per-component, per-action |
| **Vivado (SAIF)** | Dynamic + static power (mW), broken down by resource type | Per-resource-type (BRAM, DSP, Logic, Signal) |
| **USB Power Meter** | Total board power (mW), active minus idle = accelerator dynamic power | Total only |

**Derived metrics to compute:**
| Metric | Formula |
|--------|---------|
| Timeloop energy/inference | Direct from Timeloop output |
| Vivado energy/inference | Vivado_dynamic_power × latency_cycles / clock_freq |
| Physical energy/inference | (Active_power - Idle_power) × latency_cycles / clock_freq |
| Throughput | clock_freq / latency_cycles |
| GOPS | (MACs_per_inference × 2) × throughput |
| GOPS/W | GOPS / physical_dynamic_power |

### 4.2 Figures to Generate

**Figure 1: Pareto Front — Energy vs. Latency (THE key figure)**
- Each point = one configuration
- Three curves overlaid: Timeloop prediction (line), Vivado SAIF (markers), Physical (markers with error bars)
- Shows whether Timeloop's Pareto front holds up against real measurements

**Figure 2: Estimation Accuracy Scatter Plot**
- X-axis: Physical measured energy/inference
- Y-axis: Timeloop predicted energy/inference (blue) and Vivado SAIF energy (orange)
- Ideal = y=x line
- Shows systematic over/under-estimation by each tool

**Figure 3: Estimation Error Bar Chart**
- Per-configuration bars showing: % error of Timeloop vs. physical, % error of Vivado vs. physical
- Grouped by configuration

**Figure 4: Power Breakdown Comparison**
- Stacked bar chart: BRAM vs. DSP vs. Logic vs. Signal power
- Timeloop breakdown vs. Vivado breakdown side by side
- For 3-4 selected configs (e.g., smallest, baseline, largest)

**Figure 5: GOPS/W Pareto Front**
- GOPS/W vs. area (LUTs) for each config
- Based on physical measurements
- Annotated with "design guidelines" for different power budgets

**Figure 6 (optional): Dataflow Impact**
- If you test multiple loop orderings for the same hardware config
- Bar chart: energy for weight-stationary vs. output-stationary vs. row-stationary
- Shows which dataflow Timeloop picks matches what's actually best on silicon

### 4.3 Key Claims to Support

- [ ] "Timeloop/Accelergy predicts CNN accelerator energy within X% of physical measurements on Artix-7"
- [ ] "Vivado SAIF-based estimation achieves Y% accuracy vs. physical measurements"
- [ ] "Timeloop's Pareto-optimal mappings remain optimal when validated against real silicon"
  - OR: "Z% of Timeloop's predicted Pareto-optimal points are suboptimal on real hardware due to [routing/clock tree/static power effects]"
- [ ] "For sub-W power budgets on Artix-7, the optimal CNN configuration is: [N MACs, INT-W, X×X feature map]"
- [ ] "Static power dominates on Artix-7 (70 mW vs. ~17 mW dynamic), making dataflow choice less impactful than on ASIC targets"

---

## Phase 5: Paper Writing (Weeks 5-8, overlaps with Phase 4)

### 5.1 Paper Structure (IEEE Access format, ~10-12 pages)

1. **Abstract** (~150 words)
   - Gap: Timeloop/Accelergy widely used but never validated against physical FPGA measurements
   - Method: Model CNN accel in Timeloop, build Pareto-optimal configs on Basys3, three-way compare
   - Key result: Timeloop predicts within X%, identifies correct Pareto-optimal configs

2. **Introduction** (1-1.5 pages)
   - Edge AI needs efficient CNN inference on low-cost FPGAs
   - Timeloop/Accelergy enables fast analytical DSE but accuracy on FPGAs is unknown
   - Vivado power estimation exists but has known limitations
   - **Contribution:** First physical validation of Timeloop on an FPGA CNN accelerator

3. **Background & Related Work** (1.5 pages)
   - Timeloop/Accelergy framework and how it works
   - FPGA CNN accelerator designs (Eyeriss, TPU-lite, etc.)
   - Existing FPGA power characterization methods
   - **Gap:** No paper validates Timeloop against physical FPGA measurements

4. **CNN Accelerator Architecture** (2 pages)
   - Parameterized design: MAC array, BRAM subsystem, controller FSM
   - How it maps to Timeloop's architecture model
   - Parameterization strategy and configuration space

5. **Methodology** (2 pages)
   - Timeloop modeling: architecture YAML, energy tables, mapper config
   - Vivado flow: synthesis, SAIF simulation, power reporting
   - Physical measurement: Basys3 setup, USB meter protocol, calibration
   - How energy is computed from each source for fair comparison

6. **Results** (3-4 pages)
   - All figures from Section 4.2
   - Detailed comparison tables
   - Accuracy analysis: where does Timeloop get it right/wrong?
   - Design guidelines for edge deployment

7. **Discussion** (1 page)
   - Why Timeloop over/under-estimates on FPGAs (routing overhead, clock tree, static power)
   - Limitations: single FPGA family, single-channel CNN, small device
   - How to improve Timeloop's FPGA accuracy (better energy tables, routing models)

8. **Conclusion** (0.5 pages)

### 5.2 Related Work to Cite
- Parashar et al., "Timeloop: A Systematic Approach to DNN Accelerator Evaluation" (ISPASS 2019)
- Wu et al., "Accelergy: An Architecture-Level Energy Estimation Methodology" (ICCAD 2019)
- Chen et al., "Eyeriss: A Spatial Architecture for Energy-Efficient Dataflow" (ISCA 2016)
- Samajdar et al., "MAESTRO: A Data-Centric Approach" (MICRO 2020)
- Any FPGA CNN accelerator papers on Artix-7 or similar low-cost devices
- Xilinx/AMD power estimation methodology papers

---

## Phase 6 (Stretch Goal): Synthesis Optimization vs. Power Measurement Fidelity

**Only pursue if Phases 1-5 are complete and time permits.**

### Motivation
Your RTL uses `DONT_TOUCH = "TRUE"` extensively to prevent synthesis from optimizing away logic during power measurement. But how much does this actually affect the results?

### Experiment Design
1. Pick 3-4 CNN configurations from the main study
2. Build each twice:
   - **Build A:** With `DONT_TOUCH` on all submodules (your current approach)
   - **Build B:** Without `DONT_TOUCH` (normal synthesis optimization)
3. For each build, collect:
   - Resource utilization (LUTs, FFs, DSPs, BRAMs)
   - Vivado power estimate (default + SAIF)
   - Physical power measurement (same protocol)
4. Compare:
   - Does optimization reduce resource usage significantly?
   - Does it change the power measurement? By how much?
   - Does it invalidate the Timeloop comparison?

### Why This Is Novel
- Every FPGA power measurement paper implicitly assumes their synthesis settings are "correct"
- Nobody has quantified the measurement error introduced by DONT_TOUCH vs. normal optimization
- This is a **methodology contribution** that benefits the entire FPGA power characterization community
- Could be a standalone 4-page IEEE ESL letter or a section in the main paper

### What to Report
- Table: per-config, DONT_TOUCH vs. optimized: utilization delta, power delta
- Recommendation: when is DONT_TOUCH necessary and when does it distort results?
- This strengthens the main paper's methodology section regardless

---

## Timeline Summary

| Week | Phase 1 | Phase 2 | Phase 3 | Phase 4 | Phase 5 |
|------|---------|---------|---------|---------|---------|
| 1 | Install Timeloop, tutorials, model architecture | | | | |
| 2 | Energy tables, workload YAML | Run mapper, explore mappings | | | |
| 3 | | Pareto identification | Start RTL parameterization | | |
| 4 | | | Build sweep, SAIF generation | | |
| 5 | | | Physical measurements | Start analysis | Start writing |
| 6 | | | | Figures, comparison | Architecture + methodology |
| 7 | | | | | Results + discussion |
| 8 | | | | | Polish + submit |

## File Structure for New Work

```
fpga-power-test-accel/
├── timeloop/                          # NEW — all Timeloop/Accelergy files
│   ├── arch/
│   │   ├── cnn_accel_9mac.yaml       # 9-MAC baseline architecture
│   │   ├── cnn_accel_3mac.yaml       # 3-MAC variant
│   │   └── cnn_accel_1mac.yaml       # 1-MAC variant
│   ├── problem/
│   │   ├── conv2d_16x16.yaml         # Baseline 16×16 workload
│   │   ├── conv2d_8x8.yaml           # Small workload
│   │   └── conv2d_32x32.yaml         # Large workload
│   ├── mapper/
│   │   └── mapper_config.yaml
│   ├── energy/
│   │   ├── artix7_components.csv      # FPGA-specific energy tables
│   │   └── energy_derivation.md       # How values were obtained
│   └── results/
│       └── timeloop_pareto.csv        # Collected mapper outputs
├── scripts/
│   └── sweep/
│       ├── run_cnn_dse.tcl            # Vivado build sweep
│       └── collect_results.py         # Parse reports → CSV
├── results/
│   ├── cnn_dse_results.csv            # Unified results (all 3 sources)
│   ├── physical_measurements.csv      # USB meter raw data
│   └── figures/                       # Generated plots
│       ├── pareto_energy_latency.pdf
│       ├── estimation_accuracy.pdf
│       └── ...
└── paper/
    ├── main.tex                       # IEEE Access LaTeX template
    └── figures/
```

## Risk Mitigation

| Risk | Mitigation |
|------|------------|
| **Timeloop doesn't model FPGAs well** | That's actually a finding! "Timeloop's ASIC-oriented model has X% error on FPGAs due to Y" is a useful contribution |
| **Energy table values for Artix-7 are inaccurate** | Derive from your own Vivado per-component power breakdown. Report derivation methodology. Sensitivity analysis: sweep energy table values ±50% and show Pareto front stability |
| **Too few Pareto points to be interesting** | If the design space is small, expand: vary feature map size (8×8 to 32×32), add multi-channel (C=1,3), add multi-filter (K=1,4,8) |
| **Physical measurement noise is large** | 3 measurements per config, report standard deviation. If USB meter resolution is too coarse, report it as a limitation and lean on the Timeloop-vs-Vivado comparison |
| **CNN parameterization for partial MAC is complex** | Start with 9-MAC baseline only. Even without varying MAC count, you have dataflow × workload size × bit-width as sweep dimensions |

## Sources & References
- [Timeloop/Accelergy Overview](https://timeloop.csail.mit.edu/)
- [Timeloop Paper (ISPASS 2019)](https://accelergy.mit.edu/timeloop.pdf)
- [Accelergy Paper (ICCAD 2019)](https://d1qx31qr3h6wln.cloudfront.net/publications/ICCAD_2019_Accelergy.pdf)
- [ISPASS 2020 Tutorial Part 1](https://accelergy.mit.edu/ispass2020/2020_08_23_timeloop_accelergy_tutorial_part1.pdf)
- [ISPASS 2020 Tutorial Part 2](https://accelergy.mit.edu/ispass2020/2020_08_23_timeloop_accelergy_tutorial_part2.pdf)
- [Timeloop Exercise Repo](https://github.com/Accelergy-Project/timeloop-accelergy-exercises)
- [Docker Infrastructure](https://github.com/Accelergy-Project/accelergy-timeloop-infrastructure)
- [Table-Based Plug-in](https://github.com/Accelergy-Project/accelergy-table-based-plug-ins)
- [Accelergy Plug-ins Documentation](https://timeloop.csail.mit.edu/previous_versions/timeloop-accelergy-v3/accelergy/plugins)
- [Artix-7 DC/AC Switching Characteristics](https://www.mouser.com/pdfDocs/DCandACSwitchingCharacteristics.pdf)
- [Quantization + Mapping Synergy (2024)](https://arxiv.org/html/2404.05368v2)
- [Berkeley DSE Enhancement (2024)](https://www2.eecs.berkeley.edu/Pubs/TechRpts/2024/EECS-2024-237.pdf)
