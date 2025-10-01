// Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
// Copyright 2022-2024 Advanced Micro Devices, Inc. All Rights Reserved.
// --------------------------------------------------------------------------------
// Tool Version: Vivado v.2024.2 (win64) Build 5239630 Fri Nov 08 22:35:27 MST 2024
// Date        : Wed Oct  1 14:37:09 2025
// Host        : DESKTOP-VAD40IB running 64-bit major release  (build 9200)
// Command     : write_verilog -mode funcsim -file R:/fpga/fpga-power-test-accel/reports/post_impl_netlist.v
// Design      : hello_top
// Purpose     : This verilog netlist is a functional simulation representation of the design and should not be modified
//               or synthesized. This netlist cannot be used for SDF annotated simulation.
// Device      : xc7a35tcpg236-1
// --------------------------------------------------------------------------------
`timescale 1 ps / 1 ps

(* DIV_BIT = "26" *) (* ECO_CHECKSUM = "11e553c" *) 
(* NotValidForBitStream *)
(* \DesignAttr:ENABLE_NOC_NETLIST_VIEW  *) 
(* \DesignAttr:ENABLE_AIE_NETLIST_VIEW  *) 
module hello_top
   (clk,
    rst_n,
    led_on,
    led_blink);
  input clk;
  input rst_n;
  output led_on;
  output led_blink;

  wire clear;
  wire clk;
  wire clk_IBUF;
  wire clk_IBUF_BUFG;
  wire \ctr[0]_i_3_n_0 ;
  wire \ctr_reg[0]_i_2_n_0 ;
  wire \ctr_reg[0]_i_2_n_4 ;
  wire \ctr_reg[0]_i_2_n_5 ;
  wire \ctr_reg[0]_i_2_n_6 ;
  wire \ctr_reg[0]_i_2_n_7 ;
  wire \ctr_reg[12]_i_1_n_0 ;
  wire \ctr_reg[12]_i_1_n_4 ;
  wire \ctr_reg[12]_i_1_n_5 ;
  wire \ctr_reg[12]_i_1_n_6 ;
  wire \ctr_reg[12]_i_1_n_7 ;
  wire \ctr_reg[16]_i_1_n_0 ;
  wire \ctr_reg[16]_i_1_n_4 ;
  wire \ctr_reg[16]_i_1_n_5 ;
  wire \ctr_reg[16]_i_1_n_6 ;
  wire \ctr_reg[16]_i_1_n_7 ;
  wire \ctr_reg[20]_i_1_n_0 ;
  wire \ctr_reg[20]_i_1_n_4 ;
  wire \ctr_reg[20]_i_1_n_5 ;
  wire \ctr_reg[20]_i_1_n_6 ;
  wire \ctr_reg[20]_i_1_n_7 ;
  wire \ctr_reg[24]_i_1_n_6 ;
  wire \ctr_reg[24]_i_1_n_7 ;
  wire \ctr_reg[4]_i_1_n_0 ;
  wire \ctr_reg[4]_i_1_n_4 ;
  wire \ctr_reg[4]_i_1_n_5 ;
  wire \ctr_reg[4]_i_1_n_6 ;
  wire \ctr_reg[4]_i_1_n_7 ;
  wire \ctr_reg[8]_i_1_n_0 ;
  wire \ctr_reg[8]_i_1_n_4 ;
  wire \ctr_reg[8]_i_1_n_5 ;
  wire \ctr_reg[8]_i_1_n_6 ;
  wire \ctr_reg[8]_i_1_n_7 ;
  wire \ctr_reg_n_0_[0] ;
  wire \ctr_reg_n_0_[10] ;
  wire \ctr_reg_n_0_[11] ;
  wire \ctr_reg_n_0_[12] ;
  wire \ctr_reg_n_0_[13] ;
  wire \ctr_reg_n_0_[14] ;
  wire \ctr_reg_n_0_[15] ;
  wire \ctr_reg_n_0_[16] ;
  wire \ctr_reg_n_0_[17] ;
  wire \ctr_reg_n_0_[18] ;
  wire \ctr_reg_n_0_[19] ;
  wire \ctr_reg_n_0_[1] ;
  wire \ctr_reg_n_0_[20] ;
  wire \ctr_reg_n_0_[21] ;
  wire \ctr_reg_n_0_[22] ;
  wire \ctr_reg_n_0_[23] ;
  wire \ctr_reg_n_0_[24] ;
  wire \ctr_reg_n_0_[2] ;
  wire \ctr_reg_n_0_[3] ;
  wire \ctr_reg_n_0_[4] ;
  wire \ctr_reg_n_0_[5] ;
  wire \ctr_reg_n_0_[6] ;
  wire \ctr_reg_n_0_[7] ;
  wire \ctr_reg_n_0_[8] ;
  wire \ctr_reg_n_0_[9] ;
  wire led_blink;
  wire led_blink_OBUF;
  wire led_on;
  wire rst_n;
  wire rst_n_IBUF;
  wire [2:0]\NLW_ctr_reg[0]_i_2_CO_UNCONNECTED ;
  wire [2:0]\NLW_ctr_reg[12]_i_1_CO_UNCONNECTED ;
  wire [2:0]\NLW_ctr_reg[16]_i_1_CO_UNCONNECTED ;
  wire [2:0]\NLW_ctr_reg[20]_i_1_CO_UNCONNECTED ;
  wire [3:0]\NLW_ctr_reg[24]_i_1_CO_UNCONNECTED ;
  wire [3:2]\NLW_ctr_reg[24]_i_1_O_UNCONNECTED ;
  wire [2:0]\NLW_ctr_reg[4]_i_1_CO_UNCONNECTED ;
  wire [2:0]\NLW_ctr_reg[8]_i_1_CO_UNCONNECTED ;
PULLUP pullup_rst_n
       (.O(rst_n));

  BUFG clk_IBUF_BUFG_inst
       (.I(clk_IBUF),
        .O(clk_IBUF_BUFG));
  IBUF clk_IBUF_inst
       (.I(clk),
        .O(clk_IBUF));
  LUT1 #(
    .INIT(2'h1)) 
    \ctr[0]_i_1 
       (.I0(rst_n_IBUF),
        .O(clear));
  LUT1 #(
    .INIT(2'h1)) 
    \ctr[0]_i_3 
       (.I0(\ctr_reg_n_0_[0] ),
        .O(\ctr[0]_i_3_n_0 ));
  FDRE #(
    .INIT(1'b0)) 
    \ctr_reg[0] 
       (.C(clk_IBUF_BUFG),
        .CE(1'b1),
        .D(\ctr_reg[0]_i_2_n_7 ),
        .Q(\ctr_reg_n_0_[0] ),
        .R(clear));
  (* ADDER_THRESHOLD = "11" *) 
  CARRY4 \ctr_reg[0]_i_2 
       (.CI(1'b0),
        .CO({\ctr_reg[0]_i_2_n_0 ,\NLW_ctr_reg[0]_i_2_CO_UNCONNECTED [2:0]}),
        .CYINIT(1'b0),
        .DI({1'b0,1'b0,1'b0,1'b1}),
        .O({\ctr_reg[0]_i_2_n_4 ,\ctr_reg[0]_i_2_n_5 ,\ctr_reg[0]_i_2_n_6 ,\ctr_reg[0]_i_2_n_7 }),
        .S({\ctr_reg_n_0_[3] ,\ctr_reg_n_0_[2] ,\ctr_reg_n_0_[1] ,\ctr[0]_i_3_n_0 }));
  FDRE #(
    .INIT(1'b0)) 
    \ctr_reg[10] 
       (.C(clk_IBUF_BUFG),
        .CE(1'b1),
        .D(\ctr_reg[8]_i_1_n_5 ),
        .Q(\ctr_reg_n_0_[10] ),
        .R(clear));
  FDRE #(
    .INIT(1'b0)) 
    \ctr_reg[11] 
       (.C(clk_IBUF_BUFG),
        .CE(1'b1),
        .D(\ctr_reg[8]_i_1_n_4 ),
        .Q(\ctr_reg_n_0_[11] ),
        .R(clear));
  FDRE #(
    .INIT(1'b0)) 
    \ctr_reg[12] 
       (.C(clk_IBUF_BUFG),
        .CE(1'b1),
        .D(\ctr_reg[12]_i_1_n_7 ),
        .Q(\ctr_reg_n_0_[12] ),
        .R(clear));
  (* ADDER_THRESHOLD = "11" *) 
  CARRY4 \ctr_reg[12]_i_1 
       (.CI(\ctr_reg[8]_i_1_n_0 ),
        .CO({\ctr_reg[12]_i_1_n_0 ,\NLW_ctr_reg[12]_i_1_CO_UNCONNECTED [2:0]}),
        .CYINIT(1'b0),
        .DI({1'b0,1'b0,1'b0,1'b0}),
        .O({\ctr_reg[12]_i_1_n_4 ,\ctr_reg[12]_i_1_n_5 ,\ctr_reg[12]_i_1_n_6 ,\ctr_reg[12]_i_1_n_7 }),
        .S({\ctr_reg_n_0_[15] ,\ctr_reg_n_0_[14] ,\ctr_reg_n_0_[13] ,\ctr_reg_n_0_[12] }));
  FDRE #(
    .INIT(1'b0)) 
    \ctr_reg[13] 
       (.C(clk_IBUF_BUFG),
        .CE(1'b1),
        .D(\ctr_reg[12]_i_1_n_6 ),
        .Q(\ctr_reg_n_0_[13] ),
        .R(clear));
  FDRE #(
    .INIT(1'b0)) 
    \ctr_reg[14] 
       (.C(clk_IBUF_BUFG),
        .CE(1'b1),
        .D(\ctr_reg[12]_i_1_n_5 ),
        .Q(\ctr_reg_n_0_[14] ),
        .R(clear));
  FDRE #(
    .INIT(1'b0)) 
    \ctr_reg[15] 
       (.C(clk_IBUF_BUFG),
        .CE(1'b1),
        .D(\ctr_reg[12]_i_1_n_4 ),
        .Q(\ctr_reg_n_0_[15] ),
        .R(clear));
  FDRE #(
    .INIT(1'b0)) 
    \ctr_reg[16] 
       (.C(clk_IBUF_BUFG),
        .CE(1'b1),
        .D(\ctr_reg[16]_i_1_n_7 ),
        .Q(\ctr_reg_n_0_[16] ),
        .R(clear));
  (* ADDER_THRESHOLD = "11" *) 
  CARRY4 \ctr_reg[16]_i_1 
       (.CI(\ctr_reg[12]_i_1_n_0 ),
        .CO({\ctr_reg[16]_i_1_n_0 ,\NLW_ctr_reg[16]_i_1_CO_UNCONNECTED [2:0]}),
        .CYINIT(1'b0),
        .DI({1'b0,1'b0,1'b0,1'b0}),
        .O({\ctr_reg[16]_i_1_n_4 ,\ctr_reg[16]_i_1_n_5 ,\ctr_reg[16]_i_1_n_6 ,\ctr_reg[16]_i_1_n_7 }),
        .S({\ctr_reg_n_0_[19] ,\ctr_reg_n_0_[18] ,\ctr_reg_n_0_[17] ,\ctr_reg_n_0_[16] }));
  FDRE #(
    .INIT(1'b0)) 
    \ctr_reg[17] 
       (.C(clk_IBUF_BUFG),
        .CE(1'b1),
        .D(\ctr_reg[16]_i_1_n_6 ),
        .Q(\ctr_reg_n_0_[17] ),
        .R(clear));
  FDRE #(
    .INIT(1'b0)) 
    \ctr_reg[18] 
       (.C(clk_IBUF_BUFG),
        .CE(1'b1),
        .D(\ctr_reg[16]_i_1_n_5 ),
        .Q(\ctr_reg_n_0_[18] ),
        .R(clear));
  FDRE #(
    .INIT(1'b0)) 
    \ctr_reg[19] 
       (.C(clk_IBUF_BUFG),
        .CE(1'b1),
        .D(\ctr_reg[16]_i_1_n_4 ),
        .Q(\ctr_reg_n_0_[19] ),
        .R(clear));
  FDRE #(
    .INIT(1'b0)) 
    \ctr_reg[1] 
       (.C(clk_IBUF_BUFG),
        .CE(1'b1),
        .D(\ctr_reg[0]_i_2_n_6 ),
        .Q(\ctr_reg_n_0_[1] ),
        .R(clear));
  FDRE #(
    .INIT(1'b0)) 
    \ctr_reg[20] 
       (.C(clk_IBUF_BUFG),
        .CE(1'b1),
        .D(\ctr_reg[20]_i_1_n_7 ),
        .Q(\ctr_reg_n_0_[20] ),
        .R(clear));
  (* ADDER_THRESHOLD = "11" *) 
  CARRY4 \ctr_reg[20]_i_1 
       (.CI(\ctr_reg[16]_i_1_n_0 ),
        .CO({\ctr_reg[20]_i_1_n_0 ,\NLW_ctr_reg[20]_i_1_CO_UNCONNECTED [2:0]}),
        .CYINIT(1'b0),
        .DI({1'b0,1'b0,1'b0,1'b0}),
        .O({\ctr_reg[20]_i_1_n_4 ,\ctr_reg[20]_i_1_n_5 ,\ctr_reg[20]_i_1_n_6 ,\ctr_reg[20]_i_1_n_7 }),
        .S({\ctr_reg_n_0_[23] ,\ctr_reg_n_0_[22] ,\ctr_reg_n_0_[21] ,\ctr_reg_n_0_[20] }));
  FDRE #(
    .INIT(1'b0)) 
    \ctr_reg[21] 
       (.C(clk_IBUF_BUFG),
        .CE(1'b1),
        .D(\ctr_reg[20]_i_1_n_6 ),
        .Q(\ctr_reg_n_0_[21] ),
        .R(clear));
  FDRE #(
    .INIT(1'b0)) 
    \ctr_reg[22] 
       (.C(clk_IBUF_BUFG),
        .CE(1'b1),
        .D(\ctr_reg[20]_i_1_n_5 ),
        .Q(\ctr_reg_n_0_[22] ),
        .R(clear));
  FDRE #(
    .INIT(1'b0)) 
    \ctr_reg[23] 
       (.C(clk_IBUF_BUFG),
        .CE(1'b1),
        .D(\ctr_reg[20]_i_1_n_4 ),
        .Q(\ctr_reg_n_0_[23] ),
        .R(clear));
  FDRE #(
    .INIT(1'b0)) 
    \ctr_reg[24] 
       (.C(clk_IBUF_BUFG),
        .CE(1'b1),
        .D(\ctr_reg[24]_i_1_n_7 ),
        .Q(\ctr_reg_n_0_[24] ),
        .R(clear));
  (* ADDER_THRESHOLD = "11" *) 
  CARRY4 \ctr_reg[24]_i_1 
       (.CI(\ctr_reg[20]_i_1_n_0 ),
        .CO(\NLW_ctr_reg[24]_i_1_CO_UNCONNECTED [3:0]),
        .CYINIT(1'b0),
        .DI({1'b0,1'b0,1'b0,1'b0}),
        .O({\NLW_ctr_reg[24]_i_1_O_UNCONNECTED [3:2],\ctr_reg[24]_i_1_n_6 ,\ctr_reg[24]_i_1_n_7 }),
        .S({1'b0,1'b0,led_blink_OBUF,\ctr_reg_n_0_[24] }));
  FDRE #(
    .INIT(1'b0)) 
    \ctr_reg[25] 
       (.C(clk_IBUF_BUFG),
        .CE(1'b1),
        .D(\ctr_reg[24]_i_1_n_6 ),
        .Q(led_blink_OBUF),
        .R(clear));
  FDRE #(
    .INIT(1'b0)) 
    \ctr_reg[2] 
       (.C(clk_IBUF_BUFG),
        .CE(1'b1),
        .D(\ctr_reg[0]_i_2_n_5 ),
        .Q(\ctr_reg_n_0_[2] ),
        .R(clear));
  FDRE #(
    .INIT(1'b0)) 
    \ctr_reg[3] 
       (.C(clk_IBUF_BUFG),
        .CE(1'b1),
        .D(\ctr_reg[0]_i_2_n_4 ),
        .Q(\ctr_reg_n_0_[3] ),
        .R(clear));
  FDRE #(
    .INIT(1'b0)) 
    \ctr_reg[4] 
       (.C(clk_IBUF_BUFG),
        .CE(1'b1),
        .D(\ctr_reg[4]_i_1_n_7 ),
        .Q(\ctr_reg_n_0_[4] ),
        .R(clear));
  (* ADDER_THRESHOLD = "11" *) 
  CARRY4 \ctr_reg[4]_i_1 
       (.CI(\ctr_reg[0]_i_2_n_0 ),
        .CO({\ctr_reg[4]_i_1_n_0 ,\NLW_ctr_reg[4]_i_1_CO_UNCONNECTED [2:0]}),
        .CYINIT(1'b0),
        .DI({1'b0,1'b0,1'b0,1'b0}),
        .O({\ctr_reg[4]_i_1_n_4 ,\ctr_reg[4]_i_1_n_5 ,\ctr_reg[4]_i_1_n_6 ,\ctr_reg[4]_i_1_n_7 }),
        .S({\ctr_reg_n_0_[7] ,\ctr_reg_n_0_[6] ,\ctr_reg_n_0_[5] ,\ctr_reg_n_0_[4] }));
  FDRE #(
    .INIT(1'b0)) 
    \ctr_reg[5] 
       (.C(clk_IBUF_BUFG),
        .CE(1'b1),
        .D(\ctr_reg[4]_i_1_n_6 ),
        .Q(\ctr_reg_n_0_[5] ),
        .R(clear));
  FDRE #(
    .INIT(1'b0)) 
    \ctr_reg[6] 
       (.C(clk_IBUF_BUFG),
        .CE(1'b1),
        .D(\ctr_reg[4]_i_1_n_5 ),
        .Q(\ctr_reg_n_0_[6] ),
        .R(clear));
  FDRE #(
    .INIT(1'b0)) 
    \ctr_reg[7] 
       (.C(clk_IBUF_BUFG),
        .CE(1'b1),
        .D(\ctr_reg[4]_i_1_n_4 ),
        .Q(\ctr_reg_n_0_[7] ),
        .R(clear));
  FDRE #(
    .INIT(1'b0)) 
    \ctr_reg[8] 
       (.C(clk_IBUF_BUFG),
        .CE(1'b1),
        .D(\ctr_reg[8]_i_1_n_7 ),
        .Q(\ctr_reg_n_0_[8] ),
        .R(clear));
  (* ADDER_THRESHOLD = "11" *) 
  CARRY4 \ctr_reg[8]_i_1 
       (.CI(\ctr_reg[4]_i_1_n_0 ),
        .CO({\ctr_reg[8]_i_1_n_0 ,\NLW_ctr_reg[8]_i_1_CO_UNCONNECTED [2:0]}),
        .CYINIT(1'b0),
        .DI({1'b0,1'b0,1'b0,1'b0}),
        .O({\ctr_reg[8]_i_1_n_4 ,\ctr_reg[8]_i_1_n_5 ,\ctr_reg[8]_i_1_n_6 ,\ctr_reg[8]_i_1_n_7 }),
        .S({\ctr_reg_n_0_[11] ,\ctr_reg_n_0_[10] ,\ctr_reg_n_0_[9] ,\ctr_reg_n_0_[8] }));
  FDRE #(
    .INIT(1'b0)) 
    \ctr_reg[9] 
       (.C(clk_IBUF_BUFG),
        .CE(1'b1),
        .D(\ctr_reg[8]_i_1_n_6 ),
        .Q(\ctr_reg_n_0_[9] ),
        .R(clear));
  OBUF led_blink_OBUF_inst
       (.I(led_blink_OBUF),
        .O(led_blink));
  OBUF led_on_OBUF_inst
       (.I(1'b1),
        .O(led_on));
  IBUF rst_n_IBUF_inst
       (.I(rst_n),
        .O(rst_n_IBUF));
endmodule
`ifndef GLBL
`define GLBL
`timescale  1 ps / 1 ps

