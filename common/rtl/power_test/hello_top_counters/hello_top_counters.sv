`timescale 1ns/1ps

// Notes:
// * 'taps' is marked keep/dont_touch so logic won't be trimmed.
module hello_top_counters #(
  parameter int unsigned NUM = 512,
  parameter int unsigned W   = 32
) (
  input  logic clk,
  input  logic rst_n
);

  // Bank of counters
  logic [W-1:0] ctr [NUM];

  // Reduction taps to force LUT/FF activity to be kept
  (* keep = "true", DONT_TOUCH = "true" *) logic [NUM-1:0] taps;

  genvar i;
  generate
    for (i = 0; i < NUM; i++) begin : G
      always_ff @(posedge clk) begin
        if (!rst_n) ctr[i] <= '0;
        else        ctr[i] <= ctr[i] + 1'b1;
      end
      // Mix a few bits so LUTs toggle too; kept so synth won't prune
      assign taps[i] = ^{ctr[i][0], ctr[i][5], ctr[i][9], ctr[i][13],
                         ctr[i][17], ctr[i][21], ctr[i][25], ctr[i][W-1]};
    end
  endgenerate

endmodule