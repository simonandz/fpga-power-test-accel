-- Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
-- Copyright 2022-2024 Advanced Micro Devices, Inc. All Rights Reserved.
-- --------------------------------------------------------------------------------
-- Tool Version: Vivado v.2024.2 (win64) Build 5239630 Fri Nov 08 22:35:27 MST 2024
-- Date        : Wed Oct  1 14:37:54 2025
-- Host        : DESKTOP-VAD40IB running 64-bit major release  (build 9200)
-- Command     : write_vhdl -mode funcsim -file R:/fpga/fpga-power-test-accel/reports/post_impl_netlist.vhd
-- Design      : hello_top
-- Purpose     : This VHDL netlist is a functional simulation representation of the design and should not be modified or
--               synthesized. This netlist cannot be used for SDF annotated simulation.
-- Device      : xc7a35tcpg236-1
-- --------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
library UNISIM;
use UNISIM.VCOMPONENTS.ALL;
entity hello_top is
  port (
    clk : in STD_LOGIC;
    rst_n : in STD_LOGIC;
    led_on : out STD_LOGIC;
    led_blink : out STD_LOGIC
  );
  attribute NotValidForBitStream : boolean;
  attribute NotValidForBitStream of hello_top : entity is true;
  attribute DIV_BIT : string;
  attribute DIV_BIT of hello_top : entity is "26";
  attribute \DesignAttr:ENABLE_AIE_NETLIST_VIEW\ : boolean;
  attribute \DesignAttr:ENABLE_AIE_NETLIST_VIEW\ of hello_top : entity is std.standard.true;
  attribute \DesignAttr:ENABLE_NOC_NETLIST_VIEW\ : boolean;
  attribute \DesignAttr:ENABLE_NOC_NETLIST_VIEW\ of hello_top : entity is std.standard.true;
  attribute ECO_CHECKSUM : string;
  attribute ECO_CHECKSUM of hello_top : entity is "11e553c";
end hello_top;

