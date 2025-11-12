# MLP Accelerator Simulation Script for Vivado XSim
# This script compiles and simulates the MLP accelerator testbench

# Auto-detect repo root
set _here [expr {[info script] ne "" ? [file dirname [info script]] : [pwd]}]
set script_dir [file normalize $_here]

set probe $script_dir
set repo_root ""
for {set i 0} {$i < 5} {incr i} {
    if {[file isdirectory [file join $probe common rtl]]} {
        set repo_root [file normalize $probe]
        break
    }
    set parent [file normalize [file join $probe ..]]
    if {$parent eq $probe} { break }
    set probe $parent
}
if {$repo_root eq ""} {
    return -code error "Could not locate repo root from $script_dir"
}

# Set paths
set rtl_dir     [file normalize [file join $repo_root mlp rtl]]
set tb_dir      [file normalize [file join $repo_root mlp tb]]
set build_dir   [file normalize [file join $repo_root build mlp]]
set results_dir [file normalize [file join $repo_root mlp results]]

puts "========================================="
puts "MLP Core Simulation"
puts "========================================="
puts "repo_root    = $repo_root"
puts "rtl_dir      = $rtl_dir"
puts "tb_dir       = $tb_dir"
puts "build_dir    = $build_dir"
puts "results_dir  = $results_dir"
puts "========================================="

# Create directories
file mkdir $build_dir
file mkdir $results_dir

# Change to build directory
cd $build_dir

# Clean previous simulation files
file delete -force xsim.dir
file delete -force *.jou
file delete -force *.log
file delete -force *.pb
file delete -force *.wdb

puts "\n[1/4] Compiling RTL sources..."

# Compile RTL sources
set rtl_file [file join $rtl_dir mlp_core.sv]
if {![file exists $rtl_file]} {
    return -code error "RTL file not found: $rtl_file"
}
puts "  Compiling: $rtl_file"
if {[catch {exec xvlog -sv $rtl_file} result]} {
    puts "ERROR during RTL compilation:"
    puts $result
    return -code error "RTL compilation failed"
}

puts "\n[2/4] Compiling testbench..."

# Compile testbench
set tb_file [file join $tb_dir tb_mlp_core.sv]
if {![file exists $tb_file]} {
    return -code error "Testbench file not found: $tb_file"
}
puts "  Compiling: $tb_file"
if {[catch {exec xvlog -sv $tb_file} result]} {
    puts "ERROR during testbench compilation:"
    puts $result
    return -code error "Testbench compilation failed"
}

puts "\n[3/4] Elaborating design..."

# Elaborate the design
if {[catch {exec xelab tb_mlp_core -debug typical -s mlp_core_sim} result]} {
    puts "ERROR during elaboration:"
    puts $result
    return -code error "Elaboration failed"
}

puts "\n[4/4] Running simulation..."

# Create simulation TCL script
set sim_tcl [file join $build_dir run_sim.tcl]
set sim_fh [open $sim_tcl w]
puts $sim_fh "# MLP Core Simulation Run Script"
puts $sim_fh "puts \"Starting MLP Core simulation...\""
puts $sim_fh "puts \"Simulation time: Running until completion (with timeout)...\""
puts $sim_fh "run all"
puts $sim_fh "puts \"Simulation complete.\""
puts $sim_fh "quit"
close $sim_fh

# Run simulation
puts "  Running xsim..."
if {[catch {exec xsim mlp_core_sim -tclbatch $sim_tcl} result]} {
    puts $result
    # xsim returns non-zero even on successful completion, so check for errors
    if {[string match "*ERROR*" $result]} {
        return -code error "Simulation failed with errors"
    }
} else {
    puts $result
}

puts "\n========================================="
puts "Copying results to mlp/results..."
puts "========================================="

# Copy important result files to results directory
if {[file exists xsim.log]} {
    file copy -force xsim.log [file join $results_dir simulation.log]
    puts "  Copied: simulation.log"
}
if {[file exists xvlog.log]} {
    file copy -force xvlog.log [file join $results_dir compilation.log]
    puts "  Copied: compilation.log"
}
if {[file exists xelab.log]} {
    file copy -force xelab.log [file join $results_dir elaboration.log]
    puts "  Copied: elaboration.log"
}
if {[file exists tb_mlp_core.vcd]} {
    file copy -force tb_mlp_core.vcd [file join $results_dir tb_mlp_core.vcd]
    puts "  Copied: tb_mlp_core.vcd (waveform)"
}
if {[file exists mlp_core_sim.wdb]} {
    file copy -force mlp_core_sim.wdb [file join $results_dir mlp_core_sim.wdb]
    puts "  Copied: mlp_core_sim.wdb (waveform database)"
}

puts "\n========================================="
puts "Simulation complete!"
puts "========================================="
puts "Build directory:   $build_dir"
puts "Results directory: $results_dir"
puts "\nResults files:"
puts "  - simulation.log     (xsim output)"
puts "  - compilation.log    (xvlog output)"
puts "  - elaboration.log    (xelab output)"
puts "  - tb_mlp_core.vcd    (waveform for GTKWave)"
puts "  - mlp_core_sim.wdb   (waveform for Vivado)"
puts "========================================="
