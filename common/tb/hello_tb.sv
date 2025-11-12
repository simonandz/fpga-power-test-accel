`timescale 1ns/1ps

module hello_top_tb;

  // Parameters
  localparam int DIV_BIT = 26;
  localparam real CLK_PERIOD = 10.0; 

  // DUT signals
  logic clk;
  logic rst_n;
  logic led_on;
  logic led_blink;

  hello_top #(
    .DIV_BIT(DIV_BIT)
  ) dut (
    .clk(clk),
    .rst_n(rst_n),
    .led_on(led_on),
    .led_blink(led_blink)
  );

  initial clk = 0;
  always #(CLK_PERIOD/2) clk = ~clk;

  // Reset 
  initial begin
    rst_n = 0;
    #(10 * CLK_PERIOD);
    rst_n = 1;
  end

  // main
  initial begin
    $display("Starting simulation.");
    #(5_000_000 * CLK_PERIOD);
    $display("Simulation complete.");
    $finish;
  end

endmodule
