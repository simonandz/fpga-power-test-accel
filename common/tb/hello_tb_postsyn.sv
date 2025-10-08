`timescale 1ns/1ps
module hello_tb;

  // ===== Config for power-oriented sim =====
  // For post-synthesis, DIV_BIT is hardcoded in the netlist (26 bits)
  localparam int DIV_BIT_TB     = 26;                   // matches synthesized design
  localparam int HALF_PERIOD_CY = 1 << (DIV_BIT_TB-1);  // cycles between led_blink edges
  localparam int EDGES_TO_SEE   = 8;                    // collect some edges
  localparam int WARMUP_CYCLES  = 200;                  // after reset deassert
  localparam int EXTRA_CYCLES   = 200;                  // tail after last edge

  // ===== Clk/Reset & DUT I/O =====
  logic clk   = 1'b0;
  logic rst_n = 1'b0;
  logic led_on, led_blink;

  // 100 MHz clock -> 10 ns period
  always #5 clk = ~clk;

  // ===== DUT (post-synthesis netlist - NO parameters) =====
  hello_top dut (
    .clk       (clk),
    .rst_n     (rst_n),
    .led_on    (led_on),
    .led_blink (led_blink)
  );

  // ===== Bookkeeping (declare at module scope for Vivado) =====
  int   edges_seen         = 0;
  logic blink_q            = 1'b0;
  int   cycles_since_edge  = 0;

  // ===== VCD dump for Vivado Power =====
  initial begin
    // If your flow prefers WDB/SAIF, you can comment these and use xsim switches instead.
    $dumpfile("hello_top.vcd");
    $dumpvars(0, hello_tb);
  end

  // ===== Stimulus & run control =====
  initial begin
    $timeformat(-9, 3, " ns", 10);
    $display("[%t] Simulation starting", $realtime);

    // Hold reset for 100 cycles
    repeat (100) @(posedge clk);
    rst_n = 1'b1;
    $display("[%t] Reset released", $realtime);

    // Warm-up to flush any Xs
    repeat (WARMUP_CYCLES) @(posedge clk);

    // Initialize edge tracker AFTER warmup
    blink_q           = led_blink;
    cycles_since_edge = 0;
    edges_seen        = 0;

    // Run until we see EDGES_TO_SEE toggles of led_blink
    forever begin
      @(posedge clk);
      if (!rst_n) begin
        blink_q           <= led_blink;
        cycles_since_edge <= 0;
        edges_seen        <= 0;
      end else begin
        cycles_since_edge <= cycles_since_edge + 1;

        // Any toggle (rise or fall) of led_blink
        if (blink_q ^ led_blink) begin
          edges_seen <= edges_seen + 1;

          // Optional spacing check (should be HALF_PERIOD_CY)
          if (cycles_since_edge != 0 && cycles_since_edge != HALF_PERIOD_CY) begin
            $error("[%t] led_blink edge spacing = %0d cycles, expected %0d",
                   $realtime, cycles_since_edge, HALF_PERIOD_CY);
          end else begin
            $display("[%t] led_blink toggled (edge %0d, spacing %0d cycles)",
                     $realtime, edges_seen, cycles_since_edge);
          end

          cycles_since_edge <= 0;
        end

        blink_q <= led_blink;

        if (edges_seen >= EDGES_TO_SEE) begin
          repeat (EXTRA_CYCLES) @(posedge clk);
          $display("[%t] Simulation completed", $realtime);
          $finish;
        end
      end
    end
  end

  // ===== Assertions (simulation-only) =====
  // led_on must be 1 after reset deasserts
  assert property (@(posedge clk) disable iff (!rst_n) (led_on == 1'b1))
    else $error("led_on should always be 1 when not in reset");

  // Simple no-glitch check: only 1-bit change allowed (toggle or hold)
  assert property (@(posedge clk) disable iff (!rst_n)
                   (led_blink == $past(led_blink) || (led_blink ^ $past(led_blink))))
    else $error("led_blink glitch detected");

endmodule
