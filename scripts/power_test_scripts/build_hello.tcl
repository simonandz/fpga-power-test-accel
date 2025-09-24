# ===== Build: hello_top (Basys-3) =====
set script_dir  [file normalize [file dirname [info script]]]
set repo_root   [file normalize [file join $script_dir ..]]

set part        xc7a35tcpg236-1
set top         hello_top
set src_dir     [file join $repo_root common rtl]
set xdc_file    [file join $repo_root common constraints basys3_hello_top.xdc]
set build_dir   [file join $repo_root build]
set rpt_dir     [file join $repo_root reports]
file mkdir $build_dir; file mkdir $rpt_dir

# Read sources
set sv_list [lsort -unique [glob -nocomplain -directory $src_dir *.sv]]
if {[llength $sv_list] == 0} { return -code error "No SV in $src_dir" }
read_verilog -sv {*}$sv_list

if {![file exists $xdc_file]} { return -code error "Missing XDC: $xdc_file" }
read_xdc $xdc_file

# Build
synth_design -top $top -part $part
write_checkpoint -force [file join $build_dir ${top}_post_synth.dcp]
opt_design; place_design; route_design

# Reports
report_utilization    -hierarchical -file [file join $rpt_dir ${top}_utilization_routed.rpt]
report_timing_summary -file [file join $rpt_dir ${top}_timing_summary.rpt]

# Artifacts
write_bitstream  -force [file join $build_dir ${top}.bit]
write_checkpoint -force [file join $build_dir ${top}_routed.dcp]

puts "OK: build/${top}.bit, build/${top}_routed.dcp; reports/*"
