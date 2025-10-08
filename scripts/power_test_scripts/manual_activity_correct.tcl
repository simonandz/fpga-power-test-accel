# manual_activity_correct.tcl
# 100% manual activity specification with CORRECT toggle rate units
# Toggle rate in Vivado is a percentage (0-100), NOT frequency

set repo_root "R:/fpga/fpga-power-test-accel"

# Define paths
set routed_dcp [file join $repo_root build hello_top_routed.dcp]
set rpt_dir    [file join $repo_root reports]

puts "=== 100% Manual Activity Specification ==="

# Helper function to ensure valid static_probability for given toggle_rate
# Constraint: static_prob >= toggle_rate/200 AND static_prob <= 1 - toggle_rate/200
proc calc_static_prob {toggle_rate desired_prob} {
    set min_prob [expr {$toggle_rate / 200.0}]
    set max_prob [expr {1.0 - ($toggle_rate / 200.0)}]

    # Clamp to valid range
    if {$desired_prob < $min_prob} {
        return $min_prob
    } elseif {$desired_prob > $max_prob} {
        return $max_prob
    } else {
        return $desired_prob
    }
}

# Open the routed design
puts "\nOpening routed checkpoint..."
open_checkpoint $routed_dcp

# Design parameters
set CLK_FREQ 100.0      ;# 100 MHz clock (10ns period)
set DIV_BIT 26          ;# Counter width

puts "\n--- Setting Primary I/O Activity ---"

# Clock - Don't set activity on clock nets, they're handled by timing constraints
# set clk_nets [get_nets -quiet -hierarchical -filter {NAME =~ *clk*BUFG*}]
# Clock activity is automatically derived from create_clock constraints
puts "Clock nets: Activity derived from timing constraints"

# Reset - virtually never toggles after startup (mostly high)
set rst_nets [get_nets -quiet -hierarchical -filter {NAME =~ *rst*}]
if {[llength $rst_nets] > 0} {
    set rst_toggle 0.01
    set rst_prob [calc_static_prob $rst_toggle 0.99]
    set_switching_activity -toggle_rate $rst_toggle -static_probability $rst_prob $rst_nets
    puts "Reset nets: [llength $rst_nets] nets @ ${rst_toggle}% toggle, ${rst_prob} static prob"
}

# LED on - constant 1, never toggles
set led_on_nets [get_nets -quiet -hierarchical -filter {NAME =~ *led_on*}]
if {[llength $led_on_nets] > 0} {
    set_switching_activity -toggle_rate 0.0 -static_probability 1.0 $led_on_nets
    puts "LED on nets: [llength $led_on_nets] nets @ 0% toggle rate (constant high)"
}

# LED blink - toggles once every 2^26 cycles
set led_blink_toggle_pct [expr {100.0 / (2.0 ** $DIV_BIT)}]
set led_blink_nets [get_nets -quiet -hierarchical -filter {NAME =~ *led_blink*}]
if {[llength $led_blink_nets] > 0} {
    set blink_prob [calc_static_prob $led_blink_toggle_pct 0.5]
    set_switching_activity -toggle_rate $led_blink_toggle_pct -static_probability $blink_prob $led_blink_nets
    puts "LED blink nets: [llength $led_blink_nets] nets @ ${led_blink_toggle_pct}% toggle, ${blink_prob} static prob"
}

puts "\n--- Setting Counter Register Activity ---"

# Counter bits - each bit toggles at different rates
# ctr[0] toggles every cycle = 100%
# ctr[1] toggles every 2 cycles = 50%
# ctr[2] toggles every 4 cycles = 25%
# ctr[i] toggles with probability = 100 / 2^(i+1) percent

set total_ctr_nets 0
for {set i 0} {$i < $DIV_BIT} {incr i} {
    # Toggle rate percentage = 100 / 2^(i+1)
    set bit_toggle_pct [expr {100.0 / (2.0 ** ($i + 1))}]

    # Clamp to reasonable range (Vivado may have minimum)
    if {$bit_toggle_pct < 0.0001} {
        set bit_toggle_pct 0.0001
    }

    # Find all nets related to this counter bit
    set bit_nets [get_nets -quiet -hierarchical -filter "NAME =~ *ctr*\\\[$i\\\]*"]

    if {[llength $bit_nets] > 0} {
        set bit_prob [calc_static_prob $bit_toggle_pct 0.5]
        set_switching_activity -toggle_rate $bit_toggle_pct -static_probability $bit_prob $bit_nets
        incr total_ctr_nets [llength $bit_nets]

        if {$i < 8 || $i == [expr {$DIV_BIT - 1}]} {
            puts [format "  ctr\[%2d\]: %d nets @ %.6f%% toggle" $i [llength $bit_nets] $bit_toggle_pct]
        } elseif {$i == 8} {
            puts "  ..."
        }
    }
}
puts "Total counter nets configured: $total_ctr_nets"

puts "\n--- Setting Carry Chain Activity ---"

# CARRY4 cells and their outputs - moderate activity
set carry_cells [get_cells -quiet -hierarchical -filter {REF_NAME == CARRY4}]
puts "CARRY4 cells found: [llength $carry_cells]"

if {[llength $carry_cells] > 0} {
    foreach carry $carry_cells {
        set carry_nets [get_nets -quiet -of_objects [get_pins -of_objects $carry -filter {DIRECTION == OUT}]]
        if {[llength $carry_nets] > 0} {
            # Carry chains have moderate activity - use 25% toggle rate
            set_switching_activity -quiet -toggle_rate 25.0 -static_probability 0.5 $carry_nets
        }
    }
    puts "CARRY4 output nets configured @ 25% toggle rate"
}

puts "\n--- Setting Default Activity for Remaining Nets ---"

# Set defaults for any unspecified logic - typical toggle rate is 12.5%
set_switching_activity -default_toggle_rate 12.5 -default_static_probability 0.5

# Deassert resets for power analysis
set_switching_activity -deassert_resets

puts "\n--- Generating Power Report ---"

# Check how many nets we've configured
set all_nets [get_nets -hierarchical]
puts "Total nets in design: [llength $all_nets]"

# Generate power report
report_power -file [file join $rpt_dir hello_top_power_manual_correct.rpt]

puts "\n=== Complete ==="
puts "Report: hello_top_power_manual_correct.rpt"
puts ""
puts "Toggle Rate Units in Vivado:"
puts "  - 100% = signal toggles every clock cycle"
puts "  - 50% = signal toggles every 2 clock cycles"
puts "  - 25% = signal toggles every 4 clock cycles"
puts "  - etc."
puts ""
puts "This report has complete activity specification."
puts "Check 'Design Nets Matched' - should show high user-specified activity."

close_design
