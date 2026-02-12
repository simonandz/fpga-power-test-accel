// 9-way Parallel MAC Array
// Performs 9 multiply-accumulate operations in parallel
// Designed for 3x3 CNN convolution kernels
//
// Format: Signed INT8 throughout
// - Inputs: signed 8-bit integers (-128 to +127)
// - Weights: signed 8-bit integers (-128 to +127)
// - Products: signed 16-bit integers (-32768 to +32767)
// - Partial sum: signed 16-bit integer (sum of 9 products)

`timescale 1ns / 1ps

(* DONT_TOUCH = "TRUE" *)
module mac_array_9x (
    input  logic         clk,
    input  logic         rst_n,

    // Control
    input  logic         enable,        // Enable MAC operation
    input  logic         clear_acc,     // Clear accumulator

    // Input data (9 parallel inputs)
    input  logic signed [7:0]   data_in[0:8],

    // Weights (9 parallel weights)
    input  logic signed [7:0]   weight_in[0:8],

    // Output
    output logic signed [15:0] mac_out[0:8],    // 9 individual products
    output logic signed [15:0] partial_sum,     // Sum of all 9 products
    output logic               valid            // Output valid signal
);

    // Internal registers for pipelined operation
    logic signed [15:0] products[0:8];
    logic signed [15:0] sum_stage1[0:4];  // First reduction: 9 -> 5
    logic signed [15:0] sum_stage2[0:2];  // Second reduction: 5 -> 3
    logic               valid_pipe[0:2];   // Pipeline valid signals

    // Stage 1: Multiply (DSP48E1 operation)
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < 9; i++) begin
                products[i] <= 16'h0000;
                mac_out[i] <= 16'h0000;
            end
            valid_pipe[0] <= 1'b0;
        end else begin
            if (clear_acc) begin
                for (int i = 0; i < 9; i++) begin
                    products[i] <= 16'h0000;
                    mac_out[i] <= 16'h0000;
                end
                valid_pipe[0] <= 1'b0;
            end else if (enable) begin
                for (int i = 0; i < 9; i++) begin
                    products[i] <= $signed(data_in[i]) * $signed(weight_in[i]);
                    mac_out[i] <= products[i];
                end
                valid_pipe[0] <= 1'b1;
            end else begin
                valid_pipe[0] <= 1'b0;
            end
        end
    end

    // Stage 2: First level of reduction (4 adders + 1 passthrough)
    // Reduce 9 products to 5 sums
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < 5; i++) begin
                sum_stage1[i] <= 16'h0000;
            end
            valid_pipe[1] <= 1'b0;
        end else begin
            sum_stage1[0] <= products[0] + products[1];
            sum_stage1[1] <= products[2] + products[3];
            sum_stage1[2] <= products[4] + products[5];
            sum_stage1[3] <= products[6] + products[7];
            sum_stage1[4] <= products[8];               // Passthrough (odd element)
            valid_pipe[1] <= valid_pipe[0];
        end
    end

    // Stage 3: Second level of reduction (2 adders + 1 passthrough)
    // Reduce 5 sums to 3 sums
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < 3; i++) begin
                sum_stage2[i] <= 16'h0000;
            end
            valid_pipe[2] <= 1'b0;
        end else begin
            sum_stage2[0] <= sum_stage1[0] + sum_stage1[1];
            sum_stage2[1] <= sum_stage1[2] + sum_stage1[3];
            sum_stage2[2] <= sum_stage1[4];              // Passthrough
            valid_pipe[2] <= valid_pipe[1];
        end
    end

    // Stage 4: Final reduction (2 adders chained)
    // Reduce 3 sums to final partial sum
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            partial_sum <= 16'h0000;
            valid <= 1'b0;
        end else begin
            partial_sum <= sum_stage2[0] + sum_stage2[1] + sum_stage2[2];
            valid <= valid_pipe[2];
        end
    end

endmodule
