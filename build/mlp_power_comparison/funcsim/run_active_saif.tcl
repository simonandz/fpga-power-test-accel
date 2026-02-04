open_saif "mlp_active.saif"
log_saif [get_objects -r /tb_saif_active/dut/*]
run all
close_saif
quit
