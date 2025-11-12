// Fixed-Point Arithmetic Package
// Common Q4.4 fixed-point utilities for all accelerators
// Q4.4 format: 4 integer bits, 4 fractional bits
// Range: -8.0 to +7.9375 with 0.0625 precision

`timescale 1ns / 1ps

package fixed_point_pkg;

    // Q4.4 format constants
    localparam int FRAC_BITS = 4;
    localparam int INT_BITS  = 4;
    localparam int TOTAL_BITS = 8;

    // Common Q4.4 constants
    localparam logic [7:0] Q44_ZERO   = 8'h00;  // 0.0
    localparam logic [7:0] Q44_ONE    = 8'h10;  // 1.0
    localparam logic [7:0] Q44_HALF   = 8'h08;  // 0.5
    localparam logic [7:0] Q44_NEG_ONE = 8'hF0;  // -1.0
    localparam logic [7:0] Q44_MAX    = 8'h7F;  // 7.9375 (max positive)
    localparam logic [7:0] Q44_MIN    = 8'h80;  // -8.0 (min negative)

    // Convert integer to Q4.4
    function automatic logic [7:0] int_to_q44(input int value);
        return value << FRAC_BITS;
    endfunction

    // Convert Q4.4 to integer (truncate fractional part)
    function automatic int q44_to_int(input logic [7:0] value);
        return $signed(value) >>> FRAC_BITS;
    endfunction

    // Add bias with proper Q4.4 scaling
    // bias is stored as INT8 but needs to be shifted for Q4.4
    function automatic logic signed [15:0] add_bias_q44(
        input logic signed [15:0] accumulator,
        input logic signed [7:0]  bias
    );
        return accumulator + ($signed(bias) <<< FRAC_BITS);
    endfunction

    // Saturate 16-bit accumulator to 8-bit Q4.4
    function automatic logic [7:0] saturate_to_q44(
        input logic signed [15:0] value
    );
        logic [7:0] result;

        // Check for overflow/underflow
        if (value > 16'h0FF0) begin  // Max: 255 << 4
            result = 8'hFF;
        end else if (value < 16'h0000) begin
            result = 8'h00;
        end else begin
            result = value[11:4];  // Extract Q4.4 portion
        end

        return result;
    endfunction

    // Saturate with signed output (for tanh/sigmoid)
    function automatic logic [7:0] saturate_to_q44_signed(
        input logic signed [15:0] value
    );
        logic [7:0] result;

        if (value > 16'h07F0) begin  // Max positive
            result = 8'h7F;
        end else if (value < 16'hF800) begin  // Max negative
            result = 8'h80;
        end else begin
            result = value[11:4];
        end

        return result;
    endfunction

    // Multiply two Q4.4 values
    // Result is Q8.8, need to shift back to Q4.4
    function automatic logic [7:0] mul_q44(
        input logic [7:0] a,
        input logic [7:0] b
    );
        logic signed [15:0] product;
        product = $signed(a) * $signed(b);
        return saturate_to_q44(product);
    endfunction

    // Convert float to Q4.4 (for testbench use)
    function automatic logic [7:0] float_to_q44(input real value);
        int temp;
        temp = int'(value * (1 << FRAC_BITS));

        if (temp > 127) temp = 127;
        if (temp < -128) temp = -128;

        return temp[7:0];
    endfunction

    // Convert Q4.4 to float (for testbench use)
    function automatic real q44_to_float(input logic [7:0] value);
        return real'($signed(value)) / real'(1 << FRAC_BITS);
    endfunction

    // ReLU activation (returns 0 if negative)
    function automatic logic [7:0] relu_q44(
        input logic signed [15:0] value
    );
        if (value < 0) begin
            return 8'h00;
        end else begin
            return saturate_to_q44(value);
        end
    endfunction

    // Check if value is zero
    function automatic logic is_zero_q44(input logic [7:0] value);
        return (value == Q44_ZERO);
    endfunction

    // Absolute value
    function automatic logic [7:0] abs_q44(input logic [7:0] value);
        return ($signed(value) < 0) ? -value : value;
    endfunction

    // Negate
    function automatic logic [7:0] neg_q44(input logic [7:0] value);
        return -value;
    endfunction

    // Compare: return 1 if a > b
    function automatic logic gt_q44(
        input logic [7:0] a,
        input logic [7:0] b
    );
        return ($signed(a) > $signed(b));
    endfunction

    // Maximum of two Q4.4 values
    function automatic logic [7:0] max_q44(
        input logic [7:0] a,
        input logic [7:0] b
    );
        return gt_q44(a, b) ? a : b;
    endfunction

    // Minimum of two Q4.4 values
    function automatic logic [7:0] min_q44(
        input logic [7:0] a,
        input logic [7:0] b
    );
        return gt_q44(a, b) ? b : a;
    endfunction

endpackage : fixed_point_pkg
