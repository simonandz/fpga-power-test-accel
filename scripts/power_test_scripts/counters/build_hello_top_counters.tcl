# TCL script to generate bitstream for hello_top_counters
# Usage: vivado -mode batch -source scripts/power_test_scripts/build_hello_top_counters.tcl

# Start from the script's folder (or PWD if pasted into console)
set _here [expr {[info script] ne "" ? [file dirname [info script]] : [pwd]}]
set script_dir [file normalize $_here]

# Walk up until we find a directory that contains common/rtl
set probe $script_dir
set repo_root ""
for {set i 0} {$i < 5} {incr i} {
    if {[file isdirectory [file join $probe common rtl]]} {
        set repo_root [file normalize $probe]
        break
    }
    set parent [file normalize [file join $probe ..]]
    if {$parent eq $probe} { break }  ;# reached filesystem root
    set probe $parent
}
if {$repo_root eq ""} {
    return -code error "Could not locate repo root from $script_dir (no 'common/rtl' found up to 5 levels)"
}

# Now build paths from the discovered repo_root
set src_file  [file normalize [file join $repo_root common rtl power_test hello_top_counters]]
set xdc_file  [file normalize [file join $repo_root common constraints basys3_hello_top_counters.xdc]]
set build_dir [file normalize [file join $repo_root build hello_top_counters]]
set rpt_dir   [file normalize [file join $repo_root reports hello_top_counters]]

set part xc7a35tcpg236-1
set top  hello_top_counters

puts "========================================"
puts "Build Configuration for hello_top_counters"
puts "========================================"
puts "script_dir = $script_dir"
puts "repo_root  = $repo_root"
puts "src_file   = $src_file"
puts "xdc_file   = $xdc_file"
puts "build_dir  = $build_dir"
puts "rpt_dir    = $rpt_dir"
puts "part       = $part"
puts "top        = $top"
puts "========================================"

file mkdir $build_dir
file mkdir $rpt_dir

# Read source file
if {![file exists $src_file]} {
    return -code error "Missing source file: $src_file"
}
read_verilog -sv $src_file

# Read constraints
if {![file exists $xdc_file]} {
    return -code error "Missing XDC: $xdc_file"
}
read_xdc $xdc_file

set_property top $top [current_fileset]

puts "\n========================================"
puts "Starting Synthesis"
puts "========================================"
# Synthesis
synth_design -top $top -part $part
write_checkpoint -force [file join $build_dir ${top}_post_synth.dcp]
report_utilization -file [file join $rpt_dir ${top}_utilization_post_synth.rpt]

puts "\n========================================"
puts "Starting Optimization"
puts "========================================"
# Optimization
opt_design
report_utilization -file [file join $rpt_dir ${top}_utilization_post_opt.rpt]

puts "\n========================================"
puts "Starting Placement"
puts "========================================"
# Placement
place_design
report_utilization -file [file join $rpt_dir ${top}_utilization_post_place.rpt]

puts "\n========================================"
puts "Starting Routing"
puts "========================================"
# Routing
route_design

# Post-route reports
puts "\n========================================"
puts "Generating Reports"
puts "========================================"
report_utilization    -hierarchical -file [file join $rpt_dir ${top}_utilization_routed.rpt]
report_timing_summary -file [file join $rpt_dir ${top}_timing_summary.rpt]
report_power          -file [file join $rpt_dir ${top}_power.rpt]

# Generate bitstream
puts "\n========================================"
puts "Generating Bitstream"
puts "========================================"
write_bitstream  -force [file join $build_dir ${top}.bit]
write_checkpoint -force [file join $build_dir ${top}_routed.dcp]

puts "\n========================================"
puts "Build Complete!"
puts "========================================"
puts "Bitstream: build/hello_top_counters/${top}.bit"
puts "Checkpoint: build/hello_top_counters/${top}_routed.dcp"
puts "Reports in: reports/hello_top_counters/"
puts "========================================"
