# Clock 100 MHz
set_property PACKAGE_PIN W5          [get_ports {clk}]
set_property IOSTANDARD LVCMOS33     [get_ports {clk}]
create_clock -name sys_clk -period 10.000 [get_ports {clk}]

# Reset (SW0)
set_property PACKAGE_PIN V17         [get_ports {rst_n}]
set_property IOSTANDARD LVCMOS33     [get_ports {rst_n}]
set_property PULLUP true             [get_ports {rst_n}]

# LEDs
set_property PACKAGE_PIN U16         [get_ports {led_on}]        ;# LD0
set_property IOSTANDARD LVCMOS33     [get_ports {led_on}]
set_property DRIVE 8                 [get_ports {led_on}]
set_property SLEW SLOW               [get_ports {led_on}]

set_property PACKAGE_PIN E19         [get_ports {led_blink0}]    ;# LD1
set_property IOSTANDARD LVCMOS33     [get_ports {led_blink0}]
set_property DRIVE 8                 [get_ports {led_blink0}]
set_property SLEW SLOW               [get_ports {led_blink0}]

set_property PACKAGE_PIN U19         [get_ports {led_blink1}]    ;# LD2
set_property IOSTANDARD LVCMOS33     [get_ports {led_blink1}]
set_property DRIVE 8                 [get_ports {led_blink1}]
set_property SLEW SLOW               [get_ports {led_blink1}]