architecture STRUCTURE of hello_top is
  signal clear : STD_LOGIC;
  signal clk_IBUF : STD_LOGIC;
  signal clk_IBUF_BUFG : STD_LOGIC;
  signal \ctr[0]_i_3_n_0\ : STD_LOGIC;
  signal \ctr_reg[0]_i_2_n_0\ : STD_LOGIC;
  signal \ctr_reg[0]_i_2_n_4\ : STD_LOGIC;
  signal \ctr_reg[0]_i_2_n_5\ : STD_LOGIC;
  signal \ctr_reg[0]_i_2_n_6\ : STD_LOGIC;
  signal \ctr_reg[0]_i_2_n_7\ : STD_LOGIC;
  signal \ctr_reg[12]_i_1_n_0\ : STD_LOGIC;
  signal \ctr_reg[12]_i_1_n_4\ : STD_LOGIC;
  signal \ctr_reg[12]_i_1_n_5\ : STD_LOGIC;
  signal \ctr_reg[12]_i_1_n_6\ : STD_LOGIC;
  signal \ctr_reg[12]_i_1_n_7\ : STD_LOGIC;
  signal \ctr_reg[16]_i_1_n_0\ : STD_LOGIC;
  signal \ctr_reg[16]_i_1_n_4\ : STD_LOGIC;
  signal \ctr_reg[16]_i_1_n_5\ : STD_LOGIC;
  signal \ctr_reg[16]_i_1_n_6\ : STD_LOGIC;
  signal \ctr_reg[16]_i_1_n_7\ : STD_LOGIC;
  signal \ctr_reg[20]_i_1_n_0\ : STD_LOGIC;
  signal \ctr_reg[20]_i_1_n_4\ : STD_LOGIC;
  signal \ctr_reg[20]_i_1_n_5\ : STD_LOGIC;
  signal \ctr_reg[20]_i_1_n_6\ : STD_LOGIC;
  signal \ctr_reg[20]_i_1_n_7\ : STD_LOGIC;
  signal \ctr_reg[24]_i_1_n_6\ : STD_LOGIC;
  signal \ctr_reg[24]_i_1_n_7\ : STD_LOGIC;
  signal \ctr_reg[4]_i_1_n_0\ : STD_LOGIC;
  signal \ctr_reg[4]_i_1_n_4\ : STD_LOGIC;
  signal \ctr_reg[4]_i_1_n_5\ : STD_LOGIC;
  signal \ctr_reg[4]_i_1_n_6\ : STD_LOGIC;
  signal \ctr_reg[4]_i_1_n_7\ : STD_LOGIC;
  signal \ctr_reg[8]_i_1_n_0\ : STD_LOGIC;
  signal \ctr_reg[8]_i_1_n_4\ : STD_LOGIC;
  signal \ctr_reg[8]_i_1_n_5\ : STD_LOGIC;
  signal \ctr_reg[8]_i_1_n_6\ : STD_LOGIC;
  signal \ctr_reg[8]_i_1_n_7\ : STD_LOGIC;
  signal \ctr_reg_n_0_[0]\ : STD_LOGIC;
  signal \ctr_reg_n_0_[10]\ : STD_LOGIC;
  signal \ctr_reg_n_0_[11]\ : STD_LOGIC;
  signal \ctr_reg_n_0_[12]\ : STD_LOGIC;
  signal \ctr_reg_n_0_[13]\ : STD_LOGIC;
  signal \ctr_reg_n_0_[14]\ : STD_LOGIC;
  signal \ctr_reg_n_0_[15]\ : STD_LOGIC;
  signal \ctr_reg_n_0_[16]\ : STD_LOGIC;
  signal \ctr_reg_n_0_[17]\ : STD_LOGIC;
  signal \ctr_reg_n_0_[18]\ : STD_LOGIC;
  signal \ctr_reg_n_0_[19]\ : STD_LOGIC;
  signal \ctr_reg_n_0_[1]\ : STD_LOGIC;
  signal \ctr_reg_n_0_[20]\ : STD_LOGIC;
  signal \ctr_reg_n_0_[21]\ : STD_LOGIC;
  signal \ctr_reg_n_0_[22]\ : STD_LOGIC;
  signal \ctr_reg_n_0_[23]\ : STD_LOGIC;
  signal \ctr_reg_n_0_[24]\ : STD_LOGIC;
  signal \ctr_reg_n_0_[2]\ : STD_LOGIC;
  signal \ctr_reg_n_0_[3]\ : STD_LOGIC;
  signal \ctr_reg_n_0_[4]\ : STD_LOGIC;
  signal \ctr_reg_n_0_[5]\ : STD_LOGIC;
  signal \ctr_reg_n_0_[6]\ : STD_LOGIC;
  signal \ctr_reg_n_0_[7]\ : STD_LOGIC;
  signal \ctr_reg_n_0_[8]\ : STD_LOGIC;
  signal \ctr_reg_n_0_[9]\ : STD_LOGIC;
  signal led_blink_OBUF : STD_LOGIC;
  signal rst_n_IBUF : STD_LOGIC;
  signal \rst_n^Mid\ : STD_LOGIC;
  signal \NLW_ctr_reg[0]_i_2_CO_UNCONNECTED\ : STD_LOGIC_VECTOR ( 2 downto 0 );
  signal \NLW_ctr_reg[12]_i_1_CO_UNCONNECTED\ : STD_LOGIC_VECTOR ( 2 downto 0 );
  signal \NLW_ctr_reg[16]_i_1_CO_UNCONNECTED\ : STD_LOGIC_VECTOR ( 2 downto 0 );
  signal \NLW_ctr_reg[20]_i_1_CO_UNCONNECTED\ : STD_LOGIC_VECTOR ( 2 downto 0 );
  signal \NLW_ctr_reg[24]_i_1_CO_UNCONNECTED\ : STD_LOGIC_VECTOR ( 3 downto 0 );
  signal \NLW_ctr_reg[24]_i_1_O_UNCONNECTED\ : STD_LOGIC_VECTOR ( 3 downto 2 );
  signal \NLW_ctr_reg[4]_i_1_CO_UNCONNECTED\ : STD_LOGIC_VECTOR ( 2 downto 0 );
  signal \NLW_ctr_reg[8]_i_1_CO_UNCONNECTED\ : STD_LOGIC_VECTOR ( 2 downto 0 );
  attribute ADDER_THRESHOLD : integer;
  attribute ADDER_THRESHOLD of \ctr_reg[0]_i_2\ : label is 11;
  attribute ADDER_THRESHOLD of \ctr_reg[12]_i_1\ : label is 11;
  attribute ADDER_THRESHOLD of \ctr_reg[16]_i_1\ : label is 11;
  attribute ADDER_THRESHOLD of \ctr_reg[20]_i_1\ : label is 11;
  attribute ADDER_THRESHOLD of \ctr_reg[24]_i_1\ : label is 11;
  attribute ADDER_THRESHOLD of \ctr_reg[4]_i_1\ : label is 11;
  attribute ADDER_THRESHOLD of \ctr_reg[8]_i_1\ : label is 11;
