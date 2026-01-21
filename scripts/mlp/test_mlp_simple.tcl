# Simple MLP Hardware Test (with Memory Init)
# Uses mlp_top_debug_memtest module with embedded test data
# VIO probes: vio_start, vio_num_inputs, vio_num_outputs, vio_mem_init
# ILA probes: done, busy, output_data, output_valid, start_masked, mem_init_state, mem_init_done

puts "========================================"
puts "MLP Hardware Test (with Memory Init)"
puts "========================================"

# Find repo root (for bitstream path)
set script_dir [file dirname [info script]]
set repo_root [file normalize [file join $script_dir ..]]
set bit_file [file join $repo_root build mlp_debug mlp_top_debug_memtest.bit]
set ltx_file [file join $repo_root build mlp_debug mlp_top_debug_memtest.ltx]

# Check hardware connection
if {[llength [get_hw_devices]] == 0} {
    puts "ERROR: No hardware device found!"
    puts "Make sure to open Hardware Manager and connect first:"
    puts "  open_hw_manager"
    puts "  connect_hw_server"
    puts "  open_hw_target"
    return -code error "No hardware connected"
}

set device [lindex [get_hw_devices] 0]
puts "Found device: $device"

# Program the FPGA with bitstream
puts "\n=== Programming FPGA ==="
if {![file exists $bit_file]} {
    puts "ERROR: Bitstream not found: $bit_file"
    puts "Run build_mlp_debug.tcl first to generate the bitstream"
    return -code error "Bitstream missing"
}

set_property PROGRAM.FILE $bit_file $device
if {[file exists $ltx_file]} {
    set_property PROBES.FILE $ltx_file $device
    puts "Using debug probes: $ltx_file"
}

puts "Programming: $bit_file"
program_hw_devices $device
puts "Programming complete!"

# Refresh to detect debug cores
refresh_hw_device $device

# Get VIO and ILA
set vio_cores [get_hw_vios]
set ila_cores [get_hw_ilas]

if {[llength $vio_cores] == 0 || [llength $ila_cores] == 0} {
    puts "ERROR: VIO or ILA not found after programming!"
    puts "Check that the bitstream contains debug cores"
    return -code error "Debug cores missing"
}

set vio [lindex $vio_cores 0]
set ila [lindex $ila_cores 0]

puts "Found VIO: $vio"
puts "Found ILA: $ila"

# List all available probes
puts "\n=== Available ILA Probes ==="
set all_probes [get_hw_probes -of_objects $ila]
foreach probe $all_probes {
    puts "  $probe"
}

# Get VIO probes
puts "\n=== Configuring VIO ==="
set vio_probes [get_hw_probes -of_objects $vio]
foreach probe $vio_probes {
    puts "  $probe"
}

# Find VIO control probes by actual signal names
set probe_start [lindex [get_hw_probes -of_objects $vio -filter {NAME =~ "*vio_start*"}] 0]
set probe_num_inputs [lindex [get_hw_probes -of_objects $vio -filter {NAME =~ "*vio_num_inputs*"}] 0]
set probe_num_outputs [lindex [get_hw_probes -of_objects $vio -filter {NAME =~ "*vio_num_outputs*"}] 0]
set probe_mem_init [lindex [get_hw_probes -of_objects $vio -filter {NAME =~ "*vio_mem_init*"}] 0]

# Find ILA probes by actual signal names
set ila_busy [lindex [get_hw_probes -of_objects $ila -filter {NAME =~ "*busy*"}] 0]
set ila_done [lindex [get_hw_probes -of_objects $ila -filter {NAME =~ "*done*"}] 0]
set ila_output_data [lindex [get_hw_probes -of_objects $ila -filter {NAME =~ "*output_data*"}] 0]
set ila_output_valid [lindex [get_hw_probes -of_objects $ila -filter {NAME =~ "*output_valid*"}] 0]
set ila_mem_init_done [lindex [get_hw_probes -of_objects $ila -filter {NAME =~ "*mem_init_done*"}] 0]
set ila_mem_init_state [lindex [get_hw_probes -of_objects $ila -filter {NAME =~ "*mem_init_state*"}] 0]
set ila_start_masked [lindex [get_hw_probes -of_objects $ila -filter {NAME =~ "*start_masked*"}] 0]

