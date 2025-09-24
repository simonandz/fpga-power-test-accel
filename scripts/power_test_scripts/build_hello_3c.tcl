# ===== Build: hello_top_3c (Basys-3) =====

# --- Robust repo root resolution ---
set script_dir [file normalize [file dirname [info script]]]   ;# …/scripts or …/scripts/power_test_scripts
set cand1      [file dirname $script_dir]                      ;# parent (…/scripts)
set cand2      [file dirname $cand1]                           ;# grandparent (repo root candidate)

# Optional override: vivado ... -source scripts/build_hello_3c.tcl -tclargs R:/fpga/fpga-power-test-accel
if {[llength $::argv] >= 1} {
  set repo_root [file normalize [lindex $::argv 0]]
} else {
  if {[file isdirectory [file join $cand1 common rtl]]} {
    set repo_root $cand1
  } elseif {[file isdirectory [file join $cand2 common rtl]]} {
    set repo_root $cand2
  } else {
    set repo_root $cand2
  }
}

# --- Build settings ---
set part        xc7a35tcpg236-1
set top         hello_top_3c

set src_dir     [file join $repo_root common rtl]
set xdc_dir     [file join $repo_root common constraints]
set xdc_file    [file join $xdc_dir basys3_hello_top_3c.xdc]

set build_dir   [file join $repo_root build]
set rpt_dir     [file join $repo_root reports]
file mkdir $build_dir
file mkdir $rpt_dir

# --- Debug printout ---
puts "== DEBUG =="
puts "script_dir = $script_dir"
puts "repo_root  = $repo_root"
puts "src_dir    = $src_dir"
puts "xdc_dir    = $xdc_dir"
puts "build_dir  = $build_dir"
puts "rpt_dir    = $rpt_dir"
puts "xdc_file   = $xdc_file"

# --- Collect & read SV sources (absolute paths) ---
set sv_list [lsort -unique [glob -nocomplain -directory $src_dir *.sv]]
puts "SV files found:"
foreach f $sv_list { puts "  [file normalize $f]" }
if {[llength $sv_list] == 0} {
  return -code error "No SV in $src_dir"
}
read_verilog -sv {*}$sv_list

# --- Read constraints (list what's there; hard fail if missing) ---
puts "XDCs present under $xdc_dir:"
foreach xf [lsort -dict [glob -nocomplain -directory $xdc_dir *.xdc]] {
  puts "  [file tail $xf]"
}
if {![file exists $xdc_file]} {
  return -code error "Missing XDC: $xdc_file"
}
read_xdc $xdc_file

# --- Synthesis & Implementation ---
puts "INFO: Synthesizing top='$top' part=$part"
synth_design -top $top -part $part
write_checkpoint -force [file join $build_dir ${top}_post_synth.dcp]

opt_design
place_design
route_design

# --- Reports ---
report_utilization    -hierarchical -file [file join $rpt_dir ${top}_utilization_routed.rpt]
report_timing_summary -file [file join $rpt_dir ${top}_timing_summary.rpt]

# --- Artifacts ---
write_bitstream  -force [file join $build_dir ${top}.bit]
write_checkpoint -force [file join $build_dir ${top}_routed.dcp]

puts "OK: build/${top}.bit"
puts "OK: build/${top}_post_synth.dcp"
puts "OK: build/${top}_routed.dcp"
puts "OK: reports/${top}_*.rpt"
