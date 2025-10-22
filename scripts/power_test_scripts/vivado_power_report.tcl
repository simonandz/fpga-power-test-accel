# vivado_power_report.tcl
# Reads a routed checkpoint and SAIF file, then generates power reports

set repo_root "R:/fpga/fpga-power-test-accel"

# Define paths
set routed_dcp [file join $repo_root build hello_top_routed.dcp]
set saif_file  [file join $repo_root reports hello_top_time.saif]
set rpt_dir    [file join $repo_root reports]

puts "=== Vivado Power Report Generation ==="
puts "Routed DCP: $routed_dcp"
puts "SAIF file:  $saif_file"
puts "Reports:    $rpt_dir"

# Verify files exist
if {![file exists $routed_dcp]} {
    error "Routed checkpoint not found: $routed_dcp"
}
if {![file exists $saif_file]} {
    error "SAIF file not found: $saif_file"
}

# Open the routed design
puts "Opening routed checkpoint..."
open_checkpoint $routed_dcp

# Read SAIF file
# The SAIF has testbench hierarchy hello_tb/dut, we just read it directly
# Vivado will match what it can based on signal names
puts "Reading SAIF file..."
read_saif $saif_file

puts "\nAnalyzing SAIF matching..."

# Generate power reports
puts "Generating power report with SAIF activity..."
report_power -file [file join $rpt_dir hello_top_power_saif.rpt]

puts "Generating power summary..."
report_power -file [file join $rpt_dir hello_top_power_summary.rpt]

puts "=== Power Report Generation Complete ==="
puts "Reports written to:"
puts "  - hello_top_power_saif.rpt"
puts "  - hello_top_power_summary.rpt"
