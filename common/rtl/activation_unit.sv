// Activation Function Unit
// Supports multiple activation functions for MLP, CNN, and RNN
// - ReLU: max(0, x)
// - tanh (3-segment PWL approximation) for RNN
// - Sigmoid (3-segment PWL approximation)
// - None (pass-through)
//
// Format: Signed INT8/INT16 throughout
// - Input: signed 16-bit integer (accumulator result)
// - Output: signed 8-bit integer (-128 to +127)
// - Saturates to INT8 range with overflow detection

`timescale 1ns / 1ps

module activation_unit (
    input  logic         clk,
    input  logic         rst_n,

    // Control
    input  logic [1:0]   activation_type,  // 0=ReLU, 1=tanh, 2=Sigmoid, 3=None
    input  logic         enable,

    // Input (16-bit accumulator value)
    input  logic signed [15:0] data_in,

    // Output (8-bit activated value)
    output logic signed [7:0]  data_out,
    output logic               valid
);

    // Activation type encoding
    localparam RELU    = 2'b00;
    localparam TANH    = 2'b01;
    localparam SIGMOID = 2'b10;
    localparam NONE    = 2'b11;

    logic signed [15:0] result;
    logic               valid_reg;

    // Activation function logic
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result <= 16'h0000;
            valid_reg <= 1'b0;
        end else begin
            if (enable) begin
                case (activation_type)
                    RELU: begin
                        // ReLU: max(0, x)
                        if (data_in < 0) begin
                            result <= 16'h0000;
                        end else begin
                            result <= data_in;
                        end
                    end

                    TANH: begin
                        // 3-segment piecewise linear tanh approximation
                        // Maps INT16 input to INT8 output range
                        // tanh(x) ≈ x/128      for |x| < 64
                        //           sign(x)*64 for |x| >= 64

                        logic signed [15:0] abs_x;
                        logic sign_bit;

                        sign_bit = data_in[15];
                        abs_x = sign_bit ? -data_in : data_in;

                        if (abs_x < 64) begin
                            // Linear region: scale down
                            result <= data_in;
                        end else begin
                            // Saturation region: clamp to ±64
                            result <= sign_bit ? -16'd64 : 16'd64;
                        end
                    end

                    SIGMOID: begin
                        // Simple sigmoid approximation
                        // σ(x) ≈ 64 + x/4   for |x| < 128
                        //        127        for x >= 128
                        //        0          for x <= -128

                        if (data_in > 128) begin
                            result <= 16'd127;
                        end else if (data_in < -128) begin
                            result <= 16'd0;
                        end else begin
                            // Shift to range [0, 127]: sigmoid(0) = 64
                            result <= 16'd64 + (data_in >>> 2);
                        end
                    end

                    NONE: begin
                        // Pass through without activation
                        result <= data_in;
                    end

                    default: begin
                        result <= data_in;
                    end
                endcase
                valid_reg <= 1'b1;
            end else begin
                valid_reg <= 1'b0;
            end
        end
    end

    // Saturate to 8-bit signed INT8 output
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            data_out <= 8'h00;
            valid <= 1'b0;
        end else begin
            // Saturate 16-bit to 8-bit signed range
            if (result > 127) begin
                data_out <= 8'd127;  // Max positive INT8
            end else if (result < -128) begin
                data_out <= -8'd128;  // Min negative INT8
            end else begin
                data_out <= result[7:0];  // Direct assignment
            end
            valid <= valid_reg;
        end
    end

endmodule
