open_saif "../../../reports/benchmark/mlp_benchmark.saif"
log_saif [get_objects -r /tb_mlp_benchmark/dut/*]
run all
close_saif
quit
