// Testbench for 8-way MAC Array
// Tests parallel multiply-accumulate operations

`timescale 1ns / 1ps

module tb_mac_array_8x;

    logic clk;
    logic rst_n;
    logic enable;
    logic clear_acc;
    logic [7:0] data_in[0:7];
    logic [7:0] weight_in[0:7];
    logic signed [15:0] mac_out[0:7];
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
    mac_array_8x dut (
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

    // Test task - Icarus compatible
    task test_mac;
        input logic [7:0] in0, in1, in2, in3, in4, in5, in6, in7;
        input logic [7:0] w0, w1, w2, w3, w4, w5, w6, w7;
        input int expected_sum;
        input string test_name;
        int i;
        logic signed [15:0] expected_products[0:7];
        int actual_sum;

        $display("\n--- %s ---", test_name);

        // Load inputs
        data_in[0] = in0; data_in[1] = in1; data_in[2] = in2; data_in[3] = in3;
        data_in[4] = in4; data_in[5] = in5; data_in[6] = in6; data_in[7] = in7;
        weight_in[0] = w0; weight_in[1] = w1; weight_in[2] = w2; weight_in[3] = w3;
        weight_in[4] = w4; weight_in[5] = w5; weight_in[6] = w6; weight_in[7] = w7;

        expected_products[0] = $signed(in0) * $signed(w0);
        expected_products[1] = $signed(in1) * $signed(w1);
        expected_products[2] = $signed(in2) * $signed(w2);
        expected_products[3] = $signed(in3) * $signed(w3);
        expected_products[4] = $signed(in4) * $signed(w4);
        expected_products[5] = $signed(in5) * $signed(w5);
        expected_products[6] = $signed(in6) * $signed(w6);
        expected_products[7] = $signed(in7) * $signed(w7);

        // Enable MAC
        @(posedge clk);
        enable = 1'b1;
        @(posedge clk);
        enable = 1'b0;

        // Wait for valid
        wait(valid);
        @(posedge clk);

        actual_sum = partial_sum;

        // Display results
        $display("Inputs:   %d, %d, %d, %d, %d, %d, %d, %d",
            $signed(in0), $signed(in1), $signed(in2), $signed(in3),
            $signed(in4), $signed(in5), $signed(in6), $signed(in7));
        $display("Weights:  %d, %d, %d, %d, %d, %d, %d, %d",
            $signed(w0), $signed(w1), $signed(w2), $signed(w3),
            $signed(w4), $signed(w5), $signed(w6), $signed(w7));
        $display("Products: %d, %d, %d, %d, %d, %d, %d, %d",
            mac_out[0], mac_out[1], mac_out[2], mac_out[3],
            mac_out[4], mac_out[5], mac_out[6], mac_out[7]);
        $display("Partial sum: %d (expected: %d)", actual_sum, expected_sum);

        if (actual_sum == expected_sum) begin
            $display("✓ PASS");
            test_passed++;
        end else begin
            $display("✗ FAIL");
            test_failed++;
        end
    endtask

    // Hybrid sweep test - sweeps input/weight combinations
    task automatic sweep_mac_range(
        input int min_val,
        input int max_val,
        input string test_name
    );
        logic [7:0] sweep_inputs[0:7];
        logic [7:0] sweep_weights[0:7];
        int expected_sum;
        int actual_sum;
        int i;

        $display("\n=== %s ===", test_name);

        for (int val = min_val; val <= max_val; val++) begin
            // Fill all inputs with same value for sweep
            for (i = 0; i < 8; i++) begin
                sweep_inputs[i] = val;
                sweep_weights[i] = 1;  // Unit weight
            end

            // Calculate expected sum
            expected_sum = $signed(val) * 8;

            // Apply inputs
            for (i = 0; i < 8; i++) begin
                data_in[i] = sweep_inputs[i];
                weight_in[i] = sweep_weights[i];
            end

            // Enable MAC
            @(posedge clk);
            enable = 1'b1;
            @(posedge clk);
            enable = 1'b0;

            // Wait for valid
            wait(valid);
            @(posedge clk);

            actual_sum = partial_sum;

            // Verify (silent mode for sweep - only report failures)
            if (actual_sum != expected_sum) begin
                $display("  FAIL at val=%0d: expected %0d, got %0d", val, expected_sum, actual_sum);
                test_failed++;
            end else begin
                test_passed++;
            end
        end
        $display("  Sweep complete: tested %0d values", max_val - min_val + 1);
    endtask

    // Main test sequence
    initial begin
        logic [7:0] test_inputs[0:7];
        logic [7:0] test_weights[0:7];
        int i;

        $display("========================================");
        $display("MAC Array 8x HYBRID SWEEP Testbench");
        $display("Using: Directed + Boundary + Random");
        $display("========================================");

        // Initialize
        rst_n = 0;
        enable = 0;
        clear_acc = 0;
        for (i = 0; i < 8; i++) begin
            data_in[i] = 0;
            weight_in[i] = 0;
        end

        // Reset
        repeat(10) @(posedge clk);
        rst_n = 1;
        repeat(5) @(posedge clk);

        // PHASE 1: DIRECTED TESTS - Corner cases
        $display("\n=== PHASE 1: DIRECTED CORNER CASES ===");

        // Test 1: All zeros
        $display("\n=== Test 1: All zeros ===");
        test_mac(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, "All zeros");

        // Test 2: All ones
        $display("\n=== Test 2: All ones ===");
        test_mac(1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 8, "All ones (1*1)*8");

        // Test 3: Maximum positive (INT8)
        $display("\n=== Test 3: Maximum positive ===");
        test_mac(127, 127, 127, 127, 127, 127, 127, 127, 1, 1, 1, 1, 1, 1, 1, 1, 1016, "127*1*8 = 1016");

        // Test 4: Minimum negative (INT8)
        $display("\n=== Test 4: Minimum negative ===");
        test_mac(-128, -128, -128, -128, -128, -128, -128, -128, 1, 1, 1, 1, 1, 1, 1, 1, -1024, "-128*1*8 = -1024");

        // Test 5: Mixed signs - cancel to zero
        $display("\n=== Test 5: Mixed signs (zero sum) ===");
        test_mac(10, -10, 20, -20, 5, -5, 15, -15, 1, 1, 1, 1, 1, 1, 1, 1, 0, "Mixed signs cancel to zero");

        // Test 6: Large products (overflow/wrap behavior)
        $display("\n=== Test 6: Large products (overflow) ===");
        // 127*127*8 = 129032, but wraps to -2040 in 16-bit signed
        test_mac(127, 127, 127, 127, 127, 127, 127, 127, 127, 127, 127, 127, 127, 127, 127, 127, -2040, "Max products: 127*127*8 wraps to -2040");

        // Test 7: Negative products
        $display("\n=== Test 7: Negative products ===");
        test_mac(-100, -100, -100, -100, -100, -100, -100, -100, 10, 10, 10, 10, 10, 10, 10, 10, -8000, "Negative products: -100*10*8");

        // Test 8: Clear accumulator
        $display("\n=== Test 8: Clear accumulator ===");
        @(posedge clk);
        clear_acc = 1'b1;
        @(posedge clk);
        clear_acc = 1'b0;
        @(posedge clk);
        test_mac(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, "All zeros after clear");

        // PHASE 2: BOUNDARY SWEEP - Exhaustive at critical values
        $display("\n=== PHASE 2: BOUNDARY SWEEP ===");
        sweep_mac_range(-10, 10, "Sweep around zero (-10 to +10)");
        sweep_mac_range(120, 127, "Sweep near INT8 max (120 to 127)");
        sweep_mac_range(-128, -120, "Sweep near INT8 min (-128 to -120)");

        // PHASE 3: RANDOM SAMPLING - Wide coverage
        $display("\n=== PHASE 3: RANDOM SAMPLING ===");
        repeat(1000) begin
            logic signed [7:0] rand_input, rand_weight;
            logic signed [15:0] expected_result_16;
            logic signed [31:0] temp_sum;

            // Generate random inputs and weights
            for (i = 0; i < 8; i++) begin
                rand_input = $urandom_range(0, 255);
                rand_weight = $urandom_range(0, 255);
                data_in[i] = rand_input;
                weight_in[i] = rand_weight;
                test_inputs[i] = rand_input;
                test_weights[i] = rand_weight;
            end

            // Calculate expected sum - mimics hardware 16-bit wrapping
            temp_sum = 0;
            for (i = 0; i < 8; i++) begin
                temp_sum = temp_sum + ($signed(test_inputs[i]) * $signed(test_weights[i]));
            end
            // Truncate to 16-bit (models hardware wrap-around)
            expected_result_16 = temp_sum[15:0];

            // Enable MAC
            @(posedge clk);
            enable = 1'b1;
            @(posedge clk);
            enable = 1'b0;

            // Wait for valid
            wait(valid);
            @(posedge clk);

            // Verify
            if (partial_sum == expected_result_16) begin
                test_passed++;
            end else begin
                $display("  Random test FAIL: expected %0d, got %0d", expected_result_16, partial_sum);
                test_failed++;
            end
        end
        $display("  Completed 1000 random MAC tests");

        // Summary
        $display("\n========================================");
        $display("Test Summary");
        $display("========================================");
        $display("Tests passed: %0d", test_passed);
        $display("Tests failed: %0d", test_failed);
        $display("Directed tests: 8");
        $display("Boundary sweep: ~46 values");
        $display("Random tests: 1000");
        $display("Grand total: ~1054 tests");

        if (test_failed == 0) begin
            $display("\n✓✓✓ ALL TESTS PASSED ✓✓✓");
        end else begin
            $display("\n✗✗✗ SOME TESTS FAILED ✗✗✗");
        end
        $display("========================================\n");

        repeat(10) @(posedge clk);
        $finish;
    end

    // Timeout
    initial begin
        #100000;
        $display("\n✗✗✗ ERROR: Simulation timeout! ✗✗✗\n");
        $finish;
    end

    // Waveform dump
    initial begin
        $dumpfile("tb_mac_array_8x.vcd");
        $dumpvars(0, tb_mac_array_8x);
    end

endmodule
