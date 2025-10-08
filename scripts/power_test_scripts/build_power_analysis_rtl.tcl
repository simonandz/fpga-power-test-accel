# build_power_analysis_rtl.tcl
# Runs RTL simulation (not post-synthesis) to generate SAIF for power analysis
set repo_root "R:/fpga/fpga-power-test-accel"

# Set working directory to build folder
cd [file join $repo_root build]

# Define all file paths relative to repo root
set rtl_src     [file join $repo_root common rtl hello_top.sv]
set tb_sv       [file join $repo_root common tb hello_tb.sv]
set saif_out    [file join $repo_root reports hello_top_rtl.saif]

puts "=== RTL Power Analysis Flow ==="
puts "Working directory: [pwd]"
puts "RTL: $rtl_src"
puts "Testbench: $tb_sv"
puts "SAIF output: $saif_out"

# Verify files
foreach file [list $rtl_src $tb_sv] {
    if {![file exists $file]} {
        error "File not found: $file"
    }
}

# Clean previous simulation (best effort - don't fail if locked)
if {[file exists "xsim.dir"]} {
    puts "Attempting to clean previous simulation..."
    if {[catch {file delete -force "xsim.dir"} err]} {
        puts "WARNING: Could not delete xsim.dir (possibly locked): $err"
        puts "Continuing anyway - xelab will reuse existing snapshot if compatible"
    }
}

# Step 1: Compile RTL
puts "Step 1: Compiling RTL design and testbench..."
if {[catch {
    exec xvlog -sv $rtl_src
    exec xvlog -sv $tb_sv
} error_msg]} {
    error "Compilation failed: $error_msg"
}

# Step 2: Elaborate
puts "Step 2: Elaborating design..."
if {[catch {
    exec xelab -timescale 1ns/1ps -debug typical hello_tb -s hello_tb_rtl
} error_msg]} {
    error "Elaboration failed: $error_msg"
}

# Step 3: Run simulation with SAIF generation
puts "Step 3: Running RTL simulation..."
set sim_script [file join $repo_root build run_simulation_rtl.tcl]
set fh [open $sim_script w]
puts $fh "open_saif \"$saif_out\""
puts $fh "log_saif \[get_objects -r /hello_tb/dut/*\]"
puts $fh "# Run for a representative time period (10ms = 1M cycles at 100MHz)"
puts $fh "# This is enough to capture typical switching activity"
puts $fh "run 10 ms"
puts $fh "close_saif"
puts $fh "quit"
close $fh

if {[catch {
    exec xsim hello_tb_rtl -tclbatch $sim_script
} error_msg]} {
    puts "Simulation output: $error_msg"
}

puts "\n=== RTL SAIF Generation Complete ==="
puts "SAIF file: $saif_out"

