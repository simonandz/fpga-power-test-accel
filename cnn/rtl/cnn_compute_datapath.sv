// CNN Compute Datapath
// Integrates 9-way MAC array, activation unit, and optional max pooling
// Performs: MAC(window, kernel) + bias -> activation -> [maxpool]
//
// Format: Signed INT8/INT16 throughout
// - Window/kernel: signed 8-bit integers (-128 to +127)
// - Accumulator: signed 16-bit integer (-32768 to +32767)
// - Output: signed 8-bit integer after activation
//
// Pipeline: MAC (4 cyc) -> accumulate (1 cyc) -> bias add (1 cyc) -> activation (2 cyc)
// Total: 8 cycles from mac_enable to conv_valid

`timescale 1ns / 1ps

(* DONT_TOUCH = "TRUE" *)
module cnn_compute_datapath (
    input  logic         clk,
    input  logic         rst_n,

    // Control signals (from controller)
    input  logic         mac_enable,
    input  logic         mac_clear,
    input  logic         activation_enable,
    input  logic [1:0]   activation_type,      // 0=ReLU, 1=tanh, 2=sigmoid, 3=none

    // Pooling control
    input  logic         pool_enable,           // Latch current result into pool unit
    input  logic         pool_clear,            // Reset pool running max
    input  logic [1:0]   pool_pixel_idx,        // Which of 4 pool pixels

    // Data inputs (9-way parallel from 3x3 window)
    input  logic signed [7:0]   window_data[0:8],   // 3x3 window pixels
    input  logic signed [7:0]   kernel_data[0:8],   // 3x3 kernel weights
    input  logic signed [7:0]   bias_in,

    // Data outputs
    output logic signed [7:0]   conv_result,    // Post-activation (before pool)
    output logic                conv_valid,     // Conv result valid
    output logic signed [7:0]   pool_result,    // Post-pooling result
    output logic                pool_valid,     // Pool result valid

    // Status
    output logic signed [15:0]  accumulator,
    output logic                mac_valid
);

    // =========================================================================
    // MAC Array signals
    // =========================================================================
    logic signed [15:0] mac_out [0:8];
    logic signed [15:0] mac_partial_sum;
    logic               mac_valid_int;

    // =========================================================================
    // Accumulator and bias pipeline
    // =========================================================================
    logic signed [15:0] acc_reg;
    logic signed [15:0] acc_plus_bias_reg;
    logic               acc_plus_bias_valid;

    // =========================================================================
    // Activation signals
    // =========================================================================
    logic signed [15:0] activation_in;
    logic signed [7:0]  activation_out;
    logic               activation_valid;

    // =========================================================================
    // MAC Array 9x instance
    // =========================================================================
    mac_array_9x mac_inst (
        .clk(clk),
        .rst_n(rst_n),
        .enable(mac_enable),
        .clear_acc(mac_clear),
        .data_in(window_data),
        .weight_in(kernel_data),
        .mac_out(mac_out),
        .partial_sum(mac_partial_sum),
        .valid(mac_valid_int)
    );

    // =========================================================================
    // Accumulator logic
    // For 3x3 convolution, all 9 products are computed in one MAC pass,
    // so no multi-pass accumulation needed. But we keep the accumulate
    // pattern for consistency with MLP and potential future extension.
    // =========================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            acc_reg <= 16'h0000;
        end else begin
            if (mac_clear) begin
                acc_reg <= 16'h0000;
            end else if (mac_valid_int) begin
                acc_reg <= acc_reg + mac_partial_sum;
            end
        end
    end

    // =========================================================================
    // Pipeline register for bias addition
    // =========================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            acc_plus_bias_reg <= 16'h0000;
            acc_plus_bias_valid <= 1'b0;
        end else begin
            if (mac_clear) begin
                acc_plus_bias_reg <= 16'h0000;
                acc_plus_bias_valid <= 1'b0;
            end else if (activation_enable) begin
                acc_plus_bias_reg <= acc_reg + $signed(bias_in);
                acc_plus_bias_valid <= 1'b1;
            end else begin
                acc_plus_bias_valid <= 1'b0;
            end
        end
    end

    // =========================================================================
    // Activation Unit instance (reused from common/rtl)
    // =========================================================================
    activation_unit activation_inst (
        .clk(clk),
        .rst_n(rst_n),
        .activation_type(activation_type),
        .enable(acc_plus_bias_valid),
        .data_in(activation_in),
        .data_out(activation_out),
        .valid(activation_valid)
    );

    assign activation_in = acc_plus_bias_reg;

    // =========================================================================
    // MaxPool 2x2 instance
    // =========================================================================
    maxpool_2x2 pool_inst (
        .clk(clk),
        .rst_n(rst_n),
        .enable(pool_enable),
        .clear(pool_clear),
        .pixel_idx(pool_pixel_idx),
        .data_in(activation_out),
        .data_out(pool_result),
        .valid(pool_valid)
    );

    // =========================================================================
    // Output assignments
    // =========================================================================
    assign accumulator = acc_reg;
    assign mac_valid = mac_valid_int;
    assign conv_result = activation_out;
    assign conv_valid = activation_valid;

endmodule
