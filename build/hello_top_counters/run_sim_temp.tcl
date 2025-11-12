# Auto-generated simulation script
puts "Starting simulation..."
run 1 ns

# Open SAIF file
open_saif "R:/fpga/fpga-power-test-accel/reports/hello_top_counters/hello_top_counters.saif"

# Log DUT signals - try both hierarchy possibilities
if {[catch {log_saif [get_objects -r /hello_top_counters_tb/dut/*]} err]} {
    puts "Error logging SAIF: $err"
    puts "Available instances:"
    puts [find instances -recursive *]
    quit
}
puts "SAIF logging started for /hello_top_counters_tb/dut/*"

# Run simulation for 1ms (100K cycles at 100MHz)
# This is sufficient for capturing switching activity
puts "Running simulation for 1ms..."
run 1 ms

# Close SAIF
close_saif
puts "SAIF file generated: R:/fpga/fpga-power-test-accel/reports/hello_top_counters/hello_top_counters.saif"

quit