module glbl ();

    parameter ROC_WIDTH = 100000;
    parameter TOC_WIDTH = 0;
    parameter GRES_WIDTH = 10000;
    parameter GRES_START = 10000;

//--------   STARTUP Globals --------------
    wire GSR;
    wire GTS;
    wire GWE;
    wire PRLD;
    wire GRESTORE;
    tri1 p_up_tmp;
    tri (weak1, strong0) PLL_LOCKG = p_up_tmp;

    wire PROGB_GLBL;
    wire CCLKO_GLBL;
    wire FCSBO_GLBL;
    wire [3:0] DO_GLBL;
    wire [3:0] DI_GLBL;
   
    reg GSR_int;
    reg GTS_int;
    reg PRLD_int;
    reg GRESTORE_int;

//--------   JTAG Globals --------------
    wire JTAG_TDO_GLBL;
    wire JTAG_TCK_GLBL;
    wire JTAG_TDI_GLBL;
    wire JTAG_TMS_GLBL;
    wire JTAG_TRST_GLBL;

    reg JTAG_CAPTURE_GLBL;
    reg JTAG_RESET_GLBL;
    reg JTAG_SHIFT_GLBL;
    reg JTAG_UPDATE_GLBL;
    reg JTAG_RUNTEST_GLBL;

    reg JTAG_SEL1_GLBL = 0;
    reg JTAG_SEL2_GLBL = 0 ;
    reg JTAG_SEL3_GLBL = 0;
    reg JTAG_SEL4_GLBL = 0;

    reg JTAG_USER_TDO1_GLBL = 1'bz;
    reg JTAG_USER_TDO2_GLBL = 1'bz;
    reg JTAG_USER_TDO3_GLBL = 1'bz;
    reg JTAG_USER_TDO4_GLBL = 1'bz;

    assign (strong1, weak0) GSR = GSR_int;
    assign (strong1, weak0) GTS = GTS_int;
    assign (weak1, weak0) PRLD = PRLD_int;
    assign (strong1, weak0) GRESTORE = GRESTORE_int;

    initial begin
	GSR_int = 1'b1;
	PRLD_int = 1'b1;
	#(ROC_WIDTH)
	GSR_int = 1'b0;
	PRLD_int = 1'b0;
    end

    initial begin
	GTS_int = 1'b1;
	#(TOC_WIDTH)
	GTS_int = 1'b0;
    end

    initial begin 
	GRESTORE_int = 1'b0;
	#(GRES_START);
	GRESTORE_int = 1'b1;
	#(GRES_WIDTH);
	GRESTORE_int = 1'b0;
    end

endmodule
`endif
