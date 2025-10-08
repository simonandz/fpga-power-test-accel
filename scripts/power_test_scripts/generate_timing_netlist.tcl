# generate_timing_netlist.tcl
# Generates a timing simulation netlist from the routed checkpoint
# This netlist has better signal name preservation for SAIF matching

set repo_root "R:/fpga/fpga-power-test-accel"

# Define paths
set routed_dcp [file join $repo_root build hello_top_routed.dcp]
set timesim_dir [file join $repo_root build timesim]
set timing_netlist [file join $timesim_dir hello_top_timesim.v]
set sdf_file [file join $timesim_dir hello_top_timesim.sdf]

puts "=== Generating Timing Simulation Netlist ==="
puts "Input:  $routed_dcp"
puts "Output: $timing_netlist"
puts "SDF:    $sdf_file"

# Verify routed checkpoint exists
if {![file exists $routed_dcp]} {
    error "Routed checkpoint not found: $routed_dcp"
}

# Create output directory
file mkdir $timesim_dir

# Open the routed design
puts "\nOpening routed checkpoint..."
open_checkpoint $routed_dcp

# Generate timing simulation netlist
puts "Writing timing simulation Verilog..."
write_verilog -mode timesim -sdf_anno true -force $timing_netlist

# Generate SDF file for timing annotation
puts "Writing SDF file..."
write_sdf -force $sdf_file

puts "\n=== Timing Netlist Generation Complete ==="
puts "Files created:"
puts "  - $timing_netlist"
puts "  - $sdf_file"
puts "\nNext: Run timing simulation with this netlist to generate SAIF"

close_design
