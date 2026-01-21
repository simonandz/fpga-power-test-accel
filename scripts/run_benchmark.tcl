# MLP Benchmark Script
# Runs simulation, collects metrics, generates reports
# Usage: vivado -mode batch -source scripts/run_benchmark.tcl

set project_name "mlp_benchmark"
set project_dir "build/${project_name}"
set part "xc7a35tcpg236-1"

# Create results directory
file mkdir reports/benchmark

puts "================================================================"
puts "MLP Benchmark Flow"
puts "================================================================"

#==========================================================================
# Step 1: Run Behavioral Simulation
#==========================================================================
puts "\n--- Step 1: Running Simulation ---\n"

# Create project
create_project -force $project_name $project_dir -part $part

# Add source files
add_files -fileset sources_1 [glob mlp/rtl/*.sv]
add_files -fileset sources_1 [glob common/rtl/*.sv]

# Add testbench
add_files -fileset sim_1 mlp/tb/tb_mlp_benchmark.sv
set_property top tb_mlp_benchmark [get_filesets sim_1]

# Update compile order
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

# Run simulation
launch_simulation -mode behavioral
run all

# Close simulation
close_sim

puts "\n--- Simulation Complete ---\n"

#==========================================================================
# Step 2: Synthesis
#==========================================================================
puts "\n--- Step 2: Running Synthesis ---\n"

# Set top module for synthesis
set_property top mlp_top [get_filesets sources_1]
update_compile_order -fileset sources_1

# Run synthesis
launch_runs synth_1 -jobs 4
wait_on_run synth_1

# Open synthesized design
open_run synth_1

# Generate synthesis reports
report_utilization -file reports/benchmark/utilization_synth.txt
report_timing_summary -file reports/benchmark/timing_synth.txt

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
report_utilization -file reports/benchmark/utilization_impl.txt
report_timing_summary -file reports/benchmark/timing_impl.txt
report_power -file reports/benchmark/power_default.txt

puts "\n--- Implementation Complete ---\n"

#==========================================================================
# Step 4: Power Analysis with Activity
#==========================================================================
puts "\n--- Step 4: Power Analysis ---\n"

# Set switching activity for realistic power estimate
# 25% toggle rate is typical for compute-heavy designs
set_switching_activity -static_probability 0.5 -toggle_rate 0.25 -type register [get_cells -hierarchical -filter {IS_SEQUENTIAL==1}]
set_switching_activity -static_probability 0.5 -toggle_rate 0.125 -type lut [get_cells -hierarchical -filter {PRIMITIVE_TYPE =~ LUT*}]

report_power -file reports/benchmark/power_active.txt

# Low activity (idle)
set_switching_activity -static_probability 0.5 -toggle_rate 0.01 -type register [get_cells -hierarchical -filter {IS_SEQUENTIAL==1}]
set_switching_activity -static_probability 0.5 -toggle_rate 0.01 -type lut [get_cells -hierarchical -filter {PRIMITIVE_TYPE =~ LUT*}]

report_power -file reports/benchmark/power_idle.txt

puts "\n--- Power Analysis Complete ---\n"

#==========================================================================
# Step 5: Extract Key Metrics
#==========================================================================
puts "\n================================================================"
puts "BENCHMARK SUMMARY"
puts "================================================================\n"

# Get timing info
set wns [get_property SLACK [get_timing_paths -max_paths 1 -setup]]
set period [get_property PERIOD [get_clocks clk]]
set fmax [expr {1000.0 / ($period - $wns)}]

puts "Timing:"
puts "  Worst Negative Slack: ${wns} ns"
puts "  Target Period:        ${period} ns"
puts "  Max Frequency:        [format %.2f $fmax] MHz"
puts ""

# Get utilization
set luts_used [get_property SLICE_LUTS [get_cells -hierarchical -filter {IS_PRIMITIVE==1}] -quiet]
set ffs_used [get_property SLICE_REGISTERS [get_cells -hierarchical -filter {IS_PRIMITIVE==1}] -quiet]

puts "See detailed reports in reports/benchmark/"
puts "================================================================\n"

close_project

puts "Benchmark flow complete!"
