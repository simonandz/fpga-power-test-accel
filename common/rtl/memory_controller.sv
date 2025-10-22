`timescale 1ns / 1ps

//==============================================================================
// Module: memory_controller
// Description: Unified memory controller with BRAM banking and power management
//              Manages 19 BRAM banks with ping-pong buffering
//==============================================================================

import accel_pkg::*;

module memory_controller (
    input  logic                        clk,
    input  logic                        rst_n,

    // Memory interface from compute units
    input  mem_req_t                    req,
    output mem_resp_t                   resp,

    // Power management
    input  logic [BRAM_BANKS-1:0]       bank_power_en,  // Power down unused banks

    // BRAM interfaces (one per bank)
    output logic [BRAM_BANKS-1:0]       bram_en,
    output logic [BRAM_BANKS-1:0]       bram_we,
    output logic [BRAM_ADDR_WIDTH-1:0]  bram_addr   [BRAM_BANKS-1:0],
    output logic [DATA_WIDTH-1:0]       bram_din    [BRAM_BANKS-1:0],
    input  logic [DATA_WIDTH-1:0]       bram_dout   [BRAM_BANKS-1:0]
);

    //--------------------------------------------------------------------------
    // Internal Signals
    //--------------------------------------------------------------------------
    logic [4:0]                     selected_bank;
    logic [BRAM_ADDR_WIDTH-1:0]     selected_addr;
    logic [DATA_WIDTH-1:0]          read_data;
    logic                           read_valid_q;

    // Pipeline stage for read data
    logic [4:0]                     bank_sel_q;
    logic                           re_q;

    //--------------------------------------------------------------------------
    // Address Decoding
    //--------------------------------------------------------------------------
    // Top bits select bank, bottom bits are offset within bank
    assign selected_bank = req.bank_sel;
    assign selected_addr = req.addr[BRAM_ADDR_WIDTH-1:0];

    //--------------------------------------------------------------------------
    // BRAM Control Logic
    //--------------------------------------------------------------------------
    // Use generate with continuous assignments for Icarus Verilog compatibility
    genvar i;
    generate
        for (i = 0; i < BRAM_BANKS; i = i + 1) begin : gen_bram_control
            logic bank_selected;
            assign bank_selected = (selected_bank == i) && bank_power_en[i];

            assign bram_en[i]   = bank_selected && (req.we | req.re);
            assign bram_we[i]   = bank_selected && req.we;
            assign bram_addr[i] = bank_selected ? selected_addr : '0;
            assign bram_din[i]  = bank_selected ? req.data : '0;
        end
    endgenerate

    //--------------------------------------------------------------------------
    // Read Pipeline (1 cycle latency for BRAM)
    //--------------------------------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            bank_sel_q    <= '0;
            re_q          <= 1'b0;
            read_valid_q  <= 1'b0;
        end else begin
            bank_sel_q    <= selected_bank;
            re_q          <= req.re;
            read_valid_q  <= re_q;
        end
    end

    // Multiplex read data from selected bank
    // Use explicit case statement for better Icarus Verilog compatibility
    always_comb begin
        case (bank_sel_q)
            5'd0:  read_data = bram_dout[0];
            5'd1:  read_data = bram_dout[1];
            5'd2:  read_data = bram_dout[2];
            5'd3:  read_data = bram_dout[3];
            5'd4:  read_data = bram_dout[4];
            5'd5:  read_data = bram_dout[5];
            5'd6:  read_data = bram_dout[6];
            5'd7:  read_data = bram_dout[7];
            5'd8:  read_data = bram_dout[8];
            5'd9:  read_data = bram_dout[9];
            5'd10: read_data = bram_dout[10];
            5'd11: read_data = bram_dout[11];
            5'd12: read_data = bram_dout[12];
            5'd13: read_data = bram_dout[13];
            5'd14: read_data = bram_dout[14];
            5'd15: read_data = bram_dout[15];
            5'd16: read_data = bram_dout[16];
            5'd17: read_data = bram_dout[17];
            5'd18: read_data = bram_dout[18];
            default: read_data = 8'h00;
        endcase
    end

    //--------------------------------------------------------------------------
    // Response
    //--------------------------------------------------------------------------
    assign resp.data  = read_data;
    assign resp.valid = read_valid_q;
    assign resp.ready = 1'b1;  // Always ready (no backpressure)

    //--------------------------------------------------------------------------
    // Assertions
    //--------------------------------------------------------------------------
    `ifdef SIMULATION
    always_ff @(posedge clk) begin
        if (rst_n) begin
            // Check for bank overflow
            assert (selected_bank < BRAM_BANKS)
                else $error("Bank select %0d exceeds available banks", selected_bank);

            // Check for address overflow
            assert (selected_addr < BRAM_DEPTH)
                else $error("Address %0h exceeds BRAM depth", selected_addr);

            // Warn if accessing powered-down bank
            if ((req.we | req.re) && !bank_power_en[selected_bank])
                $warning("Accessing powered-down bank %0d", selected_bank);
        end
    end
    `endif

endmodule
