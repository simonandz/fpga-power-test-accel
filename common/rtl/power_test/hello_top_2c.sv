`timescale 1ns/1ps

module hello_top_2c #(
  parameter int DIV_BIT = 26
) (
  input  logic clk,
  input  logic rst_n,
  output logic led_on,
  output logic led_blink0,
  output logic led_blink1
);

  // two independent counters
  logic [DIV_BIT-1:0] ctr0, ctr1;

  always_ff @(posedge clk) begin
    if (!rst_n) begin
      ctr0 <= '0;
      ctr1 <= '0;
    end else begin
      ctr0 <= ctr0 + 1'b1;
      ctr1 <= ctr1 + 1'b1;
    end
  end

  assign led_on    = 1'b1;
  assign led_blink0 = ctr0[DIV_BIT-1];
  assign led_blink1 = ctr1[DIV_BIT-1];

endmodule
