#!/bin/bash
# Run Timeloop mapper for all architecture x workload combinations
# This is the full Phase 2 sweep - generates all data needed for DSE
#
# Prerequisites: Docker or native Timeloop/Accelergy install

set -e

SKIP_EXISTING=${SKIP_EXISTING:-0}

ARCHS=(
  # INT8 (baseline)
  "arch/cnn_accel_9mac.yaml"
  "arch/cnn_accel_3mac.yaml"
  "arch/cnn_accel_1mac.yaml"
  # INT4
  "arch/cnn_accel_9mac_4b.yaml"
  "arch/cnn_accel_3mac_4b.yaml"
  "arch/cnn_accel_1mac_4b.yaml"
  # INT16
  "arch/cnn_accel_9mac_16b.yaml"
  "arch/cnn_accel_3mac_16b.yaml"
  "arch/cnn_accel_1mac_16b.yaml"
)

PROBLEMS=(
  "problem/conv2d_8x8.yaml"
  "problem/conv2d_16x16.yaml"
  "problem/conv2d_32x32.yaml"
  "problem/conv2d_16x16_c3.yaml"
  "problem/conv2d_16x16_k4.yaml"
  "problem/conv2d_16x16_c3k8.yaml"
)

echo "=== Timeloop Full DSE Sweep ==="
echo "Architectures: ${#ARCHS[@]}"
echo "Workloads:     ${#PROBLEMS[@]}"
echo "Total runs:    $((${#ARCHS[@]} * ${#PROBLEMS[@]}))"
echo ""

for arch in "${ARCHS[@]}"; do
  for problem in "${PROBLEMS[@]}"; do
    arch_name=$(basename "$arch" .yaml)
    prob_name=$(basename "$problem" .yaml)
    outdir="results/${arch_name}__${prob_name}"

    if [[ "$SKIP_EXISTING" == "1" && -f "$outdir/timeloop-mapper.stats.txt" ]]; then
      echo "--- SKIP (exists): $arch_name + $prob_name ---"
      continue
    fi

    echo "--- Running: $arch_name + $prob_name ---"
    ./run_timeloop.sh "$arch" "$problem" "$outdir"
    echo ""
  done
done

echo "=== All runs complete ==="
echo "Results in: results/"
echo ""
echo "Next steps:"
echo "  1. Review results/*/timeloop-mapper.stats.txt for energy/latency"
echo "  2. Collect Pareto-optimal points across all configs"
echo "  3. Select 8-12 points for FPGA implementation (Phase 3)"
