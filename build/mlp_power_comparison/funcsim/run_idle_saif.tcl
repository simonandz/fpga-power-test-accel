open_saif "mlp_idle.saif"
log_saif [get_objects -r /tb_saif_idle/dut/*]
run all
close_saif
quit
