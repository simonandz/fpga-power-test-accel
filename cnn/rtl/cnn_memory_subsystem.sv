// CNN Memory Subsystem
// Manages all memory blocks for CNN convolution accelerator
// - Input Feature Map BRAM (IMG_W*IMG_H x 8-bit)
// - Kernel Weight Registers (9 x 8-bit, 3x3 kernel)
// - Bias Register (1 x 8-bit, single output channel)
// - Output Feature Map BRAM (IMG_W*IMG_H x 8-bit)

`timescale 1ns / 1ps

(* DONT_TOUCH = "TRUE" *)
module cnn_memory_subsystem #(
    parameter IMG_W     = 16,
    parameter IMG_H     = 16,
    parameter KER_SIZE  = 3,
    parameter IMG_DEPTH = IMG_W * IMG_H,          // 256 for 16x16
    parameter KER_DEPTH = KER_SIZE * KER_SIZE     // 9
)(
    input  logic         clk,
    input  logic         rst_n,

    // Host write interface (for loading data before inference)
    input  logic [15:0]  ifmap_addr,
    input  logic [7:0]   ifmap_data,
    input  logic         ifmap_we,

    input  logic [3:0]   kernel_addr,
    input  logic [7:0]   kernel_data,
    input  logic         kernel_we,

    input  logic [7:0]   bias_data,
    input  logic         bias_we,

    // Compute read interface (for CNN datapath)
    input  logic [15:0]  ifmap_rd_addr,
    output logic [7:0]   ifmap_rd_data,

    input  logic [3:0]   kernel_rd_addr,
    output logic [7:0]   kernel_rd_data,

    output logic [7:0]   bias_rd_data,

    // Output write interface (from compute pipeline)
    input  logic [15:0]  ofmap_wr_addr,
    input  logic [7:0]   ofmap_wr_data,
    input  logic         ofmap_we,

    // Output read interface (host readback)
    input  logic [15:0]  ofmap_rd_addr,
    output logic [7:0]   ofmap_rd_data
);

    // =========================================================================
    // Input Feature Map BRAM
    // =========================================================================
    (* ram_style = "block" *)
    logic [7:0] ifmap_bram [0:IMG_DEPTH-1];

    // =========================================================================
    // Kernel Weight Registers (too small for block RAM)
    // =========================================================================
    (* ram_style = "distributed" *)
    logic [7:0] kernel_regs [0:KER_DEPTH-1];

    // =========================================================================
    // Bias Register (single value for single output channel)
    // =========================================================================
    logic [7:0] bias_reg;

    // =========================================================================
    // Output Feature Map BRAM
    // =========================================================================
    (* ram_style = "block" *)
    logic [7:0] ofmap_bram [0:IMG_DEPTH-1];

    // =========================================================================
    // Simulation Initialization
    // =========================================================================
    initial begin
        for (int i = 0; i < IMG_DEPTH; i++) ifmap_bram[i] = 8'h00;
        for (int i = 0; i < KER_DEPTH; i++) kernel_regs[i] = 8'h00;
        bias_reg = 8'h00;
        for (int i = 0; i < IMG_DEPTH; i++) ofmap_bram[i] = 8'h00;

        `ifndef SYNTHESIS
            if ($test$plusargs("LOAD_MEM")) begin
                $readmemh("cnn/data/ifmap_data.mem", ifmap_bram);
                $readmemh("cnn/data/kernel_data.mem", kernel_regs);
                $display("[CNN BRAM] Loaded memory initialization files");
            end
        `endif
    end

    // =========================================================================
    // Input Feature Map BRAM - Dual port (host write, compute read)
    // Read-first mode
    // =========================================================================
    always_ff @(posedge clk) begin
        ifmap_rd_data <= ifmap_bram[ifmap_rd_addr[$clog2(IMG_DEPTH)-1:0]];

        if (ifmap_we) begin
            ifmap_bram[ifmap_addr[$clog2(IMG_DEPTH)-1:0]] <= ifmap_data;
        end
    end

    // =========================================================================
    // Kernel Weight Registers - Dual port (host write, compute read)
    // =========================================================================
    always_ff @(posedge clk) begin
        kernel_rd_data <= kernel_regs[kernel_rd_addr[3:0]];

        if (kernel_we) begin
            kernel_regs[kernel_addr[3:0]] <= kernel_data;
        end
    end

    // =========================================================================
    // Bias Register
    // =========================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            bias_reg <= 8'h00;
        end else if (bias_we) begin
            bias_reg <= bias_data;
        end
    end

    assign bias_rd_data = bias_reg;

    // =========================================================================
    // Output Feature Map BRAM - Dual port (compute write, host read)
    // Read-first mode
    // =========================================================================
    always_ff @(posedge clk) begin
        ofmap_rd_data <= ofmap_bram[ofmap_rd_addr[$clog2(IMG_DEPTH)-1:0]];

        if (ofmap_we) begin
            ofmap_bram[ofmap_wr_addr[$clog2(IMG_DEPTH)-1:0]] <= ofmap_wr_data;
        end
    end

endmodule
