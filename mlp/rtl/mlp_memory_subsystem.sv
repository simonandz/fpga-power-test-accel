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

    // BRAM arrays (read-first mode for predictable read-during-write behavior)
    // Synthesis attribute for FPGA tools (ignored by simulators)
    /* synthesis ram_style = "block" */ logic [7:0] input_bram[0:4095];    // 4K inputs
    /* synthesis ram_style = "block" */ logic [7:0] weight_bram[0:16383];  // 16K weights
    /* synthesis ram_style = "block" */ logic [7:0] bias_bram[0:255];      // 256 biases
    /* synthesis ram_style = "block" */ logic [7:0] output_bram[0:4095];   // 4K outputs

    // Initialize BRAMs to zero for simulation (avoid 'x' propagation)
    initial begin
        for (int i = 0; i < 4096; i++) input_bram[i] = 8'h00;
        for (int i = 0; i < 16384; i++) weight_bram[i] = 8'h00;
        for (int i = 0; i < 256; i++) bias_bram[i] = 8'h00;
        for (int i = 0; i < 4096; i++) output_bram[i] = 8'h00;
    end

    // Input BRAM - Dual port (write from host, read from compute)
    // Read-first mode: read happens before write on same address
    always_ff @(posedge clk) begin
        // Read port (always reads, gets OLD data if same address as write)
        input_rd_data <= input_bram[input_rd_addr[11:0]];

        // Write port
        if (input_we) begin
            input_bram[input_addr[11:0]] <= input_data;
        end
    end

    // Weight BRAM - Dual port (write from host, read from compute)
    // Read-first mode: read happens before write on same address
    always_ff @(posedge clk) begin
        // Read port (always reads, gets OLD data if same address as write)
        weight_rd_data <= weight_bram[weight_rd_addr[13:0]];

        // Write port
        if (weight_we) begin
            weight_bram[weight_addr[13:0]] <= weight_data;
        end
    end

    // Bias BRAM - Dual port (write from host, read from compute)
    // Read-first mode: read happens before write on same address
    always_ff @(posedge clk) begin
        // Read port (always reads, gets OLD data if same address as write)
        bias_rd_data <= bias_bram[bias_rd_addr[7:0]];

        // Write port
        if (bias_we) begin
            bias_bram[bias_addr[7:0]] <= bias_data;
        end
    end

    // Output BRAM - Dual port (write from compute, read from host)
    // Read-first mode: read happens before write on same address
    always_ff @(posedge clk) begin
        // Read port (always reads, gets OLD data if same address as write)
        output_rd_data <= output_bram[output_rd_addr[11:0]];

        // Write port
        if (output_wr_en) begin
            output_bram[output_wr_addr[11:0]] <= output_wr_data;
        end
    end

endmodule
