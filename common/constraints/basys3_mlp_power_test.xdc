# MLP Power Measurement Test Constraints
# Target: Basys 3 (Artix-7 xc7a35tcpg236-1)
#
# Purpose: Constraints for idle vs. active power measurement
#
# Controls:
#   SW0  = rst_n (active low reset)
#   SW1  = run_enable (1 = continuous inference, 0 = idle)
#   SW15 = randomize_inputs (1 = new random inputs each inference)
#
# LEDs:
#   LD0  = heartbeat
#   LD1  = run_enable status
#   LD2  = busy
#   LD3  = done pulse
#   LD8-LD15 = inference_count[7:0]

# =============================================================================
# Clock - 100 MHz
# =============================================================================
set_property PACKAGE_PIN W5 [get_ports {clk}]
set_property IOSTANDARD LVCMOS33 [get_ports {clk}]
create_clock -period 10.000 -name sys_clk -waveform {0.000 5.000} [get_ports clk]

# =============================================================================
# Switch Inputs
# =============================================================================

# SW0 - Reset (active low)
set_property PACKAGE_PIN V17 [get_ports {rst_n}]
set_property IOSTANDARD LVCMOS33 [get_ports {rst_n}]
set_property PULLUP true [get_ports {rst_n}]

# SW1 - Run Enable (1 = continuous inference, 0 = idle)
set_property PACKAGE_PIN V16 [get_ports {run_enable}]
set_property IOSTANDARD LVCMOS33 [get_ports {run_enable}]

# SW15 - Randomize inputs each inference
set_property PACKAGE_PIN R2 [get_ports {randomize_en}]
set_property IOSTANDARD LVCMOS33 [get_ports {randomize_en}]

# =============================================================================
# LED Outputs
# =============================================================================

# LD0 - Heartbeat (slow blink idle, fast blink running)
set_property PACKAGE_PIN U16 [get_ports {led_heartbeat}]
set_property IOSTANDARD LVCMOS33 [get_ports {led_heartbeat}]
set_property DRIVE 8 [get_ports {led_heartbeat}]
set_property SLEW SLOW [get_ports {led_heartbeat}]

# LD1 - Run enable status
set_property PACKAGE_PIN E19 [get_ports {led_running}]
set_property IOSTANDARD LVCMOS33 [get_ports {led_running}]
set_property DRIVE 8 [get_ports {led_running}]
set_property SLEW SLOW [get_ports {led_running}]

# LD2 - Busy indicator
set_property PACKAGE_PIN U19 [get_ports {led_busy}]
set_property IOSTANDARD LVCMOS33 [get_ports {led_busy}]
set_property DRIVE 8 [get_ports {led_busy}]
set_property SLEW SLOW [get_ports {led_busy}]

# LD3 - Done pulse
set_property PACKAGE_PIN V19 [get_ports {led_done}]
set_property IOSTANDARD LVCMOS33 [get_ports {led_done}]
set_property DRIVE 8 [get_ports {led_done}]
set_property SLEW SLOW [get_ports {led_done}]

# LD8-LD15 - Inference count [7:0]
set_property PACKAGE_PIN V13 [get_ports {led_count[0]}]
set_property PACKAGE_PIN V3  [get_ports {led_count[1]}]
set_property PACKAGE_PIN W3  [get_ports {led_count[2]}]
set_property PACKAGE_PIN U3  [get_ports {led_count[3]}]
set_property PACKAGE_PIN P3  [get_ports {led_count[4]}]
set_property PACKAGE_PIN N3  [get_ports {led_count[5]}]
set_property PACKAGE_PIN P1  [get_ports {led_count[6]}]
set_property PACKAGE_PIN L1  [get_ports {led_count[7]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led_count[*]}]
set_property DRIVE 8 [get_ports {led_count[*]}]
set_property SLEW SLOW [get_ports {led_count[*]}]

# =============================================================================
# 7-Segment Display
# =============================================================================

# Segment outputs (active low) - CA, CB, CC, CD, CE, CF, CG
set_property PACKAGE_PIN W7 [get_ports {seg[0]}]
set_property PACKAGE_PIN W6 [get_ports {seg[1]}]
set_property PACKAGE_PIN U8 [get_ports {seg[2]}]
set_property PACKAGE_PIN V8 [get_ports {seg[3]}]
set_property PACKAGE_PIN U5 [get_ports {seg[4]}]
set_property PACKAGE_PIN V5 [get_ports {seg[5]}]
set_property PACKAGE_PIN U7 [get_ports {seg[6]}]
set_property IOSTANDARD LVCMOS33 [get_ports {seg[*]}]
set_property DRIVE 8 [get_ports {seg[*]}]
set_property SLEW SLOW [get_ports {seg[*]}]

# Anode enables (active low) - AN0, AN1, AN2, AN3
set_property PACKAGE_PIN U2 [get_ports {an[0]}]
set_property PACKAGE_PIN U4 [get_ports {an[1]}]
set_property PACKAGE_PIN V4 [get_ports {an[2]}]
set_property PACKAGE_PIN W4 [get_ports {an[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {an[*]}]
set_property DRIVE 8 [get_ports {an[*]}]
set_property SLEW SLOW [get_ports {an[*]}]

# =============================================================================
# Timing Constraints
# =============================================================================

# Asynchronous inputs from switches (use synchronizers in RTL)
set_false_path -from [get_ports rst_n]
set_false_path -from [get_ports run_enable]
set_false_path -from [get_ports randomize_en]

# LED outputs are not timing critical
set_false_path -to [get_ports led_heartbeat]
set_false_path -to [get_ports led_running]
set_false_path -to [get_ports led_busy]
set_false_path -to [get_ports led_done]
set_false_path -to [get_ports {led_count[*]}]
set_false_path -to [get_ports {seg[*]}]
set_false_path -to [get_ports {an[*]}]

# =============================================================================
# Configuration
# =============================================================================

set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property CFGBVS VCCO [current_design]

# Bitstream settings
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
set_property BITSTREAM.CONFIG.CONFIGRATE 33 [current_design]
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4 [current_design]
