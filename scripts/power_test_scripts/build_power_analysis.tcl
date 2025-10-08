# build_power_analysis.tcl
set repo_root "R:/fpga/fpga-power-test-accel"

# Set working directory to build folder
cd [file join $repo_root build]

# Define all file paths relative to repo root
set dut_netlist [file join $repo_root build timesim hello_top_funcsim.v]
set tb_sv       [file join $repo_root common tb hello_tb_postsyn.sv]
set saif_out    [file join $repo_root reports hello_top_time.saif]
set vcd_out     [file join $repo_root reports hello_top_time.vcd]

puts "=== Power Analysis Flow ==="
puts "Working directory: [pwd]"
puts "DUT: $dut_netlist"
puts "Testbench: $tb_sv"

# Verify files
foreach file [list $dut_netlist $tb_sv] {
    if {![file exists $file]} {
        error "File not found: $file"
    }
}

# Clean previous simulation
if {[file exists "xsim.dir"]} {
    puts "Cleaning previous simulation..."
    file delete -force "xsim.dir"
}

# Step 1: Compile
puts "Step 1: Compiling design and testbench..."
if {[catch {
    exec xvlog -L unisims_ver -L unimacro_ver -L secureip $dut_netlist
    exec xvlog -sv -L unisims_ver -L unimacro_ver -L secureip $tb_sv
    exec xvlog -L unisims_ver "$::env(XILINX_VIVADO)/data/verilog/src/glbl.v"
} error_msg]} {
    error "Compilation failed: $error_msg"
}

# Step 2: Elaborate
puts "Step 2: Elaborating design..."
if {[catch {
    exec xelab -timescale 1ps/1ps -debug typical \
        -L unisims_ver -L unimacro_ver -L secureip -L simprims_ver \
        hello_tb glbl \
        -s hello_top_time
} error_msg]} {
    error "Elaboration failed: $error_msg"
}

# Step 3: Run simulation
puts "Step 3: Running simulation..."
set sim_script [file join $repo_root build run_simulation.tcl]
set fh [open $sim_script w]
puts $fh "open_saif \"$saif_out\""
puts $fh "log_saif \[get_objects -r /hello_tb/dut/*\]"
puts $fh "run 5 ms"
puts $fh "close_saif"
puts $fh "quit"
close $fh

if {[catch {
    exec xsim hello_top_time -tclbatch $sim_script
} error_msg]} {
    error "Simulation failed: $error_msg"
}

