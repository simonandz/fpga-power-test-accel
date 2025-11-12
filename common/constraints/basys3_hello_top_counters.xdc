## Clock 100 MHz
set_property PACKAGE_PIN W5              [get_ports {clk}]
set_property IOSTANDARD LVCMOS33         [get_ports {clk}]
create_clock -name sys_clk -period 10.000 [get_ports {clk}]

## Reset (SW0) - active-low in RTL; pull-up keeps it deasserted by default
set_property PACKAGE_PIN V17             [get_ports {rst_n}]
set_property IOSTANDARD LVCMOS33         [get_ports {rst_n}]
set_property PULLUP true                 [get_ports {rst_n}]