# Initialize all VIO outputs to 0
puts "\n=== Initializing VIO ==="
if {[llength $probe_start] > 0} {
    set_property OUTPUT_VALUE 0 $probe_start
    puts "Found vio_start probe"
}
if {[llength $probe_num_inputs] > 0} {
    set_property OUTPUT_VALUE 0000 $probe_num_inputs
    puts "Set num_inputs = 0 (will use default 8)"
}
if {[llength $probe_num_outputs] > 0} {
    set_property OUTPUT_VALUE 0000 $probe_num_outputs
    puts "Set num_outputs = 0 (will use default 4)"
}
if {[llength $probe_mem_init] > 0} {
    set_property OUTPUT_VALUE 0 $probe_mem_init
}
commit_hw_vio $vio

# Wait for auto memory initialization (happens on reset)
puts "\n=== Waiting for Memory Init ==="
puts "Memory auto-initializes on reset..."
after 500

# Optionally trigger manual memory re-init
if {[llength $probe_mem_init] > 0} {
    puts "Triggering memory re-initialization..."
    set_property OUTPUT_VALUE 1 $probe_mem_init
    commit_hw_vio $vio
    after 100
    set_property OUTPUT_VALUE 0 $probe_mem_init
    commit_hw_vio $vio
    after 200
    puts "Memory initialization complete"
}

# Configure ILA - trigger on busy rising edge to capture computation
puts "\n=== Configuring ILA ==="
set_property CONTROL.TRIGGER_POSITION 512 $ila

# Set all probes to don't care first
foreach probe [get_hw_probes -of_objects $ila] {
    catch {set_property TRIGGER_COMPARE_VALUE X $probe}
}

# Set trigger on busy = 1 (rising edge capture)
if {[llength $ila_busy] > 0} {
    set_property TRIGGER_COMPARE_VALUE eq1'b1 $ila_busy
    puts "Trigger set on busy=1 (will capture when computation starts)"
} else {
    puts "WARNING: Could not find busy probe, using immediate trigger"
}

puts "ILA configured to trigger when busy goes high"

# Arm ILA
puts "\n=== Running Test ==="
puts "Arming ILA..."
run_hw_ila $ila
after 200

# Pulse start
puts "Pulsing start signal..."
if {[llength $probe_start] > 0} {
    set_property OUTPUT_VALUE 1 $probe_start
    commit_hw_vio $vio
    after 100
    set_property OUTPUT_VALUE 0 $probe_start
    commit_hw_vio $vio
} else {
    puts "ERROR: Could not find vio_start probe!"
}

# Wait for capture
puts "Waiting for ILA trigger (busy=1)..."
if {[catch {wait_on_hw_ila $ila -timeout 5} err]} {
    puts "\nERROR: ILA timeout - computation never started!"
    puts ""
    puts "Troubleshooting steps:"
    puts "1. Check Basys 3 power LED is ON"
    puts "2. Check SW0 is in UP position (rst_n = 1)"
    puts "3. Toggle SW0 OFF then ON to clear start_triggered latch"
    puts "4. Re-run this script"
    return -code error "ILA timeout"
}

puts "ILA triggered!"

# Upload data
puts "Uploading waveform..."
upload_hw_ila_data $ila

# Try to display
puts "Opening waveform viewer..."
if {[catch {display_hw_ila_data [lindex [get_hw_ila_data -of_objects $ila] end]} err]} {
    puts "Auto-display failed, open manually in GUI"
}

# ==========================================================================
# Test Complete - Manual Verification Required
# ==========================================================================
puts "\n========================================"
puts "ILA CAPTURE COMPLETE"
puts "========================================"
puts ""
puts "Please verify in the waveform viewer:"
puts "  1. busy goes HIGH during computation"
puts "  2. output_valid pulses 4 times"
puts "  3. output_data = 0x24 (36) when output_valid=1"
puts "  4. done asserts at the end"
puts ""
puts "Test data used:"
puts "  - Inputs:  \[1, 2, 3, 4, 5, 6, 7, 8\]"
puts "  - Weights: All 1s (32 values)"
puts "  - Biases:  All 0s (4 values)"
puts "  - Expected: 1+2+3+4+5+6+7+8 = 36 (0x24)"
puts "========================================"

return "CHECK_WAVEFORM"
