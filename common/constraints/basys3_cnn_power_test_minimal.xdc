## Basys 3 Constraints for CNN Power Test - MINIMAL VERSION
## Only clock, reset, run_enable, and 1 LED

## Clock (100 MHz)
set_property -dict { PACKAGE_PIN W5   IOSTANDARD LVCMOS33 } [get_ports clk]
create_clock -period 10.000 -name sys_clk -waveform {0.000 5.000} [get_ports clk]

## Reset (SW0)
set_property -dict { PACKAGE_PIN V17  IOSTANDARD LVCMOS33 PULLUP true } [get_ports rst_n]

## Run Enable (SW1)
set_property -dict { PACKAGE_PIN V16  IOSTANDARD LVCMOS33 } [get_ports run_enable]

## Heartbeat LED (LD0)
set_property -dict { PACKAGE_PIN U16  IOSTANDARD LVCMOS33 } [get_ports led_heartbeat]

## Timing constraints for async inputs
set_false_path -from [get_ports rst_n]
set_false_path -from [get_ports run_enable]

## Configuration
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property CFGBVS VCCO [current_design]
set_property BITSTREAM.CONFIG.CONFIGRATE 33 [current_design]
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4 [current_design]
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
