# vivado_power_report_timing.tcl
# Generates power report using SAIF from timing simulation
# Should have much better net matching than functional simulation

set repo_root "R:/fpga/fpga-power-test-accel"

# Define paths
set routed_dcp [file join $repo_root build hello_top_routed.dcp]
set saif_file  [file join $repo_root reports hello_top_timing.saif]
set rpt_dir    [file join $repo_root reports]

puts "=== Vivado Power Report (Timing Simulation SAIF) ==="
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
puts "\nOpening routed checkpoint..."
open_checkpoint $routed_dcp

# Read SAIF file
puts "Reading timing simulation SAIF..."
read_saif $saif_file

puts "\nGenerating power reports..."

# Generate detailed power report with SAIF
report_power -file [file join $rpt_dir hello_top_power_timing.rpt]

puts "\n=== Power Report Generation Complete ==="
puts "Report: hello_top_power_timing.rpt"
puts "\nCheck the 'Design Nets Matched' percentage - should be much higher!"
