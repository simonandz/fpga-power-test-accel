// 2x2 Max Pooling Unit
// Accepts 4 signed INT8 pixels sequentially and outputs the maximum
// Used by CNN accelerator for spatial downsampling
//
// Usage: Assert clear to reset, then feed 4 pixels with enable + pixel_idx 0-3.
// Output valid asserts on the cycle after pixel_idx == 3.

`timescale 1ns / 1ps

(* DONT_TOUCH = "TRUE" *)
module maxpool_2x2 (
    input  logic         clk,
    input  logic         rst_n,

    // Control
    input  logic         enable,          // Latch a new value
    input  logic         clear,           // Reset running max
    input  logic [1:0]   pixel_idx,       // Which of 4 pixels (0-3)

    // Data
    input  logic signed [7:0]  data_in,   // One pixel at a time
    output logic signed [7:0]  data_out,  // Max of 4 pixels
    output logic               valid      // Output ready after pixel_idx == 3
);

    logic signed [7:0] running_max;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            running_max <= -8'sd128;
            valid <= 1'b0;
        end else if (clear) begin
            running_max <= -8'sd128;
            valid <= 1'b0;
        end else if (enable) begin
            if (pixel_idx == 2'd0) begin
                // First pixel: initialize
                running_max <= data_in;
                valid <= 1'b0;
            end else begin
                // Subsequent pixels: compare and keep max
                if (data_in > running_max)
                    running_max <= data_in;
                // Output valid after 4th pixel
                if (pixel_idx == 2'd3)
                    valid <= 1'b1;
                else
                    valid <= 1'b0;
            end
        end else begin
            valid <= 1'b0;
        end
    end

    assign data_out = running_max;

endmodule
