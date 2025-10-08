#!/bin/bash

#==============================================================================
# Script: run_iverilog_tests.sh
# Description: Run tests with Icarus Verilog (open-source simulator)
# Install: sudo apt-get install iverilog gtkwave
#==============================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASSED=0
FAILED=0

echo "======================================================="
echo "  Accelerator Infrastructure Test Suite (Icarus)"
echo "======================================================="
echo ""

# Check if iverilog is installed
if ! command -v iverilog &> /dev/null; then
    echo -e "${RED}ERROR: Icarus Verilog not found!${NC}"
    echo ""
    echo "Install with:"
    echo "  Ubuntu/Debian: sudo apt-get install iverilog gtkwave"
    echo "  Fedora/RHEL:   sudo dnf install iverilog gtkwave"
    echo "  macOS:         brew install icarus-verilog gtkwave"
    echo ""
    exit 1
fi

# Change to project root
cd "$(dirname "$0")/.."

mkdir -p build/test_results

#------------------------------------------------------------------------------
# Helper function to run a test
#------------------------------------------------------------------------------
run_test() {
    local test_name=$1
    shift
    local files="$@"

    echo -e "${YELLOW}Running: ${test_name}${NC}"
    echo "-------------------------------------------------------"

    # Compile
    iverilog -g2012 -o build/test_results/${test_name}.vvp ${files} \
        > build/test_results/${test_name}_compile.log 2>&1

    if [ $? -ne 0 ]; then
        echo -e "${RED}✗ COMPILE FAILED${NC}"
        echo "  See build/test_results/${test_name}_compile.log"
        ((FAILED++))
        return 1
    fi

    # Simulate
    vvp build/test_results/${test_name}.vvp \
        > build/test_results/${test_name}_sim.log 2>&1

    if [ $? -ne 0 ]; then
        echo -e "${RED}✗ SIMULATION FAILED${NC}"
        echo "  See build/test_results/${test_name}_sim.log"
        ((FAILED++))
        return 1
    fi

    # Check for pass
    if grep -qi "pass" build/test_results/${test_name}_sim.log; then
        echo -e "${GREEN}✓ PASSED${NC}"
        ((PASSED++))
        return 0
    else
        echo -e "${RED}✗ FAILED${NC}"
        echo "  See build/test_results/${test_name}_sim.log"
        ((FAILED++))
        return 1
    fi
}

#------------------------------------------------------------------------------
# Run all tests
#------------------------------------------------------------------------------

run_test "tb_memory_controller" \
    common/rtl/accel_pkg.sv \
    common/rtl/bram_bank.sv \
    common/rtl/memory_controller.sv \
    common/tb/tb_memory_controller.sv
echo ""

run_test "tb_addr_gen_unit" \
    common/rtl/accel_pkg.sv \
    common/rtl/addr_gen_unit.sv \
    common/tb/tb_addr_gen_unit.sv
echo ""

run_test "tb_power_manager" \
    common/rtl/accel_pkg.sv \
    common/rtl/power_manager.sv \
    common/tb/tb_power_manager.sv
echo ""

run_test "tb_accel_controller" \
    common/rtl/accel_pkg.sv \
    common/rtl/bram_bank.sv \
    common/rtl/memory_controller.sv \
    common/rtl/addr_gen_unit.sv \
    common/rtl/accel_controller.sv \
    common/tb/tb_accel_controller.sv
echo ""

run_test "tb_accel_top" \
    common/rtl/accel_pkg.sv \
    common/rtl/bram_bank.sv \
    common/rtl/memory_controller.sv \
    common/rtl/addr_gen_unit.sv \
    common/rtl/accel_controller.sv \
    common/rtl/power_manager.sv \
    common/rtl/clock_gate.sv \
    common/rtl/accel_top.sv \
    common/tb/tb_accel_top.sv
echo ""

#------------------------------------------------------------------------------
# Summary
#------------------------------------------------------------------------------
echo "======================================================="
echo "  Test Summary"
echo "======================================================="
echo -e "Passed: ${GREEN}${PASSED}${NC}"
echo -e "Failed: ${RED}${FAILED}${NC}"
echo "Total:  $((PASSED + FAILED))"
echo ""

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}All tests passed!${NC}"
    echo ""
    echo "View waveforms with: gtkwave <test_name>.vcd"
    exit 0
else
    echo -e "${RED}Some tests failed.${NC}"
    echo "Check logs in build/test_results/"
    exit 1
fi
