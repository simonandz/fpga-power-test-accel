#!/bin/bash
# cleanup.sh - Clean up temporary and log files from FPGA project

cd "$(dirname "$0")"

echo "=== FPGA Project Cleanup ==="
echo "Project directory: $(pwd)"
echo ""

# Function to safely remove with confirmation
remove_item() {
    local item=$1
    local desc=$2
    if [ -e "$item" ]; then
        echo "Removing: $desc"
        rm -rf "$item"
    fi
}

# 1. Remove backup log files
echo "--- Cleaning backup logs ---"
remove_item "*.backup.log" "Top-level backup logs"
remove_item "*.backup.jou" "Top-level backup journals"
find build -name "*.backup.log" -delete 2>/dev/null
find build -name "*.backup.jou" -delete 2>/dev/null
echo "Backup logs cleaned"

# 2. Remove current log files (keep if you want)
echo ""
echo "--- Cleaning current logs ---"
remove_item "vivado.log" "Top-level Vivado log"
remove_item "vivado.jou" "Top-level Vivado journal"
find build -name "vivado.log" -delete 2>/dev/null
find build -name "vivado.jou" -delete 2>/dev/null
find build -name "xsim.log" -delete 2>/dev/null
find build -name "xsim.jou" -delete 2>/dev/null
find build -name "xvlog.log" -delete 2>/dev/null
find build -name "xelab.log" -delete 2>/dev/null
echo "Current logs cleaned"

# 3. Remove Xilinx temporary directories
echo ""
echo "--- Cleaning Xilinx temp directories ---"
remove_item ".Xil" "Xilinx temporary directory"
remove_item "xsim.dir" "XSim simulation directory"
remove_item "build/xsim.dir" "Build XSim directory"
echo "Temp directories cleaned"

# 4. Remove intermediate simulation files
echo ""
echo "--- Cleaning simulation intermediates ---"
remove_item "build/*.wdb" "Waveform databases"
remove_item "build/*.vcd" "VCD files in build"
remove_item "build/xsim" "XSim build folder"
find build -name "*.pb" -delete 2>/dev/null
find build -name "*.tcl" -name "run_simulation*" -delete 2>/dev/null
echo "Simulation intermediates cleaned"

# 5. Remove temporary reports (keep final reports)
echo ""
echo "--- Cleaning temporary reports ---"
remove_item "reports/temp_*.rpt" "Temporary reports"
remove_item "design_nets_analysis.txt" "Design analysis temporary file"
echo "Temporary reports cleaned"

# 6. Remove unused/old SAIF files (optional - keep if needed)
echo ""
echo "--- Optional: Old SAIF/VCD files ---"
echo "Keeping all SAIF/VCD files (comment out if you want to remove old ones)"
# Uncomment below to remove old SAIF files:
# remove_item "reports/hello_top.saif" "Old SAIF (use hello_top_time.saif)"
# remove_item "reports/hello_top_rtl.saif" "RTL SAIF (if not needed)"

echo ""
echo "=== Cleanup Complete ==="
echo ""
echo "Kept (important files):"
echo "  - Source files (common/rtl/, common/tb/)"
echo "  - Build outputs (build/*.dcp, build/*.bit)"
echo "  - Final reports (reports/*.rpt)"
echo "  - SAIF files (reports/*.saif)"
echo "  - Scripts (scripts/)"
echo ""
echo "You can now commit to git or archive the project."
