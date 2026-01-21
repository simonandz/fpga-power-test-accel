# MLP Accelerator Debug Build Script (with Memory Init)
# Uses mlp_top_debug_memtest module with embedded test data
# Creates VIO and ILA cores for hardware testing without physical I/O
# Control everything through Vivado Hardware Manager!

set _here [expr {[info script] ne "" ? [file dirname [info script]] : [pwd]}]
set script_dir [file normalize $_here]

set probe $script_dir
set repo_root ""
for {set i 0} {$i < 5} {incr i} {
    if {[file isdirectory [file join $probe mlp rtl]]} {
        set repo_root [file normalize $probe]
        break
    }
    set parent [file normalize [file join $probe ..]]
    if {$parent eq $probe} { break }
    set probe $parent
}
if {$repo_root eq ""} {
    return -code error "Could not locate repo root"
}

set mlp_rtl_dir [file normalize [file join $repo_root mlp rtl]]
set common_rtl_dir [file normalize [file join $repo_root common rtl]]
set build_dir [file normalize [file join $repo_root build mlp_debug]]
set rpt_dir [file normalize [file join $repo_root reports mlp_debug]]
set ip_dir [file normalize [file join $repo_root ip_repo]]

set part xc7a35tcpg236-1
set top mlp_top_debug_memtest

puts "============================================"
puts "MLP Debug Build (VIO + ILA + Memory Init)"
puts "============================================"
puts "repo_root  = $repo_root"
puts "build_dir  = $build_dir"
puts "ip_dir     = $ip_dir"
puts "part       = $part"
puts "top        = $top"
puts "============================================"

file mkdir $build_dir
file mkdir $rpt_dir
file mkdir $ip_dir

# Close any existing project
catch {close_project}

# Create project
create_project mlp_debug $build_dir -part $part -force

# Set IP repository path
set_property ip_repo_paths $ip_dir [current_project]
update_ip_catalog

puts "\n=========================================="
puts "Creating VIO Core..."
puts "=========================================="

# Create VIO IP
# 4 outputs: start (1-bit), num_inputs (16-bit), num_outputs (16-bit), mem_init (1-bit)
create_ip -name vio -vendor xilinx.com -library ip -version 3.0 \
    -module_name vio_0 -dir $ip_dir

set_property -dict [list \
    CONFIG.C_PROBE_OUT0_WIDTH {1} \
    CONFIG.C_PROBE_OUT1_WIDTH {16} \
    CONFIG.C_PROBE_OUT2_WIDTH {16} \
    CONFIG.C_PROBE_OUT3_WIDTH {1} \
    CONFIG.C_NUM_PROBE_OUT {4} \
    CONFIG.C_NUM_PROBE_IN {0} \
    CONFIG.C_EN_PROBE_IN_ACTIVITY {0} \
] [get_ips vio_0]

generate_target all [get_ips vio_0]
create_ip_run [get_ips vio_0]
launch_runs vio_0_synth_1
wait_on_run vio_0_synth_1

puts "\n=========================================="
puts "Creating ILA Core..."
puts "=========================================="

# Create ILA IP
# 10 probes: done (1), busy (1), output_data (8), output_valid (1),
#            start_masked (1), mem_init_state (3), mem_init_done (1),
#            output_wr_en (1), output_wr_addr (16), output_wr_data (8)
create_ip -name ila -vendor xilinx.com -library ip -version 6.2 \
    -module_name ila_0 -dir $ip_dir

set_property -dict [list \
    CONFIG.C_NUM_OF_PROBES {10} \
    CONFIG.C_PROBE0_WIDTH {1} \
    CONFIG.C_PROBE1_WIDTH {1} \
    CONFIG.C_PROBE2_WIDTH {8} \
    CONFIG.C_PROBE3_WIDTH {1} \
    CONFIG.C_PROBE4_WIDTH {1} \
    CONFIG.C_PROBE5_WIDTH {3} \
    CONFIG.C_PROBE6_WIDTH {1} \
    CONFIG.C_PROBE7_WIDTH {1} \
    CONFIG.C_PROBE8_WIDTH {16} \
    CONFIG.C_PROBE9_WIDTH {8} \
    CONFIG.C_DATA_DEPTH {4096} \
    CONFIG.C_TRIGIN_EN {false} \
    CONFIG.C_TRIGOUT_EN {false} \
] [get_ips ila_0]

generate_target all [get_ips ila_0]
create_ip_run [get_ips ila_0]
launch_runs ila_0_synth_1
wait_on_run ila_0_synth_1

puts "\n=========================================="
puts "Adding RTL Sources..."
puts "=========================================="

