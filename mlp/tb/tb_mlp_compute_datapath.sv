// Testbench for MLP Compute Datapath
// Tests MAC array + activation pipeline

`timescale 1ns / 1ps

import fixed_point_pkg::*;

module tb_mlp_compute_datapath;

    logic clk, rst_n;
    logic mac_enable, mac_clear;
    logic activation_enable;
    logic [1:0] activation_type;
    logic [7:0] data_in[0:7];
    logic [7:0] weight_in[0:7];
    logic signed [7:0] bias_in;
    logic [7:0] result_out;
    logic result_valid;
    logic signed [15:0] accumulator;
    logic mac_valid;

    int test_passed = 0;
    int test_failed = 0;

    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // DUT
    mlp_compute_datapath dut (
        .clk(clk),
        .rst_n(rst_n),
        .mac_enable(mac_enable),
        .mac_clear(mac_clear),
        .activation_enable(activation_enable),
        .activation_type(activation_type),
        .data_in(data_in),
        .weight_in(weight_in),
        .bias_in(bias_in),
        .result_out(result_out),
        .result_valid(result_valid),
        .accumulator(accumulator),
        .mac_valid(mac_valid)
    );

    // Test task for full MAC + activation
    task test_neuron(
        input logic [7:0] inputs[0:7],
        input logic [7:0] weights[0:7],
        input logic signed [7:0] bias,
        input int expected_result,
        input string test_name
    );
        int i;
        int actual_result;

        $display("\n--- %s ---", test_name);

        // Clear accumulator
        @(posedge clk);
        mac_clear = 1'b1;
        @(posedge clk);
        mac_clear = 1'b0;

        // Load data
        for (i = 0; i < 8; i++) begin
            data_in[i] = inputs[i];
            weight_in[i] = weights[i];
        end
        bias_in = bias;

        // Enable MAC
        @(posedge clk);
        mac_enable = 1'b1;
        @(posedge clk);
        mac_enable = 1'b0;

        // Wait for MAC valid and accumulator update
        wait(mac_valid);
        @(posedge clk);
        @(posedge clk);  // Extra cycle to ensure accumulator has updated

        $display("  Accumulator: %0d (0x%04h)", accumulator, accumulator);
        $display("  Bias: %0d (0x%02h)", bias, bias);

        // Enable activation (ReLU)
        activation_type = 2'b00;  // ReLU
        activation_enable = 1'b1;
        @(posedge clk);
        activation_enable = 1'b0;

        // Wait for result
        wait(result_valid);
        @(posedge clk);

        actual_result = result_out;
        $display("  Result: %0d (0x%02h), Expected: %0d (0x%02h)",
            actual_result, actual_result, expected_result, expected_result);

        // Allow some tolerance for Q4.4 rounding
        if (actual_result == expected_result ||
            (actual_result >= expected_result - 2 && actual_result <= expected_result + 2)) begin
            $display("✓ PASS");
            test_passed++;
        end else begin
            $display("✗ FAIL");
            test_failed++;
        end
    endtask

    initial begin
        logic [7:0] test_inputs[0:7];
        logic [7:0] test_weights[0:7];
        int i;

        $display("========================================");
        $display("MLP Compute Datapath Testbench");
        $display("========================================");

        // Initialize
        rst_n = 0;
        mac_enable = 0;
        mac_clear = 0;
        activation_enable = 0;
        activation_type = 0;
        bias_in = 0;
        for (i = 0; i < 8; i++) begin
            data_in[i] = 0;
            weight_in[i] = 0;
        end

        repeat(10) @(posedge clk);
        rst_n = 1;
        repeat(5) @(posedge clk);

        // Test 1: All ones, no bias
        $display("\n=== Test 1: Simple MAC ===");
        for (i = 0; i < 8; i++) begin
            test_inputs[i] = 8'h10;   // 1.0 in Q4.4
            test_weights[i] = 8'h10;  // 1.0 in Q4.4
        end
        // (1*1)*8 = 8 = 0x0800 in Q8.8, shifted to 0x80 in Q4.4
        test_neuron(test_inputs, test_weights, 8'h00, 8'h80, "8 × (1.0 * 1.0) = 8.0");

        // Test 2: With bias
        $display("\n=== Test 2: MAC with bias ===");
        for (i = 0; i < 8; i++) begin
            test_inputs[i] = 8'h10;   // 1.0
            test_weights[i] = 8'h10;  // 1.0
        end
        // (1*1)*8 + 1 = 9 = 0x0900 in Q8.8, shifted to 0x90 in Q4.4
        // Bias is stored as integer, so 1 becomes 0x01
        test_neuron(test_inputs, test_weights, 8'h10, 8'h90, "8 × (1.0 * 1.0) + 1.0 = 9.0");

        // Test 3: ReLU negative clamping
        $display("\n=== Test 3: ReLU negative ===");
        for (i = 0; i < 8; i++) begin
            test_inputs[i] = 8'h10;   // 1.0
            test_weights[i] = 8'hF0;  // -1.0
        end
        // (1*-1)*8 + 0 = -8, ReLU → 0
        test_neuron(test_inputs, test_weights, 8'h00, 8'h00, "ReLU clamps negative to 0");

        // Test 4: Accumulation over multiple MAC ops
        $display("\n=== Test 4: Multiple MAC accumulation ===");

        // First MAC
        for (i = 0; i < 8; i++) begin
            test_inputs[i] = 8'h10;   // 1.0
            test_weights[i] = 8'h10;  // 1.0
        end
        bias_in = 8'h00;

        @(posedge clk);
        mac_clear = 1'b1;
        @(posedge clk);
        mac_clear = 1'b0;

        for (i = 0; i < 8; i++) begin
            data_in[i] = test_inputs[i];
            weight_in[i] = test_weights[i];
        end

        @(posedge clk);
        mac_enable = 1'b1;
        @(posedge clk);
        mac_enable = 1'b0;
        wait(mac_valid);
        @(posedge clk);
        @(posedge clk);  // Extra cycle for accumulator update

        $display("  First MAC accumulator: %0d", accumulator);

        // Second MAC (should accumulate)
        for (i = 0; i < 8; i++) begin
            data_in[i] = test_inputs[i];
            weight_in[i] = test_weights[i];
        end

        @(posedge clk);
        mac_enable = 1'b1;
        @(posedge clk);
        mac_enable = 1'b0;
        wait(mac_valid);
        @(posedge clk);
        @(posedge clk);  // Extra cycle for accumulator update

        $display("  Second MAC accumulator: %0d (should be doubled)", accumulator);

        // Activate
        activation_type = 2'b00;
        activation_enable = 1'b1;
        @(posedge clk);
        activation_enable = 1'b0;
        wait(result_valid);
        @(posedge clk);

        // 16.0 should saturate to max Q4.4 value (0xFF = 15.9375)
        if (result_out == 8'hFF) begin
            $display("  Result: 0x%02h ✓ PASS (saturated to max)", result_out);
            test_passed++;
        end else begin
            $display("  Result: 0x%02h (expected 0xFF - saturated) ✗ FAIL", result_out);
            test_failed++;
        end

        // Test 5: Different activation types
        $display("\n=== Test 5: Pass-through activation ===");
        for (i = 0; i < 8; i++) begin
            test_inputs[i] = 8'h20;   // 2.0
            test_weights[i] = 8'h10;  // 1.0
        end

        @(posedge clk);
        mac_clear = 1'b1;
        @(posedge clk);
        mac_clear = 1'b0;

        for (i = 0; i < 8; i++) begin
            data_in[i] = test_inputs[i];
            weight_in[i] = test_weights[i];
        end
        bias_in = 8'h00;

        @(posedge clk);
        mac_enable = 1'b1;
        @(posedge clk);
        mac_enable = 1'b0;
        wait(mac_valid);
        @(posedge clk);
        @(posedge clk);  // Extra cycle for accumulator update

        // Use pass-through (type = 3)
        activation_type = 2'b11;
        activation_enable = 1'b1;
        @(posedge clk);
        activation_enable = 1'b0;
        wait(result_valid);
        @(posedge clk);

        $display("  Pass-through result: 0x%02h", result_out);
        if (result_out > 0) begin
            $display("✓ PASS (non-zero)");
            test_passed++;
        end else begin
            $display("✗ FAIL");
            test_failed++;
        end

        $display("\n========================================");
        $display("Test Summary");
        $display("========================================");
        $display("Tests passed: %0d", test_passed);
        $display("Tests failed: %0d", test_failed);

        if (test_failed == 0) begin
            $display("\n✓✓✓ ALL TESTS PASSED ✓✓✓");
        end else begin
            $display("\n✗✗✗ SOME TESTS FAILED ✗✗✗");
        end
        $display("========================================\n");

        repeat(10) @(posedge clk);
        $finish;
    end

    initial begin
        #100000;
        $display("\n✗✗✗ ERROR: Simulation timeout! ✗✗✗\n");
        $finish;
    end

    initial begin
        $dumpfile("tb_mlp_compute_datapath.vcd");
        $dumpvars(0, tb_mlp_compute_datapath);
    end

endmodule