begin
  \rst_n^Mid\ <= rst_n;
\pullup_rst_n^Midinst\: unisim.vcomponents.PULLUP
    port map (
      O => \rst_n^Mid\
    );
clk_IBUF_BUFG_inst: unisim.vcomponents.BUFG
     port map (
      I => clk_IBUF,
      O => clk_IBUF_BUFG
    );
clk_IBUF_inst: unisim.vcomponents.IBUF
     port map (
      I => clk,
      O => clk_IBUF
    );
\ctr[0]_i_1\: unisim.vcomponents.LUT1
    generic map(
      INIT => X"1"
    )
        port map (
      I0 => rst_n_IBUF,
      O => clear
    );
\ctr[0]_i_3\: unisim.vcomponents.LUT1
    generic map(
      INIT => X"1"
    )
        port map (
      I0 => \ctr_reg_n_0_[0]\,
      O => \ctr[0]_i_3_n_0\
    );
\ctr_reg[0]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => clk_IBUF_BUFG,
      CE => '1',
      D => \ctr_reg[0]_i_2_n_7\,
      Q => \ctr_reg_n_0_[0]\,
      R => clear
    );
\ctr_reg[0]_i_2\: unisim.vcomponents.CARRY4
     port map (
      CI => '0',
      CO(3) => \ctr_reg[0]_i_2_n_0\,
      CO(2 downto 0) => \NLW_ctr_reg[0]_i_2_CO_UNCONNECTED\(2 downto 0),
      CYINIT => '0',
      DI(3 downto 0) => B"0001",
      O(3) => \ctr_reg[0]_i_2_n_4\,
      O(2) => \ctr_reg[0]_i_2_n_5\,
      O(1) => \ctr_reg[0]_i_2_n_6\,
      O(0) => \ctr_reg[0]_i_2_n_7\,
      S(3) => \ctr_reg_n_0_[3]\,
      S(2) => \ctr_reg_n_0_[2]\,
      S(1) => \ctr_reg_n_0_[1]\,
      S(0) => \ctr[0]_i_3_n_0\
    );
\ctr_reg[10]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => clk_IBUF_BUFG,
      CE => '1',
      D => \ctr_reg[8]_i_1_n_5\,
      Q => \ctr_reg_n_0_[10]\,
      R => clear
    );
\ctr_reg[11]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => clk_IBUF_BUFG,
      CE => '1',
      D => \ctr_reg[8]_i_1_n_4\,
      Q => \ctr_reg_n_0_[11]\,
      R => clear
    );
\ctr_reg[12]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => clk_IBUF_BUFG,
      CE => '1',
      D => \ctr_reg[12]_i_1_n_7\,
      Q => \ctr_reg_n_0_[12]\,
      R => clear
    );
\ctr_reg[12]_i_1\: unisim.vcomponents.CARRY4
     port map (
      CI => \ctr_reg[8]_i_1_n_0\,
      CO(3) => \ctr_reg[12]_i_1_n_0\,
      CO(2 downto 0) => \NLW_ctr_reg[12]_i_1_CO_UNCONNECTED\(2 downto 0),
      CYINIT => '0',
      DI(3 downto 0) => B"0000",
      O(3) => \ctr_reg[12]_i_1_n_4\,
      O(2) => \ctr_reg[12]_i_1_n_5\,
      O(1) => \ctr_reg[12]_i_1_n_6\,
      O(0) => \ctr_reg[12]_i_1_n_7\,
      S(3) => \ctr_reg_n_0_[15]\,
      S(2) => \ctr_reg_n_0_[14]\,
      S(1) => \ctr_reg_n_0_[13]\,
      S(0) => \ctr_reg_n_0_[12]\
    );
\ctr_reg[13]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => clk_IBUF_BUFG,
      CE => '1',
      D => \ctr_reg[12]_i_1_n_6\,
      Q => \ctr_reg_n_0_[13]\,
      R => clear
    );
\ctr_reg[14]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => clk_IBUF_BUFG,
      CE => '1',
      D => \ctr_reg[12]_i_1_n_5\,
      Q => \ctr_reg_n_0_[14]\,
      R => clear
    );
\ctr_reg[15]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => clk_IBUF_BUFG,
      CE => '1',
      D => \ctr_reg[12]_i_1_n_4\,
      Q => \ctr_reg_n_0_[15]\,
      R => clear
    );
\ctr_reg[16]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => clk_IBUF_BUFG,
      CE => '1',
      D => \ctr_reg[16]_i_1_n_7\,
      Q => \ctr_reg_n_0_[16]\,
      R => clear
    );
