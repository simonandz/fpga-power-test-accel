// Testbench for 2x2 Max Pooling Unit
// Tests sequential 4-pixel input and maximum detection

`timescale 1ns / 1ps

module tb_maxpool_2x2;

    logic clk;
    logic rst_n;
    logic enable;
    logic clear;
    logic [1:0] pixel_idx;
    logic signed [7:0] data_in;
    logic signed [7:0] data_out;
    logic valid;

    int test_passed = 0;
    int test_failed = 0;

    // Clock generation (100 MHz)
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // DUT instantiation
    maxpool_2x2 dut (
        .clk(clk),
        .rst_n(rst_n),
        .enable(enable),
        .clear(clear),
        .pixel_idx(pixel_idx),
        .data_in(data_in),
        .data_out(data_out),
        .valid(valid)
    );

    // Task: feed 4 pixels sequentially, check maximum output
    task automatic test_maxpool(
        input logic signed [7:0] p0, p1, p2, p3,
        input logic signed [7:0] expected_max,
        input string test_name
    );
        logic signed [7:0] actual_max;

        $display("\n--- %s ---", test_name);

        // Clear running max before test
        @(posedge clk);
        clear = 1'b1;
        @(posedge clk);
        clear = 1'b0;

        // Feed pixel 0
        @(posedge clk);
        enable = 1'b1;
        pixel_idx = 2'd0;
        data_in = p0;

        // Feed pixel 1
        @(posedge clk);
        pixel_idx = 2'd1;
        data_in = p1;

        // Feed pixel 2
        @(posedge clk);
        pixel_idx = 2'd2;
        data_in = p2;

        // Feed pixel 3
        @(posedge clk);
        pixel_idx = 2'd3;
        data_in = p3;

        // Wait one cycle for valid to assert (registered output)
        @(posedge clk);
        enable = 1'b0;

        actual_max = data_out;

        $display("  Pixels: %4d, %4d, %4d, %4d", p0, p1, p2, p3);
        $display("  Max: %0d (expected: %0d), valid: %b", actual_max, expected_max, valid);

        if (actual_max == expected_max && valid == 1'b1) begin
            $display("  PASS");
            test_passed++;
        end else begin
            if (actual_max != expected_max)
                $display("  FAIL - wrong max value");
            if (valid != 1'b1)
                $display("  FAIL - valid not asserted");
            test_failed++;
        end
    endtask

    // Main test sequence
    initial begin
        $display("========================================");
        $display("MaxPool 2x2 Testbench");
        $display("Sequential 4-pixel input, signed INT8");
        $display("========================================");

        // Initialize
        rst_n = 0;
        enable = 0;
        clear = 0;
        pixel_idx = 0;
        data_in = 0;

        // Reset
        repeat(10) @(posedge clk);
        rst_n = 1;
        repeat(5) @(posedge clk);

        // =================================================================
        // Test 1: All same values (10, 10, 10, 10) -> max = 10
        // =================================================================
        test_maxpool(10, 10, 10, 10, 10, "Test 1: All same (10)");

        // =================================================================
        // Test 2: Ascending (1, 2, 3, 4) -> max = 4
        // =================================================================
        test_maxpool(1, 2, 3, 4, 4, "Test 2: Ascending (1,2,3,4)");

        // =================================================================
        // Test 3: Descending (4, 3, 2, 1) -> max = 4
        // =================================================================
        test_maxpool(4, 3, 2, 1, 4, "Test 3: Descending (4,3,2,1)");

        // =================================================================
        // Test 4: Max in each position separately
        // =================================================================
        test_maxpool(99, 10, 20, 30, 99, "Test 4a: Max at idx 0");
        test_maxpool(10, 99, 20, 30, 99, "Test 4b: Max at idx 1");
        test_maxpool(10, 20, 99, 30, 99, "Test 4c: Max at idx 2");
        test_maxpool(10, 20, 30, 99, 99, "Test 4d: Max at idx 3");

        // =================================================================
        // Test 5: All negative (-10, -20, -30, -5) -> max = -5
        // =================================================================
        test_maxpool(-10, -20, -30, -5, -5, "Test 5: All negative, max = -5");

        // =================================================================
        // Test 6: Mixed positive/negative (-50, 100, -25, 75) -> max = 100
        // =================================================================
        test_maxpool(-50, 100, -25, 75, 100, "Test 6: Mixed signs, max = 100");

        // =================================================================
        // Test 7: INT8 extremes (127, -128, 0, 1) -> max = 127
        // =================================================================
        test_maxpool(127, -128, 0, 1, 127, "Test 7: INT8 extremes, max = 127");

        // =================================================================
        // Test 8: Clear between tests - verify running_max resets
        // =================================================================
        $display("\n--- Test 8: Clear resets running_max ---");

        // First, feed a large value
        @(posedge clk);
        clear = 1'b1;
        @(posedge clk);
        clear = 1'b0;

        @(posedge clk);
        enable = 1'b1;
        pixel_idx = 2'd0;
        data_in = 8'sd120;
        @(posedge clk);
        pixel_idx = 2'd1;
        data_in = 8'sd120;
        @(posedge clk);
        pixel_idx = 2'd2;
        data_in = 8'sd120;
        @(posedge clk);
        pixel_idx = 2'd3;
        data_in = 8'sd120;
        @(posedge clk);
        enable = 1'b0;

        // Verify it captured 120
        if (data_out == 8'sd120 && valid == 1'b1) begin
            $display("  Pre-clear max = %0d (correct)", data_out);
        end else begin
            $display("  Pre-clear max = %0d, valid = %b (unexpected)", data_out, valid);
        end

        // Now clear
        @(posedge clk);
        clear = 1'b1;
        @(posedge clk);
        clear = 1'b0;

        // Feed small values - the old 120 should NOT persist
        @(posedge clk);
        enable = 1'b1;
        pixel_idx = 2'd0;
        data_in = 8'sd5;
        @(posedge clk);
        pixel_idx = 2'd1;
        data_in = 8'sd3;
        @(posedge clk);
        pixel_idx = 2'd2;
        data_in = 8'sd7;
        @(posedge clk);
        pixel_idx = 2'd3;
        data_in = 8'sd2;
        @(posedge clk);
        enable = 1'b0;

        $display("  Post-clear pixels: 5, 3, 7, 2");
        $display("  Max: %0d (expected: 7), valid: %b", data_out, valid);

        if (data_out == 8'sd7 && valid == 1'b1) begin
            $display("  PASS - clear correctly reset running_max");
            test_passed++;
        end else begin
            $display("  FAIL - clear did not properly reset running_max");
            test_failed++;
        end

        // =================================================================
        // Additional edge cases
        // =================================================================
        test_maxpool(-128, -128, -128, -128, -128, "Test 9: All INT8 min (-128)");
        test_maxpool(127,  127,  127,  127,  127,  "Test 10: All INT8 max (127)");
        test_maxpool(-1, 0, 0, -1, 0, "Test 11: Near zero (-1, 0, 0, -1)");

        // =================================================================
        // Summary
        // =================================================================
        $display("\n========================================");
        $display("Test Summary");
        $display("========================================");
        $display("Tests passed: %0d", test_passed);
        $display("Tests failed: %0d", test_failed);

        if (test_failed == 0) begin
            $display("\nALL TESTS PASSED");
        end else begin
            $display("\nSOME TESTS FAILED");
        end
        $display("========================================\n");

        repeat(10) @(posedge clk);
        $finish;
    end

    // Timeout watchdog
    initial begin
        #100000;
        $display("\nERROR: Simulation timeout!\n");
        $finish;
    end

    // Waveform dump
    initial begin
        $dumpfile("tb_maxpool_2x2.vcd");
        $dumpvars(0, tb_maxpool_2x2);
    end

endmodule
