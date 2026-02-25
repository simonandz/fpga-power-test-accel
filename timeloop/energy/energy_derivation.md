# Artix-7 Energy Table Derivation

## Source Data

### Vivado SAIF Power Report (MLP baseline, 100 MHz)
From `reports/benchmark/power_saif.txt`:

| Component    | Power (mW) | Count | Per-unit (mW) |
|-------------|-----------|-------|---------------|
| Block RAM    | 4         | 5.5   | 0.73          |
| Slice Logic  | <1        | 1943  | ~0.0005       |
| Signals      | 1         | 1522  | ~0.0007       |
| Clocks       | 3         | 3     | 1.0           |
| I/O          | 1         | 132   | ~0.008        |
| Static       | 70        | -     | -             |
| **Total**    | **80**    |       |               |

### Vivado Hierarchy Breakdown (SAIF)
| Module           | Power (mW) |
|-----------------|-----------|
| mlp_top (total)  | 9         |
| memory_inst      | 4         |
| datapath_inst    | 3         |
| mac_inst         | 2         |
| controller_inst  | 1         |

## Derivation Methodology

### BRAM Energy per Access
```
BRAM total power = 4 mW (from 5.5 RAMB18E1 blocks)
Per-BRAM dynamic power = 4 / 5.5 = 0.727 mW
Clock frequency = 100 MHz

Upper bound (assume every cycle is an access):
  energy_per_access = 0.727 mW / 100 MHz = 7.27 pJ

This is an upper bound because not every cycle has an active access.
Actual energy per access is likely higher (fewer accesses, same power).

Cross-reference: Xilinx DS181 quotes BRAM dynamic power at ~5-10 pJ
per access for RAMB18E1 at 100 MHz.

Selected value: 7.3 pJ (consistent with both sources)
```

### DSP48E1 (MAC) Energy per Operation
```
MAC array power = 2 mW (8-way MAC in MLP, from hierarchy report)
Per-MAC power = 2 / 8 = 0.25 mW

Activity factor estimation:
  MLP benchmark runs inference repeatedly, but MAC is not active
  every cycle. Estimated activity ~50-70%.

  If activity = 50%: energy = 0.25 / (100 * 0.50) = 5.0 pJ
  If activity = 70%: energy = 0.25 / (100 * 0.70) = 3.6 pJ
  If activity = 100%: energy = 0.25 / (100 * 1.00) = 2.5 pJ

Cross-reference: Xilinx DS181 quotes DSP48E1 at ~3-5 pJ for
18x25 multiply at 100 MHz. INT8 uses a subset.

Selected value: 3.5 pJ (middle of range)
```

### Register Energy per Access
```
Register power < 1 mW total for 559 flip-flops
Per-register: < 1.8 uW
At 100 MHz: < 0.018 pJ per cycle

However, this doesn't include routing energy to/from registers.
Signal routing power = 1 mW for 1522 nets.

Conservative estimate including local routing: 0.5 pJ per access
```

### DRAM (Off-chip) Energy
```
Not directly measurable from Vivado (off-chip).
Using typical DRAM access energy for small transfers: ~200 pJ
This represents the host PC writing data to FPGA BRAMs before inference.

Note: In our setup, DRAM accesses happen only during initialization
(loading weights/inputs), not during inference. The energy impact
is amortized over many inferences in a real deployment.
```

## Sensitivity Analysis (TODO)

After running Timeloop, perform sensitivity sweep:
- Vary BRAM energy: 5, 7.3, 10 pJ (±30%)
- Vary MAC energy: 2.5, 3.5, 5.0 pJ (±40%)
- Vary DRAM energy: 100, 200, 400 pJ (±100%)
- Check: Does the Pareto front ranking change?
- Report: Which parameter has the most impact on DSE conclusions?

## Refinement Plan

These initial values will be refined through:
1. **CNN-specific Vivado reports** — rebuild with CNN design, extract per-component power
2. **Activity-rate calibration** — use SAIF toggle rates to compute actual activity factors
3. **Physical measurement calibration** — adjust energy tables until Timeloop predictions
   match physical measurements within target accuracy
