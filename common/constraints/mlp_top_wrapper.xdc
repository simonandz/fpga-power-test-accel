# MLP Accelerator Wrapper Constraints File
# Target: Basys3 Board (Artix-7 xc7a35tcpg236-1)
#
# This XDC is for mlp_top_wrapper which has a simplified interface
# for BRAM pre-loading scenarios

# =============================================================================
# Clock and Reset
# =============================================================================

# Clock - 100 MHz on Basys3
set_property PACKAGE_PIN W5 [get_ports {clk}]
set_property IOSTANDARD LVCMOS33 [get_ports {clk}]
create_clock -period 10.000 -name sys_clk -waveform {0.000 5.000} [get_ports clk]

# Reset - Active Low (SW0)
set_property PACKAGE_PIN V17 [get_ports {rst_n}]
set_property IOSTANDARD LVCMOS33 [get_ports {rst_n}]
set_property PULLUP true [get_ports {rst_n}]

# =============================================================================
# Control Signals
# =============================================================================

# Start signal - Button Center (BTNC)
set_property PACKAGE_PIN U18 [get_ports {start}]
set_property IOSTANDARD LVCMOS33 [get_ports {start}]

# Done indicator - LED15 (leftmost)
set_property PACKAGE_PIN L1 [get_ports {done}]
set_property IOSTANDARD LVCMOS33 [get_ports {done}]
set_property DRIVE 8 [get_ports {done}]
set_property SLEW SLOW [get_ports {done}]

# Busy indicator - LED14
set_property PACKAGE_PIN P1 [get_ports {busy}]
set_property IOSTANDARD LVCMOS33 [get_ports {busy}]
set_property DRIVE 8 [get_ports {busy}]
set_property SLEW SLOW [get_ports {busy}]

# Output valid - LED13
set_property PACKAGE_PIN N3 [get_ports {output_valid}]
set_property IOSTANDARD LVCMOS33 [get_ports {output_valid}]
set_property DRIVE 8 [get_ports {output_valid}]
set_property SLEW SLOW [get_ports {output_valid}]

# =============================================================================
# Configuration Inputs (num_inputs, num_outputs)
# =============================================================================

# num_inputs[15:0] - All 16 switches (SW15:SW0)
set_property PACKAGE_PIN V17 [get_ports {num_inputs[0]}]   # SW0
set_property PACKAGE_PIN V16 [get_ports {num_inputs[1]}]   # SW1
set_property PACKAGE_PIN W16 [get_ports {num_inputs[2]}]   # SW2
set_property PACKAGE_PIN W17 [get_ports {num_inputs[3]}]   # SW3
set_property PACKAGE_PIN W15 [get_ports {num_inputs[4]}]   # SW4
set_property PACKAGE_PIN V15 [get_ports {num_inputs[5]}]   # SW5
set_property PACKAGE_PIN W14 [get_ports {num_inputs[6]}]   # SW6
set_property PACKAGE_PIN W13 [get_ports {num_inputs[7]}]   # SW7
set_property PACKAGE_PIN V2  [get_ports {num_inputs[8]}]   # SW8
set_property PACKAGE_PIN T3  [get_ports {num_inputs[9]}]   # SW9
set_property PACKAGE_PIN T2  [get_ports {num_inputs[10]}]  # SW10
set_property PACKAGE_PIN R3  [get_ports {num_inputs[11]}]  # SW11
set_property PACKAGE_PIN W2  [get_ports {num_inputs[12]}]  # SW12
set_property PACKAGE_PIN U1  [get_ports {num_inputs[13]}]  # SW13
set_property PACKAGE_PIN T1  [get_ports {num_inputs[14]}]  # SW14
set_property PACKAGE_PIN R2  [get_ports {num_inputs[15]}]  # SW15
set_property IOSTANDARD LVCMOS33 [get_ports {num_inputs[*]}]

# num_outputs[15:0] - Using direction buttons + PMOD (or hardcode in test)
# For simple testing, you can also create a parameter in the wrapper to hardcode this

# Using 4 buttons for num_outputs[3:0] (allows up to 15 outputs)
set_property PACKAGE_PIN W19 [get_ports {num_outputs[0]}]  # BTNL
set_property PACKAGE_PIN T17 [get_ports {num_outputs[1]}]  # BTNR
set_property PACKAGE_PIN T18 [get_ports {num_outputs[2]}]  # BTNU
set_property PACKAGE_PIN U17 [get_ports {num_outputs[3]}]  # BTND
set_property IOSTANDARD LVCMOS33 [get_ports {num_outputs[3:0]}]

