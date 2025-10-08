# hybrid_fixed.tcl
# TRUE Hybrid: Use 51% SAIF data + fill only unmatched nets with calculated values
# This preserves the SAIF matching percentage

set repo_root "R:/fpga/fpga-power-test-accel"

# Define paths
set routed_dcp [file join $repo_root build hello_top_routed.dcp]
set saif_file  [file join $repo_root reports hello_top_time.saif]
set rpt_dir    [file join $repo_root reports]

puts "=== TRUE Hybrid Power Analysis ==="
puts "Goal: Keep 51% SAIF matching + improve confidence for unmatched nets"

# Open the routed design
puts "\nOpening routed checkpoint..."
open_checkpoint $routed_dcp

# STEP 1: Read SAIF FIRST - this is your 51% matched data
puts "\nStep 1: Reading SAIF file (this gives 51% matched nets)..."
read_saif $saif_file

# Generate initial report to see baseline
puts "\nStep 2: Generating baseline report with SAIF only..."
report_power -file [file join $rpt_dir hello_top_power_saif_baseline.rpt]

# STEP 2: Set DEFAULT activity for all unspecified nets
# This does NOT overwrite SAIF data, only fills in missing values
puts "\nStep 3: Setting default activity for unmatched nets..."

# For unmatched logic, set reasonable defaults
# -default_* only affects nets without existing activity data
set_switching_activity -default_toggle_rate 12.5 -default_static_probability 0.5

# Also set deassert_resets to improve confidence
set_switching_activity -deassert_resets

# STEP 3: Generate final hybrid report
puts "\nStep 4: Generating hybrid power report..."
report_power -file [file join $rpt_dir hello_top_power_hybrid_fixed.rpt]

puts "\n=== Hybrid Analysis Complete ==="
puts ""
puts "Generated reports:"
puts "  1. hello_top_power_saif_baseline.rpt - SAIF only (51% matched)"
puts "  2. hello_top_power_hybrid_fixed.rpt  - SAIF + defaults for unmatched"
puts ""
puts "The hybrid report should:"
puts "  - Still show 51% Design Nets Matched (from SAIF)"
puts "  - Have High confidence due to defaults on remaining 49%"
puts "  - Combine real measurement (51%) with statistical defaults (49%)"

close_design
