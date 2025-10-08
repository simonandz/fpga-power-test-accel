# test_vcd_matching.tcl
# Test VCD file matching vs SAIF matching

set repo_root "R:/fpga/fpga-power-test-accel"

# Define paths
set routed_dcp [file join $repo_root build hello_top_routed.dcp]
set vcd_file   [file join $repo_root reports gate_level.vcd]
set saif_file  [file join $repo_root reports hello_top_time.saif]
set rpt_dir    [file join $repo_root reports]

puts "=== Testing VCD vs SAIF Matching ==="

# Open the routed design
puts "Opening routed checkpoint..."
open_checkpoint $routed_dcp

# Test 1: Try VCD if it exists
if {[file exists $vcd_file]} {
    puts "\n--- Testing VCD file ---"
    puts "VCD: $vcd_file"

    if {[catch {
        read_vcd $vcd_file
        report_power -file [file join $rpt_dir hello_top_power_vcd_test.rpt]
        puts "VCD power report generated successfully!"
    } err]} {
        puts "VCD failed: $err"
    }

    # Close and reopen to clear activity
    close_design
    open_checkpoint $routed_dcp
}

# Test 2: Try SAIF with different strip_path options
puts "\n--- Testing SAIF with strip_path ---"
puts "SAIF: $saif_file"

if {[catch {
    read_saif $saif_file -strip_path {hello_tb/dut}
    report_power -file [file join $rpt_dir hello_top_power_saif_stripped.rpt]
    puts "SAIF with strip_path generated successfully!"
} err]} {
    puts "SAIF with strip_path failed: $err"
}

puts "\n=== Test Complete ==="
puts "Check the reports to compare 'Design Nets Matched' percentages:"
puts "  - hello_top_power_vcd_test.rpt"
puts "  - hello_top_power_saif_stripped.rpt"

close_design
