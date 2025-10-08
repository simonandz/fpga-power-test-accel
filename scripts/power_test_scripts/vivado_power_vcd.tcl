# vivado_power_vcd.tcl
# Alternative: Use VCD instead of SAIF for better signal matching

set repo_root "R:/fpga/fpga-power-test-accel"

# Define paths
set routed_dcp [file join $repo_root build hello_top_routed.dcp]
set vcd_file   [file join $repo_root reports hello_top_time.vcd]
set rpt_dir    [file join $repo_root reports]

puts "=== Vivado Power Report with VCD ==="
puts "Routed DCP: $routed_dcp"
puts "VCD file:   $vcd_file"

# Verify files exist
if {![file exists $routed_dcp]} {
    error "Routed checkpoint not found: $routed_dcp"
}
if {![file exists $vcd_file]} {
    error "VCD file not found: $vcd_file"
}

# Open the routed design
puts "Opening routed checkpoint..."
open_checkpoint $routed_dcp

# Read VCD file (often has better matching than SAIF)
puts "Reading VCD file..."
read_vcd $vcd_file

# Generate power report
puts "Generating power report with VCD activity..."
report_power -file [file join $rpt_dir hello_top_power_vcd.rpt]

puts "\n=== Power Report Complete ==="
puts "Report: hello_top_power_vcd.rpt"
