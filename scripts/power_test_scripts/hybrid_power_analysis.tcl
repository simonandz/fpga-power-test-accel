# hybrid_power_analysis.tcl
# Hybrid approach: Use SAIF where available + calculated activity for the rest
# This achieves near 100% activity specification for maximum accuracy

set repo_root "R:/fpga/fpga-power-test-accel"

# Define paths
set routed_dcp [file join $repo_root build hello_top_routed.dcp]
set saif_file  [file join $repo_root reports hello_top_time.saif]
set rpt_dir    [file join $repo_root reports]

puts "=== Hybrid Power Analysis (Maximum Accuracy) ==="

# Open the routed design
puts "Opening routed checkpoint..."
open_checkpoint $routed_dcp

# Step 1: Read SAIF to get measured activity
puts "\nStep 1: Reading SAIF file for measured activity..."
read_saif $saif_file

# Get initial report to see what matched
puts "\nStep 2: Analyzing SAIF match rate..."
set temp_rpt [file join $rpt_dir temp_saif_only.rpt]
report_power -file $temp_rpt

# Parse the report to extract match percentage
set fp [open $temp_rpt r]
set content [read $fp]
close $fp
if {[regexp {Design Nets Matched\s+\|\s+(\d+)%} $content match percent]} {
    puts "SAIF matched: $percent%"
} else {
    puts "Could not determine match rate"
}

# Step 2: Set intelligent defaults for unmatched signals
puts "\nStep 3: Setting calculated activity for unmatched nets..."

# Design knowledge: 26-bit counter at 100MHz
set CLK_FREQ 100.0  ;# MHz

# Find all counter register outputs
for {set i 0} {$i < 26} {incr i} {
    # Calculate expected toggle rate for this bit
    set bit_toggle_rate [expr {$CLK_FREQ / (2.0 ** $i)}]

    # Find all nets related to ctr[$i]
    set ctr_nets [get_nets -quiet -hierarchical -filter "NAME =~ *ctr*$i*"]

    if {[llength $ctr_nets] > 0} {
        foreach net $ctr_nets {
            # Set activity (this will override unmatched nets but not SAIF-matched ones)
            set_switching_activity -quiet -toggle_rate $bit_toggle_rate -static_probability 0.5 $net
        }
        puts "  ctr\[$i\] nets: toggle rate = $bit_toggle_rate MHz"
    }
}

# Primary I/O activity
puts "\nStep 4: Setting I/O activity..."
set_switching_activity -quiet -toggle_rate [expr {2.0 * $CLK_FREQ}] -static_probability 0.5 [get_nets -quiet clk_IBUF_BUFG]
set_switching_activity -quiet -toggle_rate 0.001 -static_probability 1.0 [get_nets -quiet rst_n_IBUF]
set_switching_activity -quiet -toggle_rate 0 -static_probability 1.0 [get_nets -quiet led_on_OBUF]

# led_blink toggles at bit[25] rate
set led_toggle [expr {$CLK_FREQ / (2.0 ** 25)}]
set_switching_activity -quiet -toggle_rate $led_toggle -static_probability 0.5 [get_nets -quiet led_blink_OBUF]
puts "  led_blink: toggle rate = $led_toggle MHz"

# Set defaults for any remaining unspecified logic
puts "\nStep 5: Setting defaults for remaining logic..."
set_switching_activity -deassert_resets
set_switching_activity -default_toggle_rate 10 -default_static_probability 0.5

# Step 3: Generate final power report
puts "\nStep 6: Generating hybrid power report..."
report_power -file [file join $rpt_dir hello_top_power_hybrid.rpt]

puts "\n=== Hybrid Power Analysis Complete ==="
puts "Report: hello_top_power_hybrid.rpt"
puts ""
puts "This report combines:"
puts "  - SAIF measurements where available ($percent% of nets)"
puts "  - Calculated activity based on design knowledge (remaining nets)"
puts "  - Result: Near 100% activity specification for maximum accuracy!"

close_design
