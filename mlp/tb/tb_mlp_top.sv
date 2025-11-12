// Testbench for MLP Top-Level
// Integration test for complete MLP accelerator

`timescale 1ns / 1ps

module tb_mlp_top;

    logic clk, rst_n;
    logic start, done, busy;
    logic [15:0] num_inputs, num_outputs;
    logic [15:0] input_addr, weight_addr, bias_addr;
    logic [7:0] input_data, weight_data, bias_data;
    logic input_we, weight_we, bias_we;
    logic [7:0] output_data;
    logic output_valid;

    int test_passed = 0;
    int test_failed = 0;
    logic [7:0] captured_outputs[0:15];
    int output_count;

    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // DUT
    mlp_top dut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .done(done),
        .busy(busy),
        .num_inputs(num_inputs),
        .num_outputs(num_outputs),
        .input_addr(input_addr),
        .input_data(input_data),
        .input_we(input_we),
        .weight_addr(weight_addr),
        .weight_data(weight_data),
        .weight_we(weight_we),
        .bias_addr(bias_addr),
        .bias_data(bias_data),
        .bias_we(bias_we),
        .output_data(output_data),
        .output_valid(output_valid)
    );

    // Capture outputs
    always @(posedge clk) begin
        if (output_valid) begin
            captured_outputs[output_count] = output_data;
            $display("[%0t] Output[%0d] = %0d (0x%02h)", $time, output_count, output_data, output_data);
            output_count++;
        end
    end

    // Task to load input
    task load_input(input int addr, input logic [7:0] data);
        @(posedge clk);
        input_addr = addr;
        input_data = data;
        input_we = 1'b1;
        @(posedge clk);
        input_we = 1'b0;
    endtask

    // Task to load weight
    task load_weight(input int addr, input logic [7:0] data);
        @(posedge clk);
        weight_addr = addr;
        weight_data = data;
        weight_we = 1'b1;
        @(posedge clk);
        weight_we = 1'b0;
    endtask

    // Task to load bias
    task load_bias(input int addr, input logic [7:0] data);
        @(posedge clk);
        bias_addr = addr;
        bias_data = data;
        bias_we = 1'b1;
        @(posedge clk);
        bias_we = 1'b0;
    endtask

    initial begin
        $display("========================================");
        $display("MLP Top-Level Integration Testbench");
        $display("========================================");

        // Initialize
        rst_n = 0;
        start = 0;
        num_inputs = 8;
        num_outputs = 4;
        input_addr = 0; input_data = 0; input_we = 0;
        weight_addr = 0; weight_data = 0; weight_we = 0;
        bias_addr = 0; bias_data = 0; bias_we = 0;
        output_count = 0;

        repeat(10) @(posedge clk);
        rst_n = 1;
        repeat(5) @(posedge clk);

        // Test Case 1: Small MLP layer (8 inputs, 4 outputs)
        $display("\n=== Test Case 1: 8 inputs → 4 outputs ===");
        $display("Configuration: 8 × 4 fully-connected layer");

        // Load inputs (8 values: 1.0, 2.0, ..., 8.0 in Q4.4)
        $display("\nLoading inputs...");
        for (int i = 0; i < 8; i++) begin
            load_input(i, (i + 1) << 4);  // Q4.4 format
            $display("  Input[%0d] = %0d.0 → 0x%02h", i, i+1, (i+1)<<4);
        end

        // Load weights (8×4 = 32 values)
        $display("\nLoading weights...");
        for (int out = 0; out < 4; out++) begin
            for (int in = 0; in < 8; in++) begin
                int addr = out * 8 + in;
                logic [7:0] weight_val;

                // Simple pattern: all weights = 0.5
                weight_val = 8'h08;  // 0.5 in Q4.4

                load_weight(addr, weight_val);
            end
            $display("  Loaded weights for output neuron %0d", out);
        end

        // Load biases (4 values)
        $display("\nLoading biases...");
        for (int i = 0; i < 4; i++) begin
            logic [7:0] bias_val = 8'h01;  // 1.0 bias
            load_bias(i, bias_val);
            $display("  Bias[%0d] = 0x%02h", i, bias_val);
        end

        // Start computation
        $display("\n[%0t] Starting computation...", $time);
        @(posedge clk);
        start = 1'b1;
        @(posedge clk);
        start = 1'b0;

        // Wait for busy signal
        wait(busy);
        $display("[%0t] MLP is busy computing...", $time);

        // Wait for done
        wait(done);
        $display("[%0t] Computation complete!", $time);

        repeat(10) @(posedge clk);

        // Verify outputs
        $display("\n=== Verification ===");
        if (output_count == num_outputs) begin
            $display("✓ Received expected number of outputs: %0d", output_count);
            test_passed++;
        end else begin
            $display("✗ Output count mismatch: Expected %0d, got %0d", num_outputs, output_count);
            test_failed++;
        end

        // Check if outputs are reasonable (non-zero)
        for (int i = 0; i < output_count; i++) begin
            if (captured_outputs[i] != 8'h00) begin
                $display("✓ Output[%0d] = 0x%02h (non-zero, valid)", i, captured_outputs[i]);
                test_passed++;
            end else begin
                $display("  Output[%0d] = 0x%02h (zero, may indicate issue)", i, captured_outputs[i]);
            end
        end

        // Test Case 2: Different configuration
        $display("\n=== Test Case 2: 16 inputs → 2 outputs ===");
        output_count = 0;

        // Reset
        rst_n = 0;
        repeat(5) @(posedge clk);
        rst_n = 1;
        repeat(5) @(posedge clk);

        num_inputs = 16;
        num_outputs = 2;

        // Load inputs (all 1.0)
        $display("\nLoading 16 inputs...");
        for (int i = 0; i < 16; i++) begin
            load_input(i, 8'h10);  // 1.0
        end

        // Load weights (16×2 = 32 values, all 0.5)
        $display("Loading weights...");
        for (int out = 0; out < 2; out++) begin
            for (int in = 0; in < 16; in++) begin
                load_weight(out * 16 + in, 8'h08);  // 0.5
            end
        end

        // Load biases
        $display("Loading biases...");
        for (int i = 0; i < 2; i++) begin
            load_bias(i, 8'h00);  // No bias
        end

        // Start computation
        $display("\n[%0t] Starting computation...", $time);
        @(posedge clk);
        start = 1'b1;
        @(posedge clk);
        start = 1'b0;

        wait(done);
        $display("[%0t] Computation complete!", $time);
        repeat(10) @(posedge clk);

        $display("\n=== Test Case 2 Results ===");
        if (output_count == 2) begin
            $display("✓ Received 2 outputs");
            test_passed++;
        end else begin
            $display("✗ Expected 2 outputs, got %0d", output_count);
            test_failed++;
        end

        // Summary
        $display("\n========================================");
        $display("Test Summary");
        $display("========================================");
        $display("Tests passed: %0d", test_passed);
        $display("Tests failed: %0d", test_failed);

        if (test_failed == 0 && output_count > 0) begin
            $display("\n✓✓✓ ALL TESTS PASSED ✓✓✓");
        end else begin
            $display("\n✗✗✗ SOME TESTS FAILED ✗✗✗");
        end
        $display("========================================\n");

        repeat(20) @(posedge clk);
        $finish;
    end

    initial begin
        #1000000;  // 1ms timeout
        $display("\n✗✗✗ ERROR: Simulation timeout! ✗✗✗\n");
        $finish;
    end

    initial begin
        $dumpfile("tb_mlp_top.vcd");
        $dumpvars(0, tb_mlp_top);
    end

endmodule
