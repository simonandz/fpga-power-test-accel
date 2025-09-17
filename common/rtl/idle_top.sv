module idle_top (
  input  logic clk,
  input  logic rst_n,
  output logic led0
);
  // Tie off outputs
  assign led0 = 1'b0;
endmodule