\ctr_reg[16]_i_1\: unisim.vcomponents.CARRY4
     port map (
      CI => \ctr_reg[12]_i_1_n_0\,
      CO(3) => \ctr_reg[16]_i_1_n_0\,
      CO(2 downto 0) => \NLW_ctr_reg[16]_i_1_CO_UNCONNECTED\(2 downto 0),
      CYINIT => '0',
      DI(3 downto 0) => B"0000",
      O(3) => \ctr_reg[16]_i_1_n_4\,
      O(2) => \ctr_reg[16]_i_1_n_5\,
      O(1) => \ctr_reg[16]_i_1_n_6\,
      O(0) => \ctr_reg[16]_i_1_n_7\,
      S(3) => \ctr_reg_n_0_[19]\,
      S(2) => \ctr_reg_n_0_[18]\,
      S(1) => \ctr_reg_n_0_[17]\,
      S(0) => \ctr_reg_n_0_[16]\
    );
\ctr_reg[17]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => clk_IBUF_BUFG,
      CE => '1',
      D => \ctr_reg[16]_i_1_n_6\,
      Q => \ctr_reg_n_0_[17]\,
      R => clear
    );
\ctr_reg[18]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => clk_IBUF_BUFG,
      CE => '1',
      D => \ctr_reg[16]_i_1_n_5\,
      Q => \ctr_reg_n_0_[18]\,
      R => clear
    );
\ctr_reg[19]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => clk_IBUF_BUFG,
      CE => '1',
      D => \ctr_reg[16]_i_1_n_4\,
      Q => \ctr_reg_n_0_[19]\,
      R => clear
    );
\ctr_reg[1]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => clk_IBUF_BUFG,
      CE => '1',
      D => \ctr_reg[0]_i_2_n_6\,
      Q => \ctr_reg_n_0_[1]\,
      R => clear
    );
\ctr_reg[20]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => clk_IBUF_BUFG,
      CE => '1',
      D => \ctr_reg[20]_i_1_n_7\,
      Q => \ctr_reg_n_0_[20]\,
      R => clear
    );
\ctr_reg[20]_i_1\: unisim.vcomponents.CARRY4
     port map (
      CI => \ctr_reg[16]_i_1_n_0\,
      CO(3) => \ctr_reg[20]_i_1_n_0\,
      CO(2 downto 0) => \NLW_ctr_reg[20]_i_1_CO_UNCONNECTED\(2 downto 0),
      CYINIT => '0',
      DI(3 downto 0) => B"0000",
      O(3) => \ctr_reg[20]_i_1_n_4\,
      O(2) => \ctr_reg[20]_i_1_n_5\,
      O(1) => \ctr_reg[20]_i_1_n_6\,
      O(0) => \ctr_reg[20]_i_1_n_7\,
      S(3) => \ctr_reg_n_0_[23]\,
      S(2) => \ctr_reg_n_0_[22]\,
      S(1) => \ctr_reg_n_0_[21]\,
      S(0) => \ctr_reg_n_0_[20]\
    );
\ctr_reg[21]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => clk_IBUF_BUFG,
      CE => '1',
      D => \ctr_reg[20]_i_1_n_6\,
      Q => \ctr_reg_n_0_[21]\,
      R => clear
    );
\ctr_reg[22]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => clk_IBUF_BUFG,
      CE => '1',
      D => \ctr_reg[20]_i_1_n_5\,
      Q => \ctr_reg_n_0_[22]\,
      R => clear
    );
\ctr_reg[23]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => clk_IBUF_BUFG,
      CE => '1',
      D => \ctr_reg[20]_i_1_n_4\,
      Q => \ctr_reg_n_0_[23]\,
      R => clear
    );
\ctr_reg[24]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => clk_IBUF_BUFG,
      CE => '1',
      D => \ctr_reg[24]_i_1_n_7\,
      Q => \ctr_reg_n_0_[24]\,
      R => clear
    );
\ctr_reg[24]_i_1\: unisim.vcomponents.CARRY4
     port map (
      CI => \ctr_reg[20]_i_1_n_0\,
      CO(3 downto 0) => \NLW_ctr_reg[24]_i_1_CO_UNCONNECTED\(3 downto 0),
      CYINIT => '0',
      DI(3 downto 0) => B"0000",
      O(3 downto 2) => \NLW_ctr_reg[24]_i_1_O_UNCONNECTED\(3 downto 2),
      O(1) => \ctr_reg[24]_i_1_n_6\,
      O(0) => \ctr_reg[24]_i_1_n_7\,
      S(3 downto 2) => B"00",
      S(1) => led_blink_OBUF,
      S(0) => \ctr_reg_n_0_[24]\
    );
