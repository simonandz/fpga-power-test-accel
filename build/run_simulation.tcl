open_saif "R:/fpga/fpga-power-test-accel/reports/hello_top_time.saif"
log_saif [get_objects -r *]
run 100 ms
close_saif
quit
