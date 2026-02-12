# CNN Benchmark Script
# Runs simulation, synthesis, implementation, and SAIF-based power analysis
# Usage: vivado -mode batch -source scripts/cnn/run_cnn_benchmark.tcl

set project_name "cnn_benchmark"
set part "xc7a35tftg256-1"

# Determine repo root from script location
set script_path [file normalize [info script]]
set script_dir [file dirname $script_path]
set repo_root [file normalize [file join $script_dir .. ..]]

# Change to repo root so all relative paths work
cd $repo_root
puts "Working directory: [pwd]"

set project_dir "build/${project_name}"

# Create results directory
file mkdir reports/cnn_benchmark

puts "================================================================"
puts "CNN Benchmark Flow (with SAIF Power Analysis)"
puts "================================================================"

#==========================================================================
# Step 1: Create Project and Run Behavioral Simulation
#==========================================================================
puts "\n--- Step 1: Running Behavioral Simulation ---\n"

# Create project
create_project -force $project_name $project_dir -part $part

# Add source files
add_files -fileset sources_1 [glob cnn/rtl/*.sv]
add_files -fileset sources_1 [glob common/rtl/*.sv]

# Add testbench
add_files -fileset sim_1 cnn/tb/tb_cnn_benchmark.sv
set_property top tb_cnn_benchmark [get_filesets sim_1]

# Update compile order
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

# Run behavioral simulation (for functional verification)
launch_simulation -mode behavioral
run all
close_sim

puts "\n--- Behavioral Simulation Complete ---\n"

#==========================================================================
# Step 2: Synthesis
#==========================================================================
puts "\n--- Step 2: Running Synthesis ---\n"

# Set top module for synthesis
set_property top cnn_top [get_filesets sources_1]
update_compile_order -fileset sources_1

# Create timing constraints (100 MHz clock)
set constraints_content {
    # Clock constraint - 100 MHz (10 ns period)
    create_clock -period 10.000 -name clk [get_ports clk]

    # Set all inputs/outputs as unconstrained for benchmark (no board-specific pins)
    set_false_path -from [get_ports -filter {DIRECTION == IN && NAME != "clk"}]
    set_false_path -to [get_ports -filter {DIRECTION == OUT}]
}
set constraints_file "$project_dir/benchmark_timing.xdc"
set fp [open $constraints_file w]
puts $fp $constraints_content
close $fp
add_files -fileset constrs_1 $constraints_file

# Run synthesis
launch_runs synth_1 -jobs 4
wait_on_run synth_1

# Open synthesized design and generate reports
open_run synth_1
report_utilization -file reports/cnn_benchmark/utilization_synth.txt
report_timing_summary -file reports/cnn_benchmark/timing_synth.txt

puts "\n--- Synthesis Complete ---\n"

#==========================================================================
# Step 3: Implementation (Place & Route)
#==========================================================================
puts "\n--- Step 3: Running Implementation ---\n"

launch_runs impl_1 -jobs 4
wait_on_run impl_1

# Open implemented design
open_run impl_1

# Generate implementation reports
report_utilization -file reports/cnn_benchmark/utilization_impl.txt
report_timing_summary -file reports/cnn_benchmark/timing_impl.txt

# Save routed checkpoint for power analysis
write_checkpoint -force reports/cnn_benchmark/cnn_top_routed.dcp

puts "\n--- Implementation Complete ---\n"

#==========================================================================
# Step 4: Generate Post-Implementation Netlist for SAIF Simulation
#==========================================================================
puts "\n--- Step 4: Generating Post-Implementation Netlist ---\n"

file mkdir $project_dir/timesim
write_verilog -mode funcsim -force $project_dir/timesim/cnn_top_timesim.v

puts "Generated functional netlist: $project_dir/timesim/cnn_top_timesim.v"

close_project

#==========================================================================
# Step 5: Run Post-Implementation Simulation with SAIF Generation
#==========================================================================
puts "\n--- Step 5: Running Post-Implementation Simulation for SAIF ---\n"

set timesim_netlist "$project_dir/timesim/cnn_top_timesim.v"
set tb_file "cnn/tb/tb_cnn_benchmark.sv"
set saif_file "reports/cnn_benchmark/cnn_benchmark.saif"

# Change to timesim directory for simulation
cd $project_dir/timesim

# Compile post-implementation netlist, testbench, and supporting modules
puts "Compiling post-implementation netlist..."
exec xvlog -L unisims_ver -L unimacro_ver -L secureip cnn_top_timesim.v
exec xvlog -sv ../../../cnn/tb/tb_cnn_benchmark.sv
exec xvlog -sv ../../../common/rtl/perf_counters.sv
exec xvlog -L unisims_ver "$::env(XILINX_VIVADO)/data/verilog/src/glbl.v"

# Elaborate design
puts "Elaborating design..."
exec xelab -timescale 1ns/1ps -debug typical \
    -L unisims_ver -L unimacro_ver -L secureip -L simprims_ver \
    tb_cnn_benchmark glbl \
    -s cnn_benchmark_timesim
puts "Note: Running gate-level simulation (timing from specify blocks in netlist)"

# Create simulation script for SAIF generation
set sim_script "run_saif_sim.tcl"
set fh [open $sim_script w]
puts $fh "open_saif \"../../../$saif_file\""
puts $fh "log_saif \[get_objects -r /tb_cnn_benchmark/dut/*\]"
puts $fh "run all"
puts $fh "close_saif"
puts $fh "quit"
close $fh

# Run simulation with SAIF logging
puts "Running simulation with SAIF generation..."
exec xsim cnn_benchmark_timesim -tclbatch $sim_script

# Return to repo root
cd $repo_root

puts "\n--- SAIF Generation Complete ---\n"
puts "SAIF file: $saif_file"

#==========================================================================
# Step 6: SAIF-Based Power Analysis
#==========================================================================
puts "\n--- Step 6: SAIF-Based Power Analysis ---\n"

# Open routed checkpoint
open_checkpoint reports/cnn_benchmark/cnn_top_routed.dcp

# Read SAIF file for accurate switching activity
puts "Reading SAIF file..."
read_saif $saif_file

# Generate power report with SAIF activity
puts "Generating power report with SAIF activity..."
report_power -file reports/cnn_benchmark/power_saif.txt

# Generate hybrid report (SAIF + defaults for unmatched nets)
puts "Generating hybrid power report..."
set_switching_activity -default_toggle_rate 12.5 -default_static_probability 0.5
set_switching_activity -deassert_resets
report_power -file reports/cnn_benchmark/power_saif_hybrid.txt

puts "\n--- SAIF Power Analysis Complete ---\n"

#==========================================================================
# Step 7: Extract Key Metrics
#==========================================================================
puts "\n================================================================"
puts "CNN BENCHMARK SUMMARY"
puts "================================================================\n"

# Get timing info
set timing_paths [get_timing_paths -max_paths 1 -setup -quiet]
if {[llength $timing_paths] > 0} {
    set wns [get_property SLACK $timing_paths]
    set period 10.000
    set fmax [expr {1000.0 / ($period - $wns)}]
    puts "Timing:"
    puts "  Worst Negative Slack: ${wns} ns"
    puts "  Target Period:        ${period} ns"
    puts "  Max Frequency:        [format %.2f $fmax] MHz"
} else {
    puts "Timing: No constrained paths found"
}
puts ""

puts "CNN Configuration:"
puts "  Input:   16x16 single channel"
puts "  Kernel:  3x3 (9 MACs = 9 DSPs)"
puts "  Output:  16x16 (no pool) or 8x8 (with pool)"
puts "  MACs/inference: 2304 (9 * 16 * 16)"
puts ""

puts "Power Reports Generated:"
puts "  - power_saif.txt        (SAIF-based, actual simulation activity)"
puts "  - power_saif_hybrid.txt (SAIF + defaults for unmatched nets)"
puts ""
puts "See detailed reports in reports/cnn_benchmark/"
puts "================================================================\n"

close_design

puts "CNN Benchmark flow complete!"
