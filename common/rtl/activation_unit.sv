// Activation Function Unit
// Supports multiple activation functions for MLP, CNN, and RNN
// - ReLU: max(0, x)
// - Saturate: Clamp to 8-bit range with Q4.4 scaling
// - tanh (3-segment PWL approximation) for RNN

`timescale 1ns / 1ps

module activation_unit (
    input  logic         clk,
    input  logic         rst_n,

    // Control
    input  logic [1:0]   activation_type,  // 0=ReLU, 1=tanh, 2=Sigmoid, 3=None
    input  logic         enable,

    // Input (16-bit accumulator value with bias added)
    input  logic signed [15:0] data_in,

    // Output (8-bit activated value)
    output logic [7:0]   data_out,
    output logic         valid
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
                        // tanh(x) ≈ x         for |x| < 0.5
                        //           sign(x)   for |x| > 2.0
                        //           ...       (interpolated for middle range)

                        logic signed [15:0] abs_x;
                        logic sign_bit;

                        sign_bit = data_in[15];
                        abs_x = sign_bit ? -data_in : data_in;

                        if (abs_x < 16'h0080) begin  // |x| < 0.5 in Q4.4 (0.5 * 16 = 8)
                            result <= data_in;  // Linear region
                        end else if (abs_x > 16'h0200) begin  // |x| > 2.0 in Q4.4 (2.0 * 16 = 32)
                            result <= sign_bit ? 16'hFF00 : 16'h0100;  // Saturate to ±1.0
                        end else begin
                            // Middle region: approximate with slope
                            // tanh(x) ≈ sign(x) * (0.5 + 0.25*|x|)
                            logic signed [15:0] approx;
                            approx = 16'h0080 + (abs_x >>> 2);  // 0.5 + 0.25*|x|
                            result <= sign_bit ? -approx : approx;
                        end
                    end

                    SIGMOID: begin
                        // Simple sigmoid approximation
                        // σ(x) ≈ 0.5 + x/4 for |x| < 2
                        //        1.0       for x > 2
                        //        0.0       for x < -2
                        if (data_in > 16'h0200) begin  // x > 2.0
                            result <= 16'h0100;  // 1.0 in Q4.4
                        end else if (data_in < 16'hFE00) begin  // x < -2.0
                            result <= 16'h0000;  // 0.0
                        end else begin
                            result <= 16'h0080 + (data_in >>> 2);  // 0.5 + x/4
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

    // Saturate to 8-bit output (Q4.4 format)
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            data_out <= 8'h00;
            valid <= 1'b0;
        end else begin
            // Shift right by 4 bits to convert from Q8.8 to Q4.4
            // and saturate to 8-bit range
            if (result > 16'h0FF0) begin  // Max: 255 in Q4.4 (255 * 16)
                data_out <= 8'hFF;
            end else if (result < 16'h0000) begin  // Negative values clamp to 0 for unsigned output
                data_out <= 8'h00;
            end else begin
                data_out <= result[11:4];  // Extract middle 8 bits (Q4.4)
            end
            valid <= valid_reg;
        end
    end

endmodule
