// 8-way Parallel MAC Array
// Performs 8 multiply-accumulate operations in parallel
// Used by MLP, CNN, and RNN accelerators
// INT8 inputs/weights -> INT16 products

`timescale 1ns / 1ps

module mac_array_8x (
    input  logic         clk,
    input  logic         rst_n,

    // Control
    input  logic         enable,        // Enable MAC operation
    input  logic         clear_acc,     // Clear accumulator

    // Input data (8 parallel inputs)
    input  logic [7:0]   data_in[0:7],

    // Weights (8 parallel weights)
    input  logic [7:0]   weight_in[0:7],

    // Output
    output logic signed [15:0] mac_out[0:7],    // 8 individual products
    output logic signed [15:0] partial_sum,     // Sum of all 8 products
    output logic               valid            // Output valid signal
);

    // Internal registers for pipelined operation
    logic signed [15:0] products[0:7];
    logic signed [15:0] sum_stage1[0:3];  // First reduction stage
    logic signed [15:0] sum_stage2[0:1];  // Second reduction stage
    logic               valid_pipe[0:2];   // Pipeline valid signals

    // Stage 1: Multiply (DSP48E1 operation)
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < 8; i++) begin
                products[i] <= 16'h0000;
                mac_out[i] <= 16'h0000;
            end
            valid_pipe[0] <= 1'b0;
        end else begin
            if (clear_acc) begin
                for (int i = 0; i < 8; i++) begin
                    products[i] <= 16'h0000;
                    mac_out[i] <= 16'h0000;
                end
                valid_pipe[0] <= 1'b0;
            end else if (enable) begin
                for (int i = 0; i < 8; i++) begin
                    products[i] <= $signed(data_in[i]) * $signed(weight_in[i]);
                    mac_out[i] <= products[i];
                end
                valid_pipe[0] <= 1'b1;
            end else begin
                valid_pipe[0] <= 1'b0;
            end
        end
    end

    // Stage 2: First level of reduction (4 adders)
    // Reduce 8 products to 4 sums
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < 4; i++) begin
                sum_stage1[i] <= 16'h0000;
            end
            valid_pipe[1] <= 1'b0;
        end else begin
            sum_stage1[0] <= products[0] + products[1];
            sum_stage1[1] <= products[2] + products[3];
            sum_stage1[2] <= products[4] + products[5];
            sum_stage1[3] <= products[6] + products[7];
            valid_pipe[1] <= valid_pipe[0];
        end
    end

    // Stage 3: Second level of reduction (2 adders)
    // Reduce 4 sums to 2 sums
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < 2; i++) begin
                sum_stage2[i] <= 16'h0000;
            end
            valid_pipe[2] <= 1'b0;
        end else begin
            sum_stage2[0] <= sum_stage1[0] + sum_stage1[1];
            sum_stage2[1] <= sum_stage1[2] + sum_stage1[3];
            valid_pipe[2] <= valid_pipe[1];
        end
    end

    // Stage 4: Final reduction (1 adder)
    // Reduce 2 sums to final partial sum
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            partial_sum <= 16'h0000;
            valid <= 1'b0;
        end else begin
            partial_sum <= sum_stage2[0] + sum_stage2[1];
            valid <= valid_pipe[2];
        end
    end

endmodule
