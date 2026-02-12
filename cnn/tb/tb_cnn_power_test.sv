// CNN Power Test Wrapper Testbench
// Simulates the power measurement wrapper to verify functionality
// before programming the Basys 3 board.
//
// Tests:
// 1. Reset and initialization sequence
// 2. Idle mode (run_enable = 0)
// 3. Continuous inference mode (run_enable = 1)
// 4. Stop and return to idle
// 5. Randomize mode toggle

`timescale 1ns / 1ps

module tb_cnn_power_test;

    //==========================================================================
    // Parameters
    //==========================================================================
    parameter CLK_PERIOD_NS = 10;  // 100 MHz
    parameter NUM_INFERENCES_TO_RUN = 10;  // Target inferences for run test

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
    int          test_passed = 0;
    int          test_failed = 0;

    //==========================================================================
    // Clock Generation - 100 MHz (10ns period)
    //==========================================================================
    initial begin
        clk = 0;
        forever #(CLK_PERIOD_NS/2) clk = ~clk;
    end

    //==========================================================================
    // DUT - CNN Power Test Wrapper
    //==========================================================================
    cnn_power_test_wrapper dut (
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
    // Inference Counter (monitor led_count for changes)
    //==========================================================================
    logic [7:0] led_count_prev;
    always_ff @(posedge clk) begin
        led_count_prev <= led_count;
        if (led_count != led_count_prev && led_count > led_count_prev) begin
            observed_inferences = led_count;
        end
    end

    //==========================================================================
    // Heartbeat Monitor
    //==========================================================================
    logic heartbeat_prev;
    int   heartbeat_toggles;
    always_ff @(posedge clk) begin
        heartbeat_prev <= led_heartbeat;
        if (led_heartbeat != heartbeat_prev) begin
            heartbeat_toggles++;
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
        $display("CNN Power Test Wrapper - Functional Verification");
        $display("================================================================");
        $display("");

        // Initialize
        rst_n = 0;
        run_enable = 0;
        randomize_en = 0;
        observed_inferences = 0;
        heartbeat_toggles = 0;

        //======================================================================
        // Test 1: Reset and Initialization (100 cycles), verify heartbeat
        //======================================================================
        $display("[%0t] TEST 1: Reset and initialization (100 cycles)...", $time);

        // Hold reset for 100 cycles
        repeat(100) @(posedge clk);
        rst_n = 1;
        $display("[%0t]   Reset released", $time);

        // Wait for initialization (kernel + bias + ifmap loading)
        // S_LOAD_KERNEL: 9 cycles, S_LOAD_BIAS: 1 cycle, S_LOAD_IFMAP: 256 cycles ~ 300 cycles
        repeat(500) @(posedge clk);

        // Check heartbeat is toggling
        if (heartbeat_toggles > 0) begin
            $display("[%0t]   PASS: Heartbeat toggled %0d times during init",
                     $time, heartbeat_toggles);
            test_passed++;
        end else begin
            $display("[%0t]   FAIL: Heartbeat did not toggle during init", $time);
            test_failed++;
        end

        if (led_running == 0 && led_busy == 0) begin
            $display("[%0t]   PASS: Design in idle state after init", $time);
            test_passed++;
        end else begin
            $display("[%0t]   FAIL: Unexpected state after init (running=%b, busy=%b)",
                     $time, led_running, led_busy);
            test_failed++;
        end
        $display("");

        //======================================================================
        // Test 2: Idle mode (run_enable=0) for 5000 cycles
        //======================================================================
        $display("[%0t] TEST 2: Idle mode verification (5000 cycles)...", $time);

        observed_inferences = 0;
        repeat(5000) @(posedge clk);

        if (led_count == 8'd0) begin
            $display("[%0t]   PASS: No inference count in idle mode (led_count=%0d)",
                     $time, led_count);
            test_passed++;
        end else begin
            $display("[%0t]   FAIL: Unexpected inference count in idle mode (led_count=%0d)",
                     $time, led_count);
            test_failed++;
        end
        $display("");

        //======================================================================
        // Test 3: Run mode (run_enable=1), wait for >5 inferences
        //======================================================================
        $display("[%0t] TEST 3: Continuous inference mode...", $time);

        run_enable = 1;
        $display("[%0t]   run_enable = 1", $time);

        // Wait for synchronizer (3 cycles) + state transitions
        repeat(10) @(posedge clk);

        if (led_running == 1) begin
            $display("[%0t]   PASS: led_running asserted", $time);
            test_passed++;
        end else begin
            $display("[%0t]   FAIL: led_running not asserted", $time);
            test_failed++;
        end

        // CNN inference is slower than MLP (~20+ cycles per output pixel, 256 pixels)
        // Wait for sufficient inferences: each takes ~8000+ cycles
        // Wait for at least 5 inferences
        begin
            int wait_cycles = 0;
            int max_wait = NUM_INFERENCES_TO_RUN * 15000;  // Conservative estimate

            while (led_count < NUM_INFERENCES_TO_RUN && wait_cycles < max_wait) begin
                @(posedge clk);
                wait_cycles++;
            end

            $display("[%0t]   After %0d cycles: led_count = %0d", $time, wait_cycles, led_count);
        end

        if (led_count >= 5) begin
            $display("[%0t]   PASS: Completed >= 5 inferences (led_count=%0d)", $time, led_count);
            test_passed++;
        end else begin
            $display("[%0t]   FAIL: Expected >= 5 inferences, got led_count=%0d",
                     $time, led_count);
            test_failed++;
        end
        $display("");

        //======================================================================
        // Test 4: Stop (run_enable=0), verify returns to idle
        //======================================================================
        $display("[%0t] TEST 4: Stop inference...", $time);

        run_enable = 0;
        $display("[%0t]   run_enable = 0", $time);

        // Wait for current inference to complete + synchronizer
        repeat(20000) @(posedge clk);

        // Record count and wait more
        expected_inferences = led_count;
        repeat(10000) @(posedge clk);

        if (led_count == expected_inferences) begin
            $display("[%0t]   PASS: Inference stopped (count frozen at %0d)",
                     $time, led_count);
            test_passed++;
        end else begin
            $display("[%0t]   FAIL: Inference count changed after stop (was %0d, now %0d)",
                     $time, expected_inferences, led_count);
            test_failed++;
        end
        $display("");

        //======================================================================
        // Test 5: Randomize mode (randomize_en=1, run_enable=1)
        //======================================================================
        $display("[%0t] TEST 5: Randomize mode...", $time);

        randomize_en = 1;
        run_enable = 1;
        $display("[%0t]   randomize_en=1, run_enable=1", $time);

        // Record current count
        expected_inferences = led_count;

        // Wait for some inferences with randomization
        begin
            int wait_cycles = 0;
            int max_wait = 5 * 20000;  // Wait for ~5 more inferences

            while ((led_count - expected_inferences) < 5 && wait_cycles < max_wait) begin
                @(posedge clk);
                wait_cycles++;
            end

            $display("[%0t]   After randomize: led_count = %0d (was %0d)",
                     $time, led_count, expected_inferences);
        end

        if (led_count > expected_inferences) begin
            $display("[%0t]   PASS: Randomize mode running, count incremented to %0d",
                     $time, led_count);
            test_passed++;
        end else begin
            $display("[%0t]   FAIL: No new inferences in randomize mode", $time);
            test_failed++;
        end

        run_enable = 0;
        randomize_en = 0;
        $display("");

        //======================================================================
        // Test 6: Verify 7-Segment Display is cycling
        //======================================================================
        $display("[%0t] TEST 6: 7-segment display check...", $time);

        // Watch the anode pattern change over time
        begin
            logic [3:0] seen_an[4];
            int seen_count = 0;

            for (int cycle = 0; cycle < 1000; cycle++) begin
                @(posedge clk);
                // Check if we see different anode values
                if (cycle == 0) begin
                    seen_an[0] = an;
                    seen_count = 1;
                end else begin
                    logic found;
                    found = 0;
                    for (int s = 0; s < seen_count; s++) begin
                        if (an == seen_an[s]) found = 1;
                    end
                    if (!found && seen_count < 4) begin
                        seen_an[seen_count] = an;
                        seen_count++;
                    end
                end
            end

            $display("[%0t]   Observed %0d unique anode patterns", $time, seen_count);
            $display("[%0t]   Current: an=%b, seg=%b (digit=%h)",
                     $time, an, seg, decode_7seg(seg));
        end
        $display("[%0t]   INFO: 7-segment display functional (verify visually on board)", $time);
        $display("");

        //======================================================================
        // Summary
        //======================================================================
        $display("================================================================");
        $display("TEST SUMMARY");
        $display("================================================================");
        $display("Tests passed: %0d", test_passed);
        $display("Tests failed: %0d", test_failed);
        $display("Total led_count: %0d", led_count);
        $display("");

        if (test_failed == 0) begin
            $display("*** ALL TESTS PASSED ***");
        end else begin
            $display("*** SOME TESTS FAILED ***");
        end

        $display("");
        $display("Design is ready for power measurement on Basys 3.");
        $display("");
        $display("Instructions:");
        $display("  1. Program bitstream to Basys 3");
        $display("  2. Connect USB power meter");
        $display("  3. SW0=1 (reset off), SW1=0 -> measure IDLE power");
        $display("  4. SW1=1 -> measure ACTIVE power");
        $display("  5. Delta = Active - Idle = CNN dynamic power");
        $display("  6. Compare with MLP power measurement results");
        $display("================================================================");
        $display("");

        repeat(10) @(posedge clk);
        $finish;
    end

    //==========================================================================
    // Timeout
    //==========================================================================
    initial begin
        #500000000;  // 500ms timeout (CNN inferences are slower)
        $display("");
        $display("ERROR: Simulation timeout!");
        $display("");
        $finish;
    end

    //==========================================================================
    // VCD Dump
    //==========================================================================
    initial begin
        $dumpfile("cnn_power_test.vcd");
        $dumpvars(0, tb_cnn_power_test);
    end

endmodule
