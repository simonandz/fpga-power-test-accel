# Auto-generated: run SAIF quickly
puts "Starting XSim run for SAIF..."
run 1 ns
set top /hello_top_counters_tb
puts "Top scope: $top"
puts "Letting testbench initialize..."
run 100 ns
set dut_scope ${top}/dut
puts "Logging SAIF under: $dut_scope"
catch { close_saif }
open_saif "C:/temp/hello_top_counters_timing.saif"
if {[catch { log_saif [get_objects -r ${dut_scope}/*] } e]} {
  puts "log_saif failed: $e"
  # Fallback: log everything (can be larger)
  log_saif [get_objects -r /*]
}
puts "Run 200us for activity..."
run 200 us
close_saif
puts "SAIF written: C:/temp/hello_top_counters_timing.saif"
quit
