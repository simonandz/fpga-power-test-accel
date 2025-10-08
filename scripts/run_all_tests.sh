#!/bin/bash

#==============================================================================
# Script: run_all_tests.sh
# Description: Run all infrastructure testbenches
#==============================================================================

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test results
PASSED=0
FAILED=0

echo "======================================================="
echo "  Accelerator Infrastructure Test Suite"
echo "======================================================="
echo ""

# Change to project root
cd "$(dirname "$0")/.."

# Create test output directory
mkdir -p build/test_results

#------------------------------------------------------------------------------
# Helper function to run a test
#------------------------------------------------------------------------------
run_test() {
    local test_name=$1
    local tb_file=$2

    echo -e "${YELLOW}Running: ${test_name}${NC}"
    echo "-------------------------------------------------------"

    # Compile
    xvlog -sv common/rtl/accel_pkg.sv \
              common/rtl/bram_bank.sv \
              common/rtl/memory_controller.sv \
              common/rtl/addr_gen_unit.sv \
              common/rtl/accel_controller.sv \
              common/rtl/power_manager.sv \
              common/rtl/clock_gate.sv \
              common/tb/${tb_file} \
              > build/test_results/${test_name}_compile.log 2>&1

    if [ $? -ne 0 ]; then
        echo -e "${RED}✗ COMPILE FAILED${NC}"
        echo "  See build/test_results/${test_name}_compile.log"
        ((FAILED++))
        return 1
    fi

    # Elaborate
    xelab -debug typical ${test_name} \
        > build/test_results/${test_name}_elab.log 2>&1

    if [ $? -ne 0 ]; then
        echo -e "${RED}✗ ELABORATE FAILED${NC}"
        echo "  See build/test_results/${test_name}_elab.log"
        ((FAILED++))
        return 1
    fi

    # Simulate
    xsim ${test_name} -R \
        > build/test_results/${test_name}_sim.log 2>&1

    if [ $? -ne 0 ]; then
        echo -e "${RED}✗ SIMULATION FAILED${NC}"
        echo "  See build/test_results/${test_name}_sim.log"
        ((FAILED++))
        return 1
    fi

    # Check for "Passed" or "PASS" in output
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

run_test "tb_memory_controller" "tb_memory_controller.sv"
echo ""

run_test "tb_addr_gen_unit" "tb_addr_gen_unit.sv"
echo ""

run_test "tb_accel_controller" "tb_accel_controller.sv"
echo ""

run_test "tb_power_manager" "tb_power_manager.sv"
echo ""

# Integration test
run_test "tb_accel_top" "tb_accel_top.sv"
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
    exit 0
else
    echo -e "${RED}Some tests failed.${NC}"
    echo "Check logs in build/test_results/"
    exit 1
fi
