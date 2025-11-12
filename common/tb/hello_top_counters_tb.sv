`timescale 1ns/1ps

// Testbench for hello_top_counters - generates switching activity for power analysis
module hello_top_counters_tb;

  // ===== Clock/Reset =====
  logic clk   = 1'b0;
  logic rst_n = 1'b0;

  // 100 MHz clock -> 10 ns period
  always #5 clk = ~clk;

  // ===== DUT =====
  // Instantiate with default parameters (NUM=512, W=32) to match synthesis
  hello_top_counters dut (
    .clk   (clk),
    .rst_n (rst_n)
  );

  // ===== VCD dump (optional, for waveform viewing) =====
  // Disabled for faster simulation - only SAIF needed for power analysis
  // initial begin
  //   $dumpfile("hello_top_counters.vcd");
  //   $dumpvars(0, hello_top_counters_tb);
  // end

  // ===== Stimulus & run control =====
  initial begin
    $timeformat(-9, 3, " ns", 10);
    $display("[%t] === hello_top_counters simulation starting ===", $realtime);

    // Hold reset for 100 cycles
    repeat (100) @(posedge clk);
    rst_n = 1'b1;
    $display("[%t] Reset released - counters running", $realtime);

    // Run for sufficient time to capture switching activity
    // For power analysis, we need enough cycles to see all bits toggle
    // With W=32, worst case is bit[31] toggles every 2^31 cycles
    // But for power estimation, we only need to capture enough activity
    // to get good toggle rate statistics. 100K cycles is sufficient.
    repeat (100_000) @(posedge clk);

    $display("[%t] === Simulation completed ===", $realtime);
    $finish;
  end

  // ===== Monitoring (optional) =====
  // Sample a few counters periodically to verify activity
  initial begin
    #1; // offset slightly from clock edge
    wait(rst_n == 1'b1);

    forever begin
      #10000; // every 10us
      $display("[%t] Sample counters: [0]=%0d, [1]=%0d, [511]=%0d",
               $realtime, dut.ctr[0], dut.ctr[1], dut.ctr[511]);
    end
  end

endmodule
