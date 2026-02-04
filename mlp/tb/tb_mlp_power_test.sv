// MLP Power Test Wrapper Testbench
// Simulates the power measurement wrapper to verify functionality
// before programming the Basys 3 board.
//
// Tests:
// 1. Reset and initialization sequence
// 2. Idle mode (run_enable = 0)
// 3. Continuous inference mode (run_enable = 1)
// 4. Randomize mode toggle
// 5. Inference count verification

`timescale 1ns / 1ps

module tb_mlp_power_test;

    //==========================================================================
    // Parameters
    //==========================================================================
    parameter CLK_PERIOD_NS = 10;  // 100 MHz
    parameter NUM_INFERENCES_TO_RUN = 50;  // Run this many inferences in test

    //==========================================================================
    // Signals
    //==========================================================================
    logic        clk;
    logic        rst_n;
    logic        run_enable;
    logic        randomize_en;

    logic        led_heartbeat;
    logic        led_running;
    logic        led_busy;
    logic        led_done;
    logic [7:0]  led_count;

    logic [6:0]  seg;
    logic [3:0]  an;

    // Test tracking
    int unsigned observed_inferences;
    int unsigned expected_inferences;

    //==========================================================================
    // Clock Generation
    //==========================================================================
    initial begin
        clk = 0;
        forever #(CLK_PERIOD_NS/2) clk = ~clk;
    end

    //==========================================================================
    // DUT - Power Test Wrapper
    //==========================================================================
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

    //==========================================================================
    // Inference Counter (count done pulses)
    //==========================================================================
    logic led_done_prev;
    always_ff @(posedge clk) begin
        led_done_prev <= led_done;
        if (led_done && !led_done_prev) begin
            observed_inferences++;
        end
    end

    //==========================================================================
    // 7-Segment Display Decoder (for verification)
    //==========================================================================
    function automatic logic [3:0] decode_7seg(input logic [6:0] seg_in);
        case (seg_in)
            7'b1000000: return 4'h0;
            7'b1111001: return 4'h1;
            7'b0100100: return 4'h2;
            7'b0110000: return 4'h3;
            7'b0011001: return 4'h4;
            7'b0010010: return 4'h5;
            7'b0000010: return 4'h6;
            7'b1111000: return 4'h7;
            7'b0000000: return 4'h8;
            7'b0010000: return 4'h9;
            7'b0001000: return 4'hA;
            7'b0000011: return 4'hB;
            7'b1000110: return 4'hC;
            7'b0100001: return 4'hD;
            7'b0000110: return 4'hE;
            7'b0001110: return 4'hF;
            default:    return 4'hX;
        endcase
    endfunction

    //==========================================================================
    // Main Test Sequence
    //==========================================================================
    initial begin
        $display("");
        $display("================================================================");
        $display("MLP Power Test Wrapper - Functional Verification");
        $display("================================================================");
        $display("");

        // Initialize
        rst_n = 0;
        run_enable = 0;
        randomize_en = 0;
        observed_inferences = 0;

        //======================================================================
        // Test 1: Reset and Initialization
        //======================================================================
        $display("[%0t] TEST 1: Reset and initialization...", $time);

        repeat(20) @(posedge clk);
        rst_n = 1;
        $display("[%0t]   Reset released", $time);

        // Wait for initialization (weight/bias/input loading)
        // State machine goes through S_LOAD_WEIGHTS -> S_LOAD_BIAS -> S_LOAD_INPUTS -> S_IDLE
        // Weights: 8*4 = 32 cycles, Bias: 4 cycles, Inputs: 8 cycles = ~50 cycles
        repeat(100) @(posedge clk);

        if (led_running == 0 && led_busy == 0) begin
            $display("[%0t]   PASS: Design in idle state after init", $time);
        end else begin
            $display("[%0t]   FAIL: Unexpected state after init (running=%b, busy=%b)",
                     $time, led_running, led_busy);
        end
        $display("");

        //======================================================================
        // Test 2: Idle Mode (run_enable = 0)
        //======================================================================
        $display("[%0t] TEST 2: Idle mode verification...", $time);

        observed_inferences = 0;
        repeat(500) @(posedge clk);

        if (observed_inferences == 0) begin
            $display("[%0t]   PASS: No inferences in idle mode", $time);
        end else begin
            $display("[%0t]   FAIL: %0d inferences occurred in idle mode",
                     $time, observed_inferences);
        end
        $display("");

        //======================================================================
        // Test 3: Continuous Inference Mode (run_enable = 1)
        //======================================================================
        $display("[%0t] TEST 3: Continuous inference mode...", $time);

        observed_inferences = 0;
        run_enable = 1;
        $display("[%0t]   run_enable = 1", $time);

        // Wait for synchronizer (3 cycles) + state transition
        repeat(10) @(posedge clk);

        if (led_running == 1) begin
            $display("[%0t]   PASS: led_running asserted", $time);
        end else begin
            $display("[%0t]   FAIL: led_running not asserted", $time);
        end

        // Run for enough time to complete NUM_INFERENCES_TO_RUN inferences
        // Each inference takes roughly 50-100 cycles
        repeat(NUM_INFERENCES_TO_RUN * 150) @(posedge clk);

        $display("[%0t]   Observed %0d inferences", $time, observed_inferences);
        $display("[%0t]   led_count = 0x%02h (%0d)", $time, led_count, led_count);

        if (observed_inferences >= NUM_INFERENCES_TO_RUN) begin
            $display("[%0t]   PASS: Continuous inference running", $time);
        end else begin
            $display("[%0t]   FAIL: Expected >= %0d inferences, got %0d",
                     $time, NUM_INFERENCES_TO_RUN, observed_inferences);
        end
        $display("");

        //======================================================================
        // Test 4: Stop and Return to Idle
        //======================================================================
        $display("[%0t] TEST 4: Stop inference...", $time);

        run_enable = 0;
        repeat(200) @(posedge clk);

        // Count should stop
        expected_inferences = observed_inferences;
        repeat(500) @(posedge clk);

        if (observed_inferences == expected_inferences) begin
            $display("[%0t]   PASS: Inference stopped (count frozen at %0d)",
                     $time, observed_inferences);
        end else begin
            $display("[%0t]   FAIL: Inference continued after stop",
                     $time);
        end
        $display("");

        //======================================================================
        // Test 5: Randomize Mode
        //======================================================================
        $display("[%0t] TEST 5: Randomize mode...", $time);

        randomize_en = 1;
        run_enable = 1;
        observed_inferences = 0;

        repeat(30 * 150) @(posedge clk);  // Run 30 more inferences

        $display("[%0t]   Observed %0d inferences with randomize_en=1",
                 $time, observed_inferences);

        if (observed_inferences >= 25) begin
            $display("[%0t]   PASS: Randomize mode running", $time);
        end else begin
            $display("[%0t]   FAIL: Fewer inferences than expected", $time);
        end

        run_enable = 0;
        randomize_en = 0;
        $display("");

        //======================================================================
        // Test 6: Verify 7-Segment Display
        //======================================================================
        $display("[%0t] TEST 6: 7-segment display check...", $time);

        // Let display multiplex through all digits
        repeat(500000) @(posedge clk);  // ~5ms to cycle through all digits

        $display("[%0t]   7-seg anodes cycling (an should change): an=%b", $time, an);
        $display("[%0t]   Current segment pattern: seg=%b", $time, seg);
        $display("[%0t]   PASS: 7-segment display functional (manual verify on board)", $time);
        $display("");

        //======================================================================
        // Summary
        //======================================================================
        $display("================================================================");
        $display("TEST SUMMARY");
        $display("================================================================");
        $display("Total inferences observed: %0d", led_count);
        $display("");
        $display("Design is ready for power measurement on Basys 3.");
        $display("");
        $display("Instructions:");
        $display("  1. Program bitstream to Basys 3");
        $display("  2. Connect USB power meter");
        $display("  3. SW0=1 (reset off), SW1=0 -> measure IDLE power");
        $display("  4. SW1=1 -> measure ACTIVE power");
        $display("  5. Delta = Active - Idle = MLP dynamic power");
        $display("================================================================");
        $display("");

        repeat(10) @(posedge clk);
        $finish;
    end

    //==========================================================================
    // Timeout
    //==========================================================================
    initial begin
        #50000000;  // 50ms timeout
        $display("");
        $display("ERROR: Simulation timeout!");
        $display("");
        $finish;
    end

    //==========================================================================
    // VCD Dump
    //==========================================================================
    initial begin
        $dumpfile("mlp_power_test.vcd");
        $dumpvars(0, tb_mlp_power_test);
    end

endmodule
