// MLP Memory Subsystem
// Manages all BRAM blocks for MLP accelerator
// - Input BRAM (4K x 8-bit)
// - Weight BRAM (16K x 8-bit)
// - Bias BRAM (256 x 8-bit)
// - Output BRAM (4K x 8-bit)

`timescale 1ns / 1ps

module mlp_memory_subsystem (
    input  logic         clk,
    input  logic         rst_n,

    // Host write interface (for loading data)
    input  logic [15:0]  input_addr,
    input  logic [7:0]   input_data,
    input  logic         input_we,

    input  logic [15:0]  weight_addr,
    input  logic [7:0]   weight_data,
    input  logic         weight_we,

    input  logic [15:0]  bias_addr,
    input  logic [7:0]   bias_data,
    input  logic         bias_we,

    // Compute read interface (for accelerator access)
    input  logic [15:0]  input_rd_addr,
    output logic [7:0]   input_rd_data,

    input  logic [15:0]  weight_rd_addr,
    output logic [7:0]   weight_rd_data,

    input  logic [7:0]   bias_rd_addr,
    output logic [7:0]   bias_rd_data,

    // Output write interface (from compute)
    input  logic [15:0]  output_wr_addr,
    input  logic [7:0]   output_wr_data,
    input  logic         output_wr_en,

    // Output read interface (to host)
    input  logic [15:0]  output_rd_addr,
    output logic [7:0]   output_rd_data
);

    // BRAM arrays
    logic [7:0] input_bram[0:4095];    // 4K inputs
    logic [7:0] weight_bram[0:16383];  // 16K weights
    logic [7:0] bias_bram[0:255];      // 256 biases
    logic [7:0] output_bram[0:4095];   // 4K outputs

    // Input BRAM - Dual port (write from host, read from compute)
    always_ff @(posedge clk) begin
        if (input_we) begin
            input_bram[input_addr[11:0]] <= input_data;
        end
        input_rd_data <= input_bram[input_rd_addr[11:0]];
    end

    // Weight BRAM - Dual port (write from host, read from compute)
    always_ff @(posedge clk) begin
        if (weight_we) begin
            weight_bram[weight_addr[13:0]] <= weight_data;
        end
        weight_rd_data <= weight_bram[weight_rd_addr[13:0]];
    end

    // Bias BRAM - Dual port (write from host, read from compute)
    always_ff @(posedge clk) begin
        if (bias_we) begin
            bias_bram[bias_addr[7:0]] <= bias_data;
        end
        bias_rd_data <= bias_bram[bias_rd_addr[7:0]];
    end

    // Output BRAM - Dual port (write from compute, read from host)
    always_ff @(posedge clk) begin
        if (output_wr_en) begin
            output_bram[output_wr_addr[11:0]] <= output_wr_data;
        end
        output_rd_data <= output_bram[output_rd_addr[11:0]];
    end

endmodule
