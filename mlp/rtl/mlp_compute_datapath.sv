// MLP Compute Datapath
// Integrates MAC array and activation unit
// Performs: accumulate(MAC(inputs, weights)) + bias -> activation
//
// Format: Signed INT8/INT16 throughout
// - Inputs/weights/bias: signed 8-bit integers (-128 to +127)
// - Accumulator: signed 16-bit integer (-32768 to +32767)
// - Output: signed 8-bit integer after activation

`timescale 1ns / 1ps

module mlp_compute_datapath (
    input  logic         clk,
    input  logic         rst_n,

    // Control signals
    input  logic         mac_enable,
    input  logic         mac_clear,
    input  logic         activation_enable,
    input  logic [1:0]   activation_type,

    // Data inputs (8-way parallel)
    input  logic signed [7:0]   data_in[0:7],
    input  logic signed [7:0]   weight_in[0:7],
    input  logic signed [7:0]   bias_in,

    // Data outputs
    output logic signed [7:0]   result_out,
    output logic                result_valid,

    // Status outputs
    output logic signed [15:0]  accumulator,
    output logic                mac_valid
);

    // MAC Array signals
    logic signed [15:0] mac_out[0:7];
    logic signed [15:0] mac_partial_sum;
    logic               mac_valid_int;

    // Activation signals
    logic signed [15:0] activation_in;
    logic signed [7:0]  activation_out;
    logic               activation_valid;

    // Accumulator
    logic signed [15:0] acc_reg;

    // MAC Array instance
    mac_array_8x mac_inst (
        .clk(clk),
        .rst_n(rst_n),
        .enable(mac_enable),
        .clear_acc(mac_clear),
        .data_in(data_in),
        .weight_in(weight_in),
        .mac_out(mac_out),
        .partial_sum(mac_partial_sum),
        .valid(mac_valid_int)
    );

    // Accumulator logic
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

    // Activation Unit instance
    activation_unit activation_inst (
        .clk(clk),
        .rst_n(rst_n),
        .activation_type(activation_type),
        .enable(activation_enable),
        .data_in(activation_in),
        .data_out(activation_out),
        .valid(activation_valid)
    );

    // Add bias to accumulator (simple INT16 addition)
    always_comb begin
        activation_in = acc_reg + $signed(bias_in);
    end

    // Output assignments
    assign accumulator = acc_reg;
    assign mac_valid = mac_valid_int;
    assign result_out = activation_out;
    assign result_valid = activation_valid;

endmodule
