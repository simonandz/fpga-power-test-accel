## ===== Basys 3 (Artix-7 XC7A35T) — idle_top =====
## Clock: 100 MHz on W5
## Reset: SW0 on V17 (active-low)
## LED  : LD0 on U16

set_property PACKAGE_PIN W5          [get_ports {clk}]
set_property IOSTANDARD LVCMOS33     [get_ports {clk}]
create_clock -name sys_clk -period 10.000 [get_ports {clk}]

set_property PACKAGE_PIN V17         [get_ports {rst_n}]
set_property IOSTANDARD LVCMOS33     [get_ports {rst_n}]
set_property PULLUP true             [get_ports {rst_n}]

set_property PACKAGE_PIN U16         [get_ports {led0}]
set_property IOSTANDARD LVCMOS33     [get_ports {led0}]
set_property DRIVE 8                 [get_ports {led0}]
set_property SLEW SLOW               [get_ports {led0}]
