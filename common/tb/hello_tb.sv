`timescale 1ns/1ps
module hello_tb;
  logic clk = 0;
  logic rst_n = 0;
  logic led_on, led_blink;

  // 100 MHz clock -> 10 ns period
  always #5 clk = ~clk;

  // DUT
  hello_top dut (
    .clk(clk),
    .rst_n(rst_n),
    .led_on(led_on),
    .led_blink(led_blink)
  );

  initial begin
    // hold reset 10 cycles
    repeat (10) @(posedge clk);
    rst_n = 1;
    // run long enough to get activity
    repeat (2_000_000) @(posedge clk);
    $finish;
  end
endmodule
