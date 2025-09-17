module hello_top #(
  parameter int DIV_BIT = 26
) (
  input  logic clk,
  input  logic rst_n,
  output logic led_on,     
  output logic led_blink   
);

  logic [DIV_BIT-1:0] ctr;

  always_ff @(posedge clk) begin
    if (!rst_n) ctr <= '0;
    else        ctr <= ctr + 1'b1;
  end

  assign led_on    = 1'b1;
  assign led_blink = ctr[DIV_BIT-1];

endmodule
