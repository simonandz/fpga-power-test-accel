# ===== Non-project build for Basys 3 hello_top =====

set script_dir  [file normalize [file dirname [info script]]]
set repo_root   [file normalize [file join $script_dir ..]]

set part        xc7a35tcpg236-1
set src_dir     [file join $repo_root common rtl]
set xdc_file    [file join $repo_root common constraints basys3.xdc]
set build_dir   [file join $repo_root build]
set rpt_dir     [file join $repo_root reports]

file mkdir $build_dir
file mkdir $rpt_dir

set sv_list [glob -nocomplain [file join $src_dir *.sv]]
if {[llength $sv_list] == 0} {
  puts "ERROR: No SystemVerilog files found in $src_dir"
  exit 1
}

read_verilog -sv $sv_list

if {![file exists $xdc_file]} {
  puts "ERROR: XDC not found: $xdc_file"
  exit 1
}
read_xdc $xdc_file

set top hello_top
synth_design -top $top -part $part

opt_design
place_design
route_design

report_utilization    -hierarchical -file [file join $rpt_dir utilization_routed.rpt]
report_timing_summary -file [file join $rpt_dir timing_summary.rpt]

# Bitstream
write_bitstream -force [file join $build_dir ${top}.bit]

puts "OK: Bitstream at [file join $build_dir ${top}.bit]"
puts "Reports in $rpt_dir"