\ctr_reg[25]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => clk_IBUF_BUFG,
      CE => '1',
      D => \ctr_reg[24]_i_1_n_6\,
      Q => led_blink_OBUF,
      R => clear
    );
\ctr_reg[2]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => clk_IBUF_BUFG,
      CE => '1',
      D => \ctr_reg[0]_i_2_n_5\,
      Q => \ctr_reg_n_0_[2]\,
      R => clear
    );
\ctr_reg[3]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => clk_IBUF_BUFG,
      CE => '1',
      D => \ctr_reg[0]_i_2_n_4\,
      Q => \ctr_reg_n_0_[3]\,
      R => clear
    );
\ctr_reg[4]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => clk_IBUF_BUFG,
      CE => '1',
      D => \ctr_reg[4]_i_1_n_7\,
      Q => \ctr_reg_n_0_[4]\,
      R => clear
    );
\ctr_reg[4]_i_1\: unisim.vcomponents.CARRY4
     port map (
      CI => \ctr_reg[0]_i_2_n_0\,
      CO(3) => \ctr_reg[4]_i_1_n_0\,
      CO(2 downto 0) => \NLW_ctr_reg[4]_i_1_CO_UNCONNECTED\(2 downto 0),
      CYINIT => '0',
      DI(3 downto 0) => B"0000",
      O(3) => \ctr_reg[4]_i_1_n_4\,
      O(2) => \ctr_reg[4]_i_1_n_5\,
      O(1) => \ctr_reg[4]_i_1_n_6\,
      O(0) => \ctr_reg[4]_i_1_n_7\,
      S(3) => \ctr_reg_n_0_[7]\,
      S(2) => \ctr_reg_n_0_[6]\,
      S(1) => \ctr_reg_n_0_[5]\,
      S(0) => \ctr_reg_n_0_[4]\
    );
\ctr_reg[5]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => clk_IBUF_BUFG,
      CE => '1',
      D => \ctr_reg[4]_i_1_n_6\,
      Q => \ctr_reg_n_0_[5]\,
      R => clear
    );
\ctr_reg[6]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => clk_IBUF_BUFG,
      CE => '1',
      D => \ctr_reg[4]_i_1_n_5\,
      Q => \ctr_reg_n_0_[6]\,
      R => clear
    );
\ctr_reg[7]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => clk_IBUF_BUFG,
      CE => '1',
      D => \ctr_reg[4]_i_1_n_4\,
      Q => \ctr_reg_n_0_[7]\,
      R => clear
    );
\ctr_reg[8]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => clk_IBUF_BUFG,
      CE => '1',
      D => \ctr_reg[8]_i_1_n_7\,
      Q => \ctr_reg_n_0_[8]\,
      R => clear
    );
\ctr_reg[8]_i_1\: unisim.vcomponents.CARRY4
     port map (
      CI => \ctr_reg[4]_i_1_n_0\,
      CO(3) => \ctr_reg[8]_i_1_n_0\,
      CO(2 downto 0) => \NLW_ctr_reg[8]_i_1_CO_UNCONNECTED\(2 downto 0),
      CYINIT => '0',
      DI(3 downto 0) => B"0000",
      O(3) => \ctr_reg[8]_i_1_n_4\,
      O(2) => \ctr_reg[8]_i_1_n_5\,
      O(1) => \ctr_reg[8]_i_1_n_6\,
      O(0) => \ctr_reg[8]_i_1_n_7\,
      S(3) => \ctr_reg_n_0_[11]\,
      S(2) => \ctr_reg_n_0_[10]\,
      S(1) => \ctr_reg_n_0_[9]\,
      S(0) => \ctr_reg_n_0_[8]\
    );
\ctr_reg[9]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => clk_IBUF_BUFG,
      CE => '1',
      D => \ctr_reg[8]_i_1_n_6\,
      Q => \ctr_reg_n_0_[9]\,
      R => clear
    );
led_blink_OBUF_inst: unisim.vcomponents.OBUF
     port map (
      I => led_blink_OBUF,
      O => led_blink
    );
led_on_OBUF_inst: unisim.vcomponents.OBUF
     port map (
      I => '1',
      O => led_on
    );
rst_n_IBUF_inst: unisim.vcomponents.IBUF
     port map (
      I => \rst_n^Mid\,
      O => rst_n_IBUF
    );
end STRUCTURE;
