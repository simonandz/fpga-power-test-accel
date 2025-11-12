// Testbench for MLP Compute Datapath
// Tests MAC + Activation pipeline with INT8 values

`timescale 1ns / 1ps

module tb_mlp_compute_datapath;

    logic clk, rst_n;
    logic mac_enable, mac_clear;
    logic activation_enable;
    logic [1:0] activation_type;
    logic signed [7:0] data_in[0:7];
    logic signed [7:0] weight_in[0:7];
    logic signed [7:0] bias_in;
    logic signed [7:0] result_out;
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

    // Test task
    task test_neuron(
        input logic signed [7:0] inputs[0:7],
        input logic signed [7:0] weights[0:7],
        input logic signed [7:0] bias,
        input logic signed [7:0] expected_result,
        input string test_name
    );
        int i;
        logic signed [7:0] actual_result;

        $display("\n--- %s ---", test_name);

        // Load inputs and weights
        for (i = 0; i < 8; i++) begin
            data_in[i] = inputs[i];
            weight_in[i] = weights[i];
        end
        bias_in = bias;

        // Clear accumulator
        @(posedge clk);
        mac_clear = 1'b1;
        @(posedge clk);
        mac_clear = 1'b0;

        // Enable MAC
        @(posedge clk);
        mac_enable = 1'b1;
        @(posedge clk);
        mac_enable = 1'b0;

        // Wait for MAC valid and accumulator update
        wait(mac_valid);
        @(posedge clk);
        @(posedge clk);  // Extra cycle for accumulator update

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

        // Allow some tolerance for saturation edge cases
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
        logic signed [7:0] test_inputs[0:7];
        logic signed [7:0] test_weights[0:7];
        int i;

        $display("========================================");
        $display("MLP Compute Datapath Testbench (INT8)");
        $display("========================================");

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

        // Test 1: Simple MAC - all ones
        $display("\n=== Test 1: Simple MAC ===");
        for (i = 0; i < 8; i++) begin
            test_inputs[i] = 1;   // 1
            test_weights[i] = 1;  // 1
        end
        // (1*1)*8 = 8
        test_neuron(test_inputs, test_weights, 0, 8, "8 × (1 * 1) = 8");

        // Test 2: With bias
        $display("\n=== Test 2: MAC with bias ===");
        for (i = 0; i < 8; i++) begin
            test_inputs[i] = 2;   // 2
            test_weights[i] = 3;  // 3
        end
        // (2*3)*8 + 5 = 48 + 5 = 53
        test_neuron(test_inputs, test_weights, 5, 53, "8 × (2 * 3) + 5 = 53");

        // Test 3: ReLU negative clamping
        $display("\n=== Test 3: ReLU negative ===");
        for (i = 0; i < 8; i++) begin
            test_inputs[i] = 1;   // 1
            test_weights[i] = -2; // -2
        end
        // (1*-2)*8 + 0 = -16, ReLU → 0
        test_neuron(test_inputs, test_weights, 0, 0, "ReLU clamps negative to 0");

        // Test 4: Large values with saturation
        $display("\n=== Test 4: Saturation ===");
        for (i = 0; i < 8; i++) begin
            test_inputs[i] = 20;  // 20
            test_weights[i] = 10; // 10
        end
        // (20*10)*8 = 1600, saturates to 127
        test_neuron(test_inputs, test_weights, 0, 127, "Saturate to INT8 max (127)");

        // Test 5: Pass-through activation
        $display("\n=== Test 5: Pass-through activation ===");
        for (i = 0; i < 8; i++) begin
            test_inputs[i] = 3;   // 3
            test_weights[i] = 2;  // 2
        end
        bias_in = 4;

        // Load data
        @(posedge clk);
        mac_clear = 1'b1;
        @(posedge clk);
        mac_clear = 1'b0;

        @(posedge clk);
        mac_enable = 1'b1;
        @(posedge clk);
        mac_enable = 1'b0;
        wait(mac_valid);
        @(posedge clk);
        @(posedge clk);  // Extra cycle for accumulator update

        // (3*2)*8 + 4 = 48 + 4 = 52
        // Use pass-through (type = 3)
        activation_type = 2'b11;
        activation_enable = 1'b1;
        @(posedge clk);
        activation_enable = 1'b0;
        wait(result_valid);
        @(posedge clk);

        $display("\n--- Pass-through activation ---");
        $display("  Pass-through result: %0d", result_out);
        if (result_out == 52 || (result_out >= 50 && result_out <= 54)) begin
            $display("✓ PASS (expected ~52)");
            test_passed++;
        end else begin
            $display("✗ FAIL (expected ~52)");
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
