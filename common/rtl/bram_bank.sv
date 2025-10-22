`timescale 1ns / 1ps

//==============================================================================
// Module: bram_bank
// Description: Single BRAM bank (18Kb block)
//              Configured for 2048 x 8-bit
//==============================================================================

module bram_bank #(
    parameter DATA_WIDTH = 8,
    parameter ADDR_WIDTH = 11,
    parameter DEPTH      = 2048
) (
    input  logic                    clk,
    input  logic                    en,
    input  logic                    we,
    input  logic [ADDR_WIDTH-1:0]   addr,
    input  logic [DATA_WIDTH-1:0]   din,
    output logic [DATA_WIDTH-1:0]   dout
);

    // BRAM storage
    (* ram_style = "block" *) logic [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    // Initialize memory for simulation
    integer j;
    initial begin
        for (j = 0; j < DEPTH; j = j + 1) begin
            mem[j] = 8'h00;
        end
    end

    // Registered output with write-first behavior
    // Note: dout initialized to 'X' by SystemVerilog, will be set on first read
    always_ff @(posedge clk) begin
        if (en) begin
            if (we) begin
                mem[addr] <= din;
                dout <= din;  // Write-first: output the written data
            end else begin
                dout <= mem[addr];
            end
        end
    end

endmodule
