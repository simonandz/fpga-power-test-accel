// SAIF Testbench - ACTIVE Mode
// Runs the design in active state (run_enable=1) to capture active switching activity

`timescale 1ns / 1ps

module tb_saif_active;
    parameter CLK_PERIOD = 10;  // 100 MHz
    parameter ACTIVE_TIME_US = 100;  // 100us of active inference

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

    int inference_count = 0;
    logic led_done_prev;

    always_ff @(posedge clk) begin
        led_done_prev <= led_done;
        if (led_done && !led_done_prev)
            inference_count++;
    end

    initial begin
        $display("=== ACTIVE SAIF Generation ===");

        // Initialize
        rst_n = 0;
        run_enable = 0;
        randomize_en = 1;  // Enable randomization for varied activity

        // Reset
        repeat(20) @(posedge clk);
        rst_n = 1;

        // Wait for initialization to complete
        repeat(200) @(posedge clk);

        $display("Design initialized, starting ACTIVE inference...");

        // Enable continuous inference
        run_enable = 1;

        // Run for specified time
        #(ACTIVE_TIME_US * 1000);  // Convert us to ns

        $display("ACTIVE capture complete");
        $display("Inferences completed: %0d", inference_count);
        $finish;
    end

    // Timeout
    initial begin
        #10000000;  // 10ms timeout
        $display("Timeout!");
        $finish;
    end
endmodule

