# Start from the script’s folder (or PWD if pasted into console)
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
set src_dir   [file normalize [file join $repo_root common rtl]]
set xdc_file  [file normalize [file join $repo_root common constraints basys3_hello_top.xdc]]
set build_dir [file normalize [file join $repo_root build]]
set rpt_dir   [file normalize [file join $repo_root reports]]

set part xc7a35tcpg236-1
set top  hello_top

puts "script_dir = $script_dir"
puts "repo_root  = $repo_root"
puts "src_dir    = $src_dir"
puts "xdc_file   = $xdc_file"
puts "build_dir  = $build_dir"
puts "rpt_dir    = $rpt_dir"
puts "part       = $part"
puts "top        = $top"

file mkdir $build_dir
file mkdir $rpt_dir

# Read sources
set sv_list [lsort -unique [glob -nocomplain -directory $src_dir *.sv]]
if {[llength $sv_list] == 0} {
    return -code error "No SV in $src_dir"
}
read_verilog -sv {*}$sv_list

if {![file exists $xdc_file]} {
    return -code error "Missing XDC: $xdc_file"
}
read_xdc $xdc_file

set_property top $top [current_fileset]

# Build
synth_design -top $top -part $part
write_checkpoint -force [file join $build_dir ${top}_post_synth.dcp]
opt_design
place_design
route_design

# Reports
report_utilization    -hierarchical -file [file join $rpt_dir ${top}_utilization_routed.rpt]
report_timing_summary -file [file join $rpt_dir ${top}_timing_summary.rpt]

# Artifacts
write_bitstream  -force [file join $build_dir ${top}.bit]
write_checkpoint -force [file join $build_dir ${top}_routed.dcp]

puts "OK: build/${top}.bit, build/${top}_routed.dcp; reports/*"
