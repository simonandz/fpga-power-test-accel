# analyze_design_nets.tcl
# Analyze the actual net names in the routed design
# This helps us create accurate activity specifications

set repo_root "R:/fpga/fpga-power-test-accel"
set routed_dcp [file join $repo_root build hello_top_routed.dcp]

puts "=== Analyzing Design Net Names ==="

open_checkpoint $routed_dcp

puts "\n--- All Nets in Design ---"
set all_nets [get_nets -hierarchical]
puts "Total nets: [llength $all_nets]"

puts "\n--- Sample of Net Names (first 20) ---"
set count 0
foreach net [lsort $all_nets] {
    puts "  $net"
    incr count
    if {$count >= 20} break
}

puts "\n--- Clock Nets ---"
set clk_nets [get_nets -hierarchical -filter {TYPE == GLOBAL_CLOCK}]
foreach net $clk_nets {
    puts "  $net"
}

puts "\n--- Counter Related Nets ---"
set ctr_nets [get_nets -hierarchical -filter {NAME =~ *ctr*}]
puts "Counter nets found: [llength $ctr_nets]"
set count 0
foreach net [lsort $ctr_nets] {
    puts "  $net"
    incr count
    if {$count >= 30} {
        puts "  ... ([expr {[llength $ctr_nets] - 30}] more)"
        break
    }
}

puts "\n--- LED Nets ---"
set led_nets [get_nets -hierarchical -filter {NAME =~ *led*}]
foreach net $led_nets {
    puts "  $net"
}

puts "\n--- Register Outputs ---"
set all_regs [get_cells -hierarchical -filter {IS_SEQUENTIAL}]
puts "Total sequential cells: [llength $all_regs]"
puts "Sample register cells:"
set count 0
foreach reg [lsort $all_regs] {
    puts "  $reg"
    incr count
    if {$count >= 10} {
        puts "  ..."
        break
    }
}

close_design

puts "\n=== Analysis Complete ==="
puts "Use this information to refine manual activity specifications"
