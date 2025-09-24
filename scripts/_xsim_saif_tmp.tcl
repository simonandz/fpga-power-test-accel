open_saif "R:/fpga/fpga-power-test-accel/reports/hello_top.saif"
log_saif [get_objects -r /hello_tb/dut/*]
run 10 ms
close_saif
quit
