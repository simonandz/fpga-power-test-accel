// SAIF Testbench - IDLE Mode
// Runs the design in idle state (run_enable=0) to capture idle switching activity

`timescale 1ns / 1ps

module tb_saif_idle;
    parameter CLK_PERIOD = 10;  // 100 MHz
    parameter IDLE_TIME_US = 100;  // 100us of idle

    logic clk = 0;
    logic rst_n;
    logic run_enable;
    logic randomize_en;
    logic led_heartbeat, led_running, led_busy, led_done;
    logic [7:0] led_count;
    logic [6:0] seg;
    logic [3:0] an;

    // Clock generation
    always #(CLK_PERIOD/2) clk = ~clk;

    // DUT
    mlp_power_test_wrapper dut (
        .clk(clk),
        .rst_n(rst_n),
        .run_enable(run_enable),
        .randomize_en(randomize_en),
        .led_heartbeat(led_heartbeat),
        .led_running(led_running),
        .led_busy(led_busy),
        .led_done(led_done),
        .led_count(led_count),
        .seg(seg),
        .an(an)
    );

    initial begin
        $display("=== IDLE SAIF Generation ===");

        // Initialize
        rst_n = 0;
        run_enable = 0;
        randomize_en = 0;

        // Reset
        repeat(20) @(posedge clk);
        rst_n = 1;

        // Wait for initialization to complete
        repeat(200) @(posedge clk);

        $display("Design initialized, capturing IDLE activity...");

        // Stay in IDLE for specified time
        // run_enable stays 0
        #(IDLE_TIME_US * 1000);  // Convert us to ns

        $display("IDLE capture complete");
        $finish;
    end

    // Timeout
    initial begin
        #10000000;  // 10ms timeout
        $display("Timeout!");
        $finish;
    end
endmodule

