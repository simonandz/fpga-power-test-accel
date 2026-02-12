# CNN Power Measurement Build Script - FULL VERSION
# Generates bitstream with all LEDs + 7-segment display
#
# Controls on board:
#   SW0  = rst_n (active low reset)
#   SW1  = run_enable (0 = idle, 1 = continuous inference)
#   SW15 = randomize_en (1 = new random inputs each inference)
#
# LEDs:
#   LD0 = heartbeat, LD1 = running, LD2 = busy, LD3 = done
#   LD8-LD15 = inference count [7:0]

set _here [expr {[info script] ne "" ? [file dirname [info script]] : [pwd]}]
set script_dir [file normalize $_here]

# Find repo root
set probe $script_dir
set repo_root ""
for {set i 0} {$i < 5} {incr i} {
    if {[file isdirectory [file join $probe cnn rtl]]} {
        set repo_root [file normalize $probe]
        break
    }
    set parent [file normalize [file join $probe ..]]
    if {$parent eq $probe} { break }
    set probe $parent
}
if {$repo_root eq ""} {
    return -code error "Could not locate repo root"
}

# Directory setup
set cnn_rtl_dir    [file normalize [file join $repo_root cnn rtl]]
set common_rtl_dir [file normalize [file join $repo_root common rtl]]
set constr_dir     [file normalize [file join $repo_root common constraints]]
set build_dir      [file normalize [file join $repo_root build cnn_power_test]]
set rpt_dir        [file normalize [file join $repo_root reports cnn_power_test]]

set part xc7a35tcpg236-1
set top cnn_power_test_wrapper

puts "============================================"
puts "CNN Power Measurement Build - FULL"
puts "============================================"
puts "repo_root  = $repo_root"
puts "build_dir  = $build_dir"
puts "part       = $part"
puts "top        = $top"
puts "============================================"

file mkdir $build_dir
file mkdir $rpt_dir

catch {close_project}

create_project cnn_power_test $build_dir -part $part -force

puts "\n=========================================="
puts "Adding RTL Sources..."
puts "=========================================="

# Add all CNN RTL sources
add_files -fileset sources_1 [glob $cnn_rtl_dir/*.sv]

# Add common RTL sources
add_files -fileset sources_1 [glob $common_rtl_dir/*.sv]

# Set top module
set_property top $top [current_fileset]
update_compile_order -fileset sources_1

puts "Added source files:"
foreach f [get_files -of_objects [get_filesets sources_1]] {
    puts "  [file tail $f]"
}

puts "\n=========================================="
puts "Adding Constraints..."
puts "=========================================="

set xdc_file [file join $constr_dir basys3_cnn_power_test.xdc]
if {![file exists $xdc_file]} {
    return -code error "Constraints file not found: $xdc_file"
}
add_files -fileset constrs_1 $xdc_file
set_property target_constrs_file $xdc_file [current_fileset -constrset]
puts "Added constraints: [file tail $xdc_file]"

puts "\n=========================================="
puts "Running Synthesis..."
puts "=========================================="

launch_runs synth_1 -jobs 4
wait_on_run synth_1

if {[get_property PROGRESS [get_runs synth_1]] != "100%"} {
    puts "ERROR: Synthesis failed!"
    return -code error "Synthesis failed"
}
puts "Synthesis complete!"

open_run synth_1
report_utilization -hierarchical -file [file join $rpt_dir ${top}_utilization_synth.rpt]
puts "Utilization report: ${top}_utilization_synth.rpt"

puts "\n=========================================="
puts "Running Implementation..."
puts "=========================================="

launch_runs impl_1 -jobs 4
wait_on_run impl_1

if {[get_property PROGRESS [get_runs impl_1]] != "100%"} {
    puts "ERROR: Implementation failed!"
    return -code error "Implementation failed"
}
puts "Implementation complete!"

puts "\n=========================================="
puts "Generating Reports..."
puts "=========================================="

open_run impl_1
report_utilization -hierarchical -file [file join $rpt_dir ${top}_utilization_routed.rpt]
report_timing_summary -file [file join $rpt_dir ${top}_timing_summary.rpt]
report_power -file [file join $rpt_dir ${top}_power_estimate.rpt]

puts "Reports generated:"
puts "  - ${top}_utilization_routed.rpt"
puts "  - ${top}_timing_summary.rpt"
puts "  - ${top}_power_estimate.rpt"

puts "\n=========================================="
puts "Generating Bitstream..."
puts "=========================================="

launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1

set bit_src [file join $build_dir cnn_power_test.runs impl_1 ${top}.bit]
set bit_dst [file join $build_dir ${top}.bit]

if {[file exists $bit_src]} {
    file copy -force $bit_src $bit_dst
    puts "Bitstream: $bit_dst"
} else {
    puts "WARNING: Bitstream not found at expected location"
    puts "Check: $bit_src"
}

puts "\n=========================================="
puts "Build Complete!"
puts "=========================================="
puts ""
puts "Bitstream: build/cnn_power_test/${top}.bit"
puts ""
puts "============================================"
puts "POWER MEASUREMENT INSTRUCTIONS"
puts "============================================"
puts ""
puts "CNN Accelerator: 3x3 conv, 16x16 input, 9 DSPs"
puts ""
puts "Board Controls:"
puts "  SW0  = rst_n (1=normal, 0=reset)"
puts "  SW1  = run_enable (0=IDLE, 1=RUNNING)"
puts "  SW15 = randomize inputs (1=random, 0=fixed)"
puts ""
puts "LED Indicators:"
puts "  LD0 = heartbeat (slow=idle, fast=running)"
puts "  LD1 = run_enable status"
puts "  LD2 = busy"
puts "  LD3 = done pulse"
puts "  LD8-LD15 = inference count"
puts ""
puts "7-Segment: Shows inference count in hex"
puts ""
puts "============================================"
