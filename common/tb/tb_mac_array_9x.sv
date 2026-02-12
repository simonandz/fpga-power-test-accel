// Testbench for 9-way MAC Array (CNN 3x3 kernel)
// Tests parallel multiply-accumulate operations with adder tree reduction

`timescale 1ns / 1ps

module tb_mac_array_9x;

    logic clk;
    logic rst_n;
    logic enable;
    logic clear_acc;
    logic signed [7:0] data_in[0:8];
    logic signed [7:0] weight_in[0:8];
    logic signed [15:0] mac_out[0:8];
    logic signed [15:0] partial_sum;
    logic valid;

    int test_passed = 0;
    int test_failed = 0;

    // Clock generation (100 MHz)
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // DUT instantiation
    mac_array_9x dut (
        .clk(clk),
        .rst_n(rst_n),
        .enable(enable),
        .clear_acc(clear_acc),
        .data_in(data_in),
        .weight_in(weight_in),
        .mac_out(mac_out),
        .partial_sum(partial_sum),
        .valid(valid)
    );

    // Task: apply inputs, wait for valid (4-cycle pipeline), check partial_sum
    task automatic test_mac(
        input logic signed [7:0] d0, d1, d2, d3, d4, d5, d6, d7, d8,
        input logic signed [7:0] w0, w1, w2, w3, w4, w5, w6, w7, w8,
        input int expected_sum,
        input string test_name
    );
        int actual_sum;

        $display("\n--- %s ---", test_name);

        // Clear accumulator before each test
        @(posedge clk);
        clear_acc = 1'b1;
        @(posedge clk);
        clear_acc = 1'b0;

        // Load inputs
        data_in[0] = d0; data_in[1] = d1; data_in[2] = d2;
        data_in[3] = d3; data_in[4] = d4; data_in[5] = d5;
        data_in[6] = d6; data_in[7] = d7; data_in[8] = d8;

        weight_in[0] = w0; weight_in[1] = w1; weight_in[2] = w2;
        weight_in[3] = w3; weight_in[4] = w4; weight_in[5] = w5;
        weight_in[6] = w6; weight_in[7] = w7; weight_in[8] = w8;

        // Pulse enable for one cycle
        @(posedge clk);
        enable = 1'b1;
        @(posedge clk);
        enable = 1'b0;

        // Wait for valid output (4-cycle pipeline latency)
        wait(valid);
        @(posedge clk);

        actual_sum = partial_sum;

        $display("  Data:    %4d %4d %4d %4d %4d %4d %4d %4d %4d",
            d0, d1, d2, d3, d4, d5, d6, d7, d8);
        $display("  Weights: %4d %4d %4d %4d %4d %4d %4d %4d %4d",
            w0, w1, w2, w3, w4, w5, w6, w7, w8);
        $display("  Partial sum: %0d (expected: %0d)", actual_sum, expected_sum);

        if (actual_sum == expected_sum) begin
            $display("  PASS");
            test_passed++;
        end else begin
            $display("  FAIL");
            test_failed++;
        end
    endtask

    // Main test sequence
    initial begin
        int i;
        logic signed [7:0] rand_data[0:8];
        logic signed [7:0] rand_weight[0:8];
        logic signed [31:0] temp_sum;
        logic signed [15:0] expected_16;
        int actual_sum;

        $display("========================================");
        $display("MAC Array 9x Testbench");
        $display("Pipeline: 4-cycle latency");
        $display("========================================");

        // Initialize
        rst_n = 0;
        enable = 0;
        clear_acc = 0;
        for (i = 0; i < 9; i++) begin
            data_in[i] = 0;
            weight_in[i] = 0;
        end

        // Reset
        repeat(10) @(posedge clk);
        rst_n = 1;
        repeat(5) @(posedge clk);

        // =====================================================================
        // Test 1: All zeros -> partial_sum = 0
        // =====================================================================
        test_mac(0, 0, 0, 0, 0, 0, 0, 0, 0,
                 0, 0, 0, 0, 0, 0, 0, 0, 0,
                 0, "Test 1: All zeros");

        // =====================================================================
        // Test 2: All ones (data=1, weight=1) -> partial_sum = 9
        // =====================================================================
        test_mac(1, 1, 1, 1, 1, 1, 1, 1, 1,
                 1, 1, 1, 1, 1, 1, 1, 1, 1,
                 9, "Test 2: All ones (1*1)*9 = 9");

        // =====================================================================
        // Test 3: Max positive (data=127, weight=1) -> partial_sum = 127*9 = 1143
        // =====================================================================
        test_mac(127, 127, 127, 127, 127, 127, 127, 127, 127,
                 1,   1,   1,   1,   1,   1,   1,   1,   1,
                 1143, "Test 3: Max positive 127*1*9 = 1143");

        // =====================================================================
        // Test 4: Mixed signs - alternating +1/-1 weights
        // data = all 10, weights = +1,-1,+1,-1,+1,-1,+1,-1,+1
        // expected = 10*(+1-1+1-1+1-1+1-1+1) = 10*1 = 10
        // =====================================================================
        test_mac(10, 10, 10, 10, 10, 10, 10, 10, 10,
                 1, -1,  1, -1,  1, -1,  1, -1,  1,
                 10, "Test 4: Mixed signs alternating +1/-1 weights");

        // =====================================================================
        // Test 5: Saturation boundary test
        // data=127, weight=127 for all 9 -> 127*127*9 = 145161
        // In 16-bit signed wraps: 145161 & 0xFFFF = 0x7709 = 30473 (positive)
        // Actually 145161 = 0x23709 -> lower 16 bits = 0x3709 = 14089
        // =====================================================================
        begin
            int sat_expected;
            temp_sum = 0;
            for (i = 0; i < 9; i++) begin
                temp_sum = temp_sum + (32'sd127 * 32'sd127);
            end
            expected_16 = temp_sum[15:0];
            sat_expected = $signed(expected_16);

            test_mac(127, 127, 127, 127, 127, 127, 127, 127, 127,
                     127, 127, 127, 127, 127, 127, 127, 127, 127,
                     sat_expected, "Test 5: Saturation boundary 127*127*9 (16-bit wrap)");
        end

        // =====================================================================
        // Test 6: Additional directed tests
        // =====================================================================

        // Negative data, positive weight
        test_mac(-128, -128, -128, -128, -128, -128, -128, -128, -128,
                 1,    1,    1,    1,    1,    1,    1,    1,    1,
                 -1152, "Test 6a: -128*1*9 = -1152");

        // Single non-zero (only index 4 has data)
        test_mac(0, 0, 0, 0, 50, 0, 0, 0, 0,
                 0, 0, 0, 0,  3, 0, 0, 0, 0,
                 150, "Test 6b: Single non-zero pair (50*3 = 150)");

        // Mixed positive/negative data and weights
        // d = {10, -20, 30, -40, 50, -60, 70, -80, 90}
        // w = {1,   2,  3,   4,  5,   6,  7,   8,  9}
        // expected = 10*1 + (-20)*2 + 30*3 + (-40)*4 + 50*5 + (-60)*6 + 70*7 + (-80)*8 + 90*9
        //          = 10 - 40 + 90 - 160 + 250 - 360 + 490 - 640 + 810 = 450
        test_mac(10, -20, 30, -40, 50, -60, 70, -80, 90,
                 1,   2,  3,   4,  5,   6,  7,   8,  9,
                 450, "Test 6c: Mixed data/weights, expected 450");

        // =====================================================================
        // Test 7: 100 Random tests with software model
        // =====================================================================
        $display("\n=== Test 7: 100 Random Tests ===");
        for (int t = 0; t < 100; t++) begin
            // Generate random inputs
            for (i = 0; i < 9; i++) begin
                rand_data[i] = $urandom_range(0, 255);
                rand_weight[i] = $urandom_range(0, 255);
            end

            // Software model: compute expected sum with 16-bit wrapping
            temp_sum = 0;
            for (i = 0; i < 9; i++) begin
                temp_sum = temp_sum + ($signed(rand_data[i]) * $signed(rand_weight[i]));
            end
            expected_16 = temp_sum[15:0];

            // Clear accumulator
            @(posedge clk);
            clear_acc = 1'b1;
            @(posedge clk);
            clear_acc = 1'b0;

            // Apply inputs
            for (i = 0; i < 9; i++) begin
                data_in[i] = rand_data[i];
                weight_in[i] = rand_weight[i];
            end

            // Pulse enable
            @(posedge clk);
            enable = 1'b1;
            @(posedge clk);
            enable = 1'b0;

            // Wait for valid
            wait(valid);
            @(posedge clk);

            // Compare
            if (partial_sum == expected_16) begin
                test_passed++;
            end else begin
                $display("  Random test %0d FAIL: expected %0d, got %0d", t, $signed(expected_16), partial_sum);
                test_failed++;
            end
        end
        $display("  Completed 100 random MAC tests");

        // =====================================================================
        // Summary
        // =====================================================================
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
        $dumpfile("tb_mac_array_9x.vcd");
        $dumpvars(0, tb_mac_array_9x);
    end

endmodule
