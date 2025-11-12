# power_report_hello_top_counters.tcl
# Reads a routed checkpoint and SAIF file, then generates power reports for hello_top_counters

# Start from the script's folder (or PWD if pasted into console)
set _here [expr {[info script] ne "" ? [file dirname [info script]] : [pwd]}]
set script_dir [file normalize $_here]

# Walk up until we find a directory that contains common/rtl
set probe $script_dir
set repo_root ""
for {set i 0} {$i < 5} {incr i} {
    if {[file isdirectory [file join $probe common rtl]]} {
        set repo_root [file normalize $probe]
        break
    }
    set parent [file normalize [file join $probe ..]]
    if {$parent eq $probe} { break }  ;# reached filesystem root
    set probe $parent
}
if {$repo_root eq ""} {
    return -code error "Could not locate repo root from $script_dir (no 'common/rtl' found up to 5 levels)"
}

# Define paths
set routed_dcp [file join $repo_root build hello_top_counters hello_top_counters_routed.dcp]
set saif_file  [file join $repo_root reports hello_top_counters hello_top_counters.saif]
set rpt_dir    [file join $repo_root reports hello_top_counters]

puts "========================================"
puts "Vivado Power Report Generation"
puts "for hello_top_counters"
puts "========================================"
puts "Routed DCP: $routed_dcp"
puts "SAIF file:  $saif_file"
puts "Reports:    $rpt_dir"
puts "========================================"

# Verify files exist
if {![file exists $routed_dcp]} {
    error "Routed checkpoint not found: $routed_dcp\nPlease run build_hello_top_counters.tcl first"
}
if {![file exists $saif_file]} {
    error "SAIF file not found: $saif_file\nPlease run the simulation with run_sim_hello_top_counters.tcl first"
}

# Ensure report directory exists
file mkdir $rpt_dir

# Open the routed design
puts "\nOpening routed checkpoint..."
open_checkpoint $routed_dcp

# Read SAIF file
# The SAIF has testbench hierarchy hello_top_counters_tb/dut
# Vivado will match signals based on hierarchy names
puts "\nReading SAIF file..."
read_saif $saif_file

puts "\nAnalyzing SAIF matching..."
puts "Note: Vivado will report how many signals matched from the SAIF"

# Generate comprehensive power reports
puts "\n========================================"
puts "Generating Power Reports"
puts "========================================"

puts "1. Power report with SAIF activity (detailed)..."
report_power -file [file join $rpt_dir hello_top_counters_power_saif.rpt]

puts "2. Power summary report..."
report_power -file [file join $rpt_dir hello_top_counters_power_summary.rpt]

puts "3. Hierarchical power breakdown..."
report_power -file [file join $rpt_dir hello_top_counters_power_hierarchical.rpt] -hierarchical

puts "4. Power by hierarchy level (all levels)..."
report_power -file [file join $rpt_dir hello_top_counters_power_by_level.rpt] -hierarchical -levels 10

puts "\n========================================"
puts "Power Report Generation Complete"
puts "========================================"
puts "Reports written to: $rpt_dir"
puts ""
puts "Available reports:"
puts "  - hello_top_counters_power_saif.rpt        (detailed with SAIF)"
puts "  - hello_top_counters_power_summary.rpt     (summary)"
puts "  - hello_top_counters_power_hierarchical.rpt (hierarchical breakdown)"
puts "  - hello_top_counters_power_by_level.rpt    (power by hierarchy level)"
puts "========================================"
