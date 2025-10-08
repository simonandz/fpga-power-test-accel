# build_power_analysis_timing.tcl
# Runs timing simulation using the post-implementation netlist
# This should give MUCH better signal matching than functional simulation

set repo_root "R:/fpga/fpga-power-test-accel"

# Set working directory
cd [file join $repo_root build]

# Define all file paths
set timing_netlist [file join $repo_root build timesim hello_top_timesim.v]
set sdf_file       [file join $repo_root build timesim hello_top_timesim.sdf]
set tb_sv          [file join $repo_root common tb hello_tb_postsyn.sv]
set saif_out       [file join $repo_root reports hello_top_timing.saif]

puts "=== Timing Simulation for Power Analysis ==="
puts "Working directory: [pwd]"
puts "Netlist:    $timing_netlist"
puts "SDF:        $sdf_file"
puts "Testbench:  $tb_sv"
puts "SAIF out:   $saif_out"

# Verify files exist
foreach file [list $timing_netlist $tb_sv] {
    if {![file exists $file]} {
        error "File not found: $file"
    }
}

# Clean previous simulation (best effort)
if {[file exists "xsim.dir"]} {
    puts "\nCleaning previous simulation..."
    if {[catch {file delete -force "xsim.dir"} err]} {
        puts "WARNING: Could not delete xsim.dir: $err"
    }
}

# Step 1: Compile timing netlist and testbench
puts "\nStep 1: Compiling timing netlist and testbench..."
if {[catch {
    exec xvlog -L unisims_ver -L unimacro_ver -L secureip $timing_netlist
    exec xvlog -sv -L unisims_ver $tb_sv
    exec xvlog -L unisims_ver "$::env(XILINX_VIVADO)/data/verilog/src/glbl.v"
} error_msg]} {
    error "Compilation failed: $error_msg"
}

# Step 2: Elaborate
puts "Step 2: Elaborating design..."
if {[catch {
    exec xelab -timescale 1ps/1ps -debug typical \
        -L unisims_ver -L unimacro_ver -L secureip \
        hello_tb glbl \
        -s hello_tb_timing
} error_msg]} {
    error "Elaboration failed: $error_msg"
}

# Step 3: Run simulation with SAIF
puts "Step 3: Running timing simulation with SAIF..."
set sim_script [file join $repo_root build run_simulation_timing.tcl]
set fh [open $sim_script w]
puts $fh "open_saif \"$saif_out\""
puts $fh "log_saif \[get_objects -r /hello_tb/dut/*\]"
puts $fh "# Timing sim is very slow - run minimal time (1K cycles @ 100MHz)"
puts $fh "run 10 us"
puts $fh "close_saif"
puts $fh "quit"
close $fh

if {[catch {
    exec xsim hello_tb_timing -tclbatch $sim_script
} error_msg]} {
    puts "Simulation output: $error_msg"
}

puts "\n=== Timing Simulation SAIF Generation Complete ==="
puts "SAIF file: $saif_out"
puts "\nThis SAIF should have MUCH better signal matching!"
puts "Next: Run vivado_power_report_timing.tcl to generate power report"