# Upper bits of num_outputs - using PMOD JA (pins 1-8)
set_property PACKAGE_PIN J1 [get_ports {num_outputs[4]}]   # JA1
set_property PACKAGE_PIN L2 [get_ports {num_outputs[5]}]   # JA2
set_property PACKAGE_PIN J2 [get_ports {num_outputs[6]}]   # JA3
set_property PACKAGE_PIN G2 [get_ports {num_outputs[7]}]   # JA4
set_property PACKAGE_PIN H1 [get_ports {num_outputs[8]}]   # JA7
set_property PACKAGE_PIN K2 [get_ports {num_outputs[9]}]   # JA8
set_property PACKAGE_PIN H2 [get_ports {num_outputs[10]}]  # JA9
set_property PACKAGE_PIN G3 [get_ports {num_outputs[11]}]  # JA10
set_property IOSTANDARD LVCMOS33 [get_ports {num_outputs[11:4]}]

# Remaining bits (12-15) - using PMOD JB
set_property PACKAGE_PIN A14 [get_ports {num_outputs[12]}] # JB1
set_property PACKAGE_PIN A16 [get_ports {num_outputs[13]}] # JB2
set_property PACKAGE_PIN B15 [get_ports {num_outputs[14]}] # JB3
set_property PACKAGE_PIN B16 [get_ports {num_outputs[15]}] # JB4
set_property IOSTANDARD LVCMOS33 [get_ports {num_outputs[15:12]}]

# =============================================================================
# Output Data Display
# =============================================================================

# Output data - Show results on LEDs (LD7:LD0)
set_property PACKAGE_PIN U16 [get_ports {output_data[0]}]  # LD0
set_property PACKAGE_PIN E19 [get_ports {output_data[1]}]  # LD1
set_property PACKAGE_PIN U19 [get_ports {output_data[2]}]  # LD2
set_property PACKAGE_PIN V19 [get_ports {output_data[3]}]  # LD3
set_property PACKAGE_PIN W18 [get_ports {output_data[4]}]  # LD4
set_property PACKAGE_PIN U15 [get_ports {output_data[5]}]  # LD5
set_property PACKAGE_PIN U14 [get_ports {output_data[6]}]  # LD6
set_property PACKAGE_PIN V14 [get_ports {output_data[7]}]  # LD7
set_property IOSTANDARD LVCMOS33 [get_ports {output_data[*]}]
set_property DRIVE 8 [get_ports {output_data[*]}]
set_property SLEW SLOW [get_ports {output_data[*]}]

# =============================================================================
# Timing Constraints
# =============================================================================

# Input delays (adjust based on external interface timing)
# Switches and buttons are asynchronous, so use generous margins
set_input_delay -clock [get_clocks sys_clk] -min 0.0 [get_ports {num_inputs[*]}]
set_input_delay -clock [get_clocks sys_clk] -max 5.0 [get_ports {num_inputs[*]}]
set_input_delay -clock [get_clocks sys_clk] -min 0.0 [get_ports {num_outputs[*]}]
set_input_delay -clock [get_clocks sys_clk] -max 5.0 [get_ports {num_outputs[*]}]
set_input_delay -clock [get_clocks sys_clk] -min 0.0 [get_ports start]
set_input_delay -clock [get_clocks sys_clk] -max 5.0 [get_ports start]

# Set inputs as asynchronous (debounce in design if needed)
set_false_path -from [get_ports start]
set_false_path -from [get_ports rst_n]
set_false_path -from [get_ports {num_inputs[*]}]
set_false_path -from [get_ports {num_outputs[*]}]

# Output delays for LEDs (not timing critical)
set_output_delay -clock [get_clocks sys_clk] -min -1.0 [get_ports {output_data[*]}]
set_output_delay -clock [get_clocks sys_clk] -max 3.0 [get_ports {output_data[*]}]
set_output_delay -clock [get_clocks sys_clk] -min -1.0 [get_ports done]
set_output_delay -clock [get_clocks sys_clk] -max 3.0 [get_ports done]
set_output_delay -clock [get_clocks sys_clk] -min -1.0 [get_ports busy]
set_output_delay -clock [get_clocks sys_clk] -max 3.0 [get_ports busy]
set_output_delay -clock [get_clocks sys_clk] -min -1.0 [get_ports output_valid]
set_output_delay -clock [get_clocks sys_clk] -max 3.0 [get_ports output_valid]

# =============================================================================
# Configuration
# =============================================================================

# Configuration voltage
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property CFGBVS VCCO [current_design]

# Bitstream settings
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
set_property BITSTREAM.CONFIG.CONFIGRATE 33 [current_design]
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4 [current_design]
