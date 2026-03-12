#!/bin/bash
# Run Timeloop mapper for a given architecture + workload combination
# Usage: ./run_timeloop.sh <arch_yaml> <problem_yaml> [output_dir]
#
# Example:
#   ./run_timeloop.sh arch/cnn_accel_9mac.yaml problem/conv2d_16x16.yaml results/cnn_accel_9mac__conv2d_16x16
#   ./run_timeloop.sh arch/cnn_accel_9mac_4b.yaml problem/conv2d_16x16.yaml results/cnn_accel_9mac_4b__conv2d_16x16
#
# Prerequisites:
#   Docker: docker pull timeloopaccelergy/accelergy-timeloop-infrastructure:latest
#   OR native install of timeloop + accelergy

ARCH=${1:?"Usage: $0 <arch.yaml> <problem.yaml> [output_dir]"}
PROBLEM=${2:?"Usage: $0 <arch.yaml> <problem.yaml> [output_dir]"}
OUTDIR=${3:-"results/$(basename $ARCH .yaml)__$(basename $PROBLEM .yaml)"}
IMAGE=${TIMELOOP_DOCKER_IMAGE:-timeloopaccelergy/accelergy-timeloop-infrastructure:latest}

mkdir -p "$OUTDIR"

# Extract base architecture name (strip _4b/_16b bitwidth suffix) for mapper/constraint selection
ARCH_FILENAME=$(basename "$ARCH" .yaml)
ARCH_BASE=$(echo "$ARCH_FILENAME" | sed 's/_4b$//' | sed 's/_16b$//')

# Select mapper config based on MAC count (bitwidth-independent)
case "$ARCH_BASE" in
  cnn_accel_9mac) MAPPER_CFG="mapper/mapper_config_9mac.yaml" ;;
  cnn_accel_3mac) MAPPER_CFG="mapper/mapper_config_3mac.yaml" ;;
  cnn_accel_1mac) MAPPER_CFG="mapper/mapper_config_1mac.yaml" ;;
  *) MAPPER_CFG="mapper/mapper_config.yaml" ;;
esac

# Select bitwidth-specific ERT/ART files
if [[ "$ARCH_FILENAME" == *_4b ]]; then
  ERT_FILE="energy/artix7_ERT_4b.yaml"
  ART_FILE="energy/artix7_ART_4b.yaml"
  BITWIDTH="4"
elif [[ "$ARCH_FILENAME" == *_16b ]]; then
  ERT_FILE="energy/artix7_ERT_16b.yaml"
  ART_FILE="energy/artix7_ART_16b.yaml"
  BITWIDTH="16"
else
  ERT_FILE="energy/artix7_ERT.yaml"
  ART_FILE="energy/artix7_ART.yaml"
  BITWIDTH="8"
fi

MAPPER_CMD="timeloop-mapper \"$ARCH\" \"$PROBLEM\" \"$MAPPER_CFG\""
case "$ARCH_BASE" in
  cnn_accel_9mac|cnn_accel_3mac|cnn_accel_1mac)
  CONSTRAINTS_FILE="constraints/cnn_splitbuf_hard_constraints.yaml"
  MAPPER_CMD="$MAPPER_CMD \"$CONSTRAINTS_FILE\" $ERT_FILE $ART_FILE"
  ENERGY_MODE="custom Artix-7 ERT/ART (INT${BITWIDTH})"
  CONSTRAINT_MODE="hard split-buffer architecture constraints"
  ;;
  *)
  ENERGY_MODE="auto-generated Accelergy ERT/ART (no matching custom table entries configured)"
  CONSTRAINT_MODE="none"
  ;;
esac
MAPPER_CMD="$MAPPER_CMD -o \"$OUTDIR\""

echo "=== Timeloop Mapper ==="
echo "Architecture: $ARCH"
echo "Problem:      $PROBLEM"
echo "Output:       $OUTDIR"
echo "Image:        $IMAGE"
echo "Mapper cfg:   $MAPPER_CFG"
echo "Bitwidth:     INT${BITWIDTH}"
echo "Constraints:  $CONSTRAINT_MODE"
echo "Energy mode:  $ENERGY_MODE"
echo ""

# Option 1: Docker (recommended)
# Initializes table plug-in paths in the same container invocation (safe no-op if already initialized)
# and uses hard split-buffer constraints + custom Artix-7 ERT/ART for supported
# 1/3/9-MAC architectures to avoid auto-generated empty ERT issues and enforce
# fixed RTL buffer roles.
#
# MSYS_NO_PATHCONV=1 prevents Git Bash / MSYS2 from mangling Unix paths like
# /workspace into Windows paths. cygpath -w converts the host pwd for the
# volume mount source (needed on Windows with Docker Desktop).
HOST_DIR="$(pwd)"
if command -v cygpath >/dev/null 2>&1; then
  HOST_DIR="$(cygpath -w "$HOST_DIR")"
fi
MSYS_NO_PATHCONV=1 docker run --rm \
  -v "$HOST_DIR:/workspace" \
  -w /workspace \
  "$IMAGE" \
  bash -lc "set -e; \
    if command -v accelergyTables >/dev/null 2>&1; then \
      accelergyTables >/tmp/accelergyTables.log 2>&1 || true; \
    fi; \
    $MAPPER_CMD"

# Option 2: Native install (uncomment if installed natively)
# timeloop-mapper \
#   "$ARCH" \
#   "$PROBLEM" \
#   mapper/mapper_config.yaml \
#   constraints/cnn_splitbuf_hard_constraints.yaml \
#   energy/artix7_ERT.yaml \
#   energy/artix7_ART.yaml \
#   -o "$OUTDIR"

echo ""
echo "=== Done. Results in $OUTDIR ==="
echo "Key files:"
echo "  $OUTDIR/timeloop-mapper.stats.txt   (summary statistics)"
echo "  $OUTDIR/timeloop-mapper.map.txt     (best mapping found)"
echo "  $OUTDIR/timeloop-mapper.map+stats.xml (machine-readable)"
