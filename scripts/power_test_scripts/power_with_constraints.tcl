# power_with_constraints.tcl
# Use Vivado's built-in power estimation with activity constraints
# This can be more accurate than partial SAIF matching

set repo_root "R:/fpga/fpga-power-test-accel"

# Define paths
set routed_dcp [file join $repo_root build hello_top_routed.dcp]
set rpt_dir    [file join $repo_root reports]

puts "=== Power Analysis with Activity Constraints ==="

# Open the routed design
puts "Opening routed checkpoint..."
open_checkpoint $routed_dcp

# Set switching activity on specific signals
# For a counter at 100MHz, most bits toggle at different rates
puts "\nSetting switching activity based on design knowledge..."

# Clock is 100MHz
set_switching_activity -toggle_rate 200 -static_probability 0.5 [get_nets clk_IBUF_BUFG]

# Reset is mostly inactive after startup
set_switching_activity -toggle_rate 0.001 -static_probability 1.0 [get_nets rst_n_IBUF]

# LED signals
set_switching_activity -toggle_rate 0 -static_probability 1.0 [get_nets led_on_OBUF]

# Counter bits - each bit toggles at half the frequency of the previous
# For DIV_BIT=26, counter runs at 100MHz
# ctr[0] toggles at 50MHz, ctr[1] at 25MHz, etc.
set counter_base_freq 100.0  ;# MHz
for {set i 0} {$i < 26} {incr i} {
    set bit_freq [expr {$counter_base_freq / (2.0 ** ($i + 1))}]
    set toggle_rate [expr {2.0 * $bit_freq}]  ;# Toggle rate is 2x frequency

    # Find nets matching this counter bit
    set nets [get_nets -quiet -filter "NAME =~ *ctr*\[$i\]*"]
    if {[llength $nets] > 0} {
        set_switching_activity -toggle_rate $toggle_rate -static_probability 0.5 $nets
        puts "Set ctr\[$i\] toggle rate: $toggle_rate MHz"
    }
}

# Set default activity for remaining nets (typical logic)
set_switching_activity -default_toggle_rate 12.5 -default_static_probability 0.5

# Generate power report
puts "\nGenerating power report with activity constraints..."
report_power -file [file join $rpt_dir hello_top_power_constrained.rpt]

puts "\n=== Power Analysis Complete ==="
puts "Report: hello_top_power_constrained.rpt"
puts "This should show 100% activity specification!"

close_design