# Add RTL sources
add_files -fileset sources_1 [glob $mlp_rtl_dir/*.sv]
add_files -fileset sources_1 [glob $common_rtl_dir/*.sv]

# Note: mlp_top_debug_memtest has embedded test data, no external .mem files needed
puts "\nUsing embedded test data (no external .mem files required)"

# Update compile order
set_property top $top [current_fileset]
update_compile_order -fileset sources_1

puts "\n=========================================="
puts "Creating Constraints..."
puts "=========================================="

# Create minimal XDC (only clock and reset)
set xdc_content {# Minimal constraints for debug build
# Clock - 100 MHz on Basys3
set_property PACKAGE_PIN W5 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports clk]
create_clock -add -name sys_clk_pin -period 10.00 -waveform {0 5} [get_ports clk]

# Reset - Active Low (SW0)
set_property PACKAGE_PIN V17 [get_ports rst_n]
set_property IOSTANDARD LVCMOS33 [get_ports rst_n]
set_property PULLUP true [get_ports rst_n]

# Configuration
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property CFGBVS VCCO [current_design]
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
set_property BITSTREAM.CONFIG.CONFIGRATE 33 [current_design]
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4 [current_design]
set_property BITSTREAM.CONFIG.SPI_FALL_EDGE YES [current_design]
}

set xdc_file [file join $build_dir mlp_debug.xdc]
set fh [open $xdc_file w]
puts $fh $xdc_content
close $fh

# Add constraints to project (not read_xdc which is for non-project mode)
add_files -fileset constrs_1 $xdc_file
set_property target_constrs_file $xdc_file [current_fileset -constrset]

puts "\n=========================================="
puts "Running Synthesis..."
puts "=========================================="

# Use project mode: launch synthesis run
launch_runs synth_1 -jobs 4
wait_on_run synth_1

# Check synthesis status
if {[get_property PROGRESS [get_runs synth_1]] != "100%"} {
    puts "ERROR: Synthesis failed!"
    return -code error "Synthesis failed"
}
puts "Synthesis complete!"

# Generate post-synth reports
open_run synth_1
report_utilization -hierarchical -file [file join $rpt_dir ${top}_utilization_synth.rpt]

puts "\n=========================================="
puts "Running Implementation..."
puts "=========================================="

# Launch implementation run
launch_runs impl_1 -jobs 4
wait_on_run impl_1

# Check implementation status
if {[get_property PROGRESS [get_runs impl_1]] != "100%"} {
    puts "ERROR: Implementation failed!"
    return -code error "Implementation failed"
}
puts "Implementation complete!"

puts "\n=========================================="
puts "Generating Reports..."
puts "=========================================="

open_run impl_1
report_utilization -hierarchical -file [file join $rpt_dir ${top}_utilization_routed.rpt]
report_timing_summary -file [file join $rpt_dir ${top}_timing_summary.rpt]
report_power -file [file join $rpt_dir ${top}_power.rpt]

puts "\n=========================================="
puts "Generating Bitstream..."
puts "=========================================="

# Launch bitstream generation
launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1

# Copy bitstream and debug probes to expected locations
set bit_src [file join $build_dir mlp_debug.runs impl_1 ${top}.bit]
set ltx_src [file join $build_dir mlp_debug.runs impl_1 ${top}.ltx]
set bit_dst [file join $build_dir ${top}.bit]
set ltx_dst [file join $build_dir ${top}.ltx]

if {[file exists $bit_src]} {
    file copy -force $bit_src $bit_dst
    puts "Bitstream copied to: $bit_dst"
}
if {[file exists $ltx_src]} {
    file copy -force $ltx_src $ltx_dst
    puts "Debug probes copied to: $ltx_dst"
}

puts "\n=========================================="
puts "Build Complete!"
puts "=========================================="
puts "Bitstream: build/mlp_debug/${top}.bit"
puts ""
puts "Test data (embedded in design):"
puts "  - Inputs:  \[1, 2, 3, 4, 5, 6, 7, 8\]"
puts "  - Weights: All 1s (32 values)"
puts "  - Biases:  All 0s (4 values)"
puts "  - Expected output: 36 (0x24) for each of 4 neurons"
puts ""
puts "VIO Probes:"
puts "  - probe_out0: start (1-bit)"
puts "  - probe_out1: num_inputs (16-bit, default=8)"
puts "  - probe_out2: num_outputs (16-bit, default=4)"
puts "  - probe_out3: mem_init trigger (1-bit)"
puts ""
puts "ILA Probes:"
puts "  - probe0: done (1-bit)"
puts "  - probe1: busy (1-bit)"
puts "  - probe2: output_data (8-bit)"
puts "  - probe3: output_valid (1-bit)"
puts "  - probe4: start_masked (1-bit)"
puts "  - probe5: mem_init_state (3-bit)"
puts "  - probe6: mem_init_done (1-bit)"
puts "  - probe7: output_wr_en (1-bit) - BRAM write enable"
puts "  - probe8: output_wr_addr (16-bit) - BRAM write address"
puts "  - probe9: output_wr_data (8-bit) - BRAM write data"
puts ""
puts "Next steps:"
puts "1. Program FPGA with this bitstream"
puts "2. Memory auto-initializes on reset"
puts "3. Leave num_inputs/num_outputs at 0 to use defaults"
puts "4. Toggle 'start' signal high then low"
puts "5. Watch ILA for output_data = 0x24"
puts ""
puts "See scripts/test_mlp_simple.tcl for automation"
puts "=========================================="
