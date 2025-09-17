# ===== Non-project build for idle_top (idle baseline bitstream) =====

# 0) Ensure we're NOT in a project session (avoid filemgmt warnings)
if {[llength [get_projects]] > 0} {
  puts "INFO: Closing existing project to switch to non-project flow..."
  close_project -quiet
}

# 1) Resolve paths
set script_dir  [file normalize [file dirname [info script]]]
set repo_root   [file normalize [file join $script_dir ..]]

set part        xc7a35tcpg236-1
set src_idle    [file join $repo_root common rtl idle_top.sv]
set xdc_file    [file join $repo_root common constraints idle_baseline.xdc]
set build_dir   [file join $repo_root build idle]
set rpt_dir     [file join $repo_root reports idle]

file mkdir $build_dir
file mkdir $rpt_dir

# 2) Read sources / constraints (non-project)
if {![file exists $src_idle]} {
  puts "ERROR: Missing RTL: $src_idle"
  exit 1
}
read_verilog -sv $src_idle

if {![file exists $xdc_file]} {
  puts "ERROR: Missing XDC: $xdc_file"
  exit 1
}
read_xdc $xdc_file

# 3) Synthesize/implement
set top idle_top
synth_design -top $top -part $part

# Now we have an open synthesized design → safe to run IO/timing reports
report_io                 -file [file join $rpt_dir io_report_post_synth.rpt]
report_timing_summary     -file [file join $rpt_dir timing_post_synth.rpt]

opt_design
place_design
route_design

# 4) Post-route reports
report_utilization        -hierarchical -file [file join $rpt_dir utilization_routed.rpt]
report_timing_summary     -file [file join $rpt_dir timing_summary_routed.rpt]
report_io                 -file [file join $rpt_dir io_report_routed.rpt]

# 5) Artifacts
set dcp_path [file join $build_dir ${top}_routed.dcp]
set bit_path [file join $build_dir ${top}.bit]
write_checkpoint -force $dcp_path
write_bitstream  -force $bit_path

puts "=================================================="
puts "Bitstream : $bit_path"
puts "Checkpoint: $dcp_path"
puts "Reports   : $rpt_dir"
puts "=================================================="
