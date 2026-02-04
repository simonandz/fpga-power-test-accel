
    # Clock constraint - 100 MHz (10 ns period)
    create_clock -period 10.000 -name clk [get_ports clk]

    # Set all inputs/outputs as unconstrained for benchmark (no board-specific pins)
    set_false_path -from [get_ports -filter {DIRECTION == IN && NAME != "clk"}]
    set_false_path -to [get_ports -filter {DIRECTION == OUT}]

