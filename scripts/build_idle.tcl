# ===== Non-project build for idle_top (idle baseline bitstream) =====

# Resolve paths relative to this script
set script_dir  [file normalize [file dirname [info script]]]
set repo_root   [file normalize [file join $script_dir ..]]

set part        xc7a35tcpg236-1

# Sources: allow both common/rtl and common/rtl/idle_baseline
set src_dir1    [file join $repo_root common rtl]
set src_dir2    [file join $repo_root common rtl idle_baseline]

# XDC specific to idle_top
set xdc_file    [file join $repo_root common constraints idle_baseline.xdc]

# Output dirs
set build_dir   [file join $repo_root build idle]
set rpt_dir     [file join $repo_root reports idle]
file mkdir $build_dir
file mkdir $rpt_dir

# Gather SystemVerilog sources
set sv_list {}
foreach d [list $src_dir1 $src_dir2] {
  set g [glob -nocomplain [file join $d *.sv]]
  if {[llength $g] > 0} {
    set sv_list [concat $sv_list $g]
  }
}
if {[llength $sv_list] == 0} {
  puts "ERROR: No .sv files found in $src_dir1 or $src_dir2"
  exit 1
}

# Read sources / constraints
read_verilog -sv $sv_list

if {![file exists $xdc_file]} {
  puts "ERROR: XDC not found: $xdc_file"
  exit 1
}
read_xdc $xdc_file

# Reports to verify pins/standards
report_io  -file [file join $rpt_dir io_report.rpt]

# Synthesize/implement
set top idle_top
synth_design -top $top -part $part
opt_design
place_design
route_design

# Timing/utilization reports
report_utilization    -hierarchical -file [file join $rpt_dir utilization_routed.rpt]
report_timing_summary -file [file join $rpt_dir timing_summary.rpt]

# Bitstream
write_bitstream -force [file join $build_dir ${top}.bit]
puts "OK: Bitstream at [file join $build_dir ${top}.bit]"
puts "Reports in $rpt_dir"
