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

    // Debug outputs (unused in TB but required for port connection)
    logic [15:0] output_wr_addr;
    logic [7:0]  output_wr_data;
    logic        output_wr_en;

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
        .output_valid(output_valid),
        .output_wr_addr(output_wr_addr),
        .output_wr_data(output_wr_data),
        .output_wr_en(output_wr_en)
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

    // Task to run a complete test case
    task run_test(
        input string test_name,
        input int n_inputs,
        input int n_outputs,
        input logic [7:0] inputs[],
        input logic [7:0] weights[],
        input logic [7:0] biases[],
        input logic [7:0] expected[]
    );
        int i, j;
        logic test_ok;

        $display("\n=== %s ===", test_name);
        $display("Configuration: %0d inputs × %0d outputs", n_inputs, n_outputs);

        // Reset
        rst_n = 0;
        output_count = 0;
        repeat(5) @(posedge clk);
        rst_n = 1;
        repeat(5) @(posedge clk);

        num_inputs = n_inputs;
        num_outputs = n_outputs;

        // Load inputs
        for (i = 0; i < n_inputs; i++) begin
            load_input(i, inputs[i]);
        end

        // Load weights (row-major: output × input)
        for (i = 0; i < n_outputs * n_inputs; i++) begin
            load_weight(i, weights[i]);
        end

        // Load biases
        for (i = 0; i < n_outputs; i++) begin
            load_bias(i, biases[i]);
        end

        // Start computation
        $display("[%0t] Starting computation...", $time);
        @(posedge clk);
        start = 1'b1;
        @(posedge clk);
        start = 1'b0;

        // Wait for done
        wait(done);
        $display("[%0t] Computation complete!", $time);
        repeat(5) @(posedge clk);

        // Verify outputs
        test_ok = 1;
        if (output_count != n_outputs) begin
            $display("  FAIL: Expected %0d outputs, got %0d", n_outputs, output_count);
            test_ok = 0;
        end

        for (i = 0; i < output_count && i < n_outputs; i++) begin
            if (captured_outputs[i] == expected[i]) begin
                $display("  PASS: Output[%0d] = 0x%02h (expected 0x%02h)", i, captured_outputs[i], expected[i]);
            end else begin
                $display("  FAIL: Output[%0d] = 0x%02h (expected 0x%02h)", i, captured_outputs[i], expected[i]);
                test_ok = 0;
            end
        end

        if (test_ok) begin
            test_passed++;
            $display("  >>> TEST PASSED <<<");
        end else begin
            test_failed++;
            $display("  >>> TEST FAILED <<<");
        end
    endtask

    initial begin
        // Test data arrays
        logic [7:0] inputs_t1[8];
        logic [7:0] weights_t1[32];
        logic [7:0] biases_t1[4];
        logic [7:0] expected_t1[4];

        logic [7:0] inputs_t2[8];
        logic [7:0] weights_t2[32];
        logic [7:0] biases_t2[4];
        logic [7:0] expected_t2[4];

        logic [7:0] inputs_t3[8];
        logic [7:0] weights_t3[32];
        logic [7:0] biases_t3[4];
        logic [7:0] expected_t3[4];

        logic [7:0] inputs_t4[8];
        logic [7:0] weights_t4[16];
        logic [7:0] biases_t4[2];
        logic [7:0] expected_t4[2];

        logic [7:0] inputs_t5[8];
        logic [7:0] weights_t5[32];
        logic [7:0] biases_t5[4];
        logic [7:0] expected_t5[4];

        int i;

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

        //======================================================================
        // Test 1: Basic sum - inputs [1,2,3,4,5,6,7,8], weights all 1, bias 0
        // Expected: 1+2+3+4+5+6+7+8 = 36 (0x24) for each neuron
        //======================================================================
        for (i = 0; i < 8; i++) inputs_t1[i] = i + 1;
        for (i = 0; i < 32; i++) weights_t1[i] = 8'h01;
        for (i = 0; i < 4; i++) biases_t1[i] = 8'h00;
        for (i = 0; i < 4; i++) expected_t1[i] = 8'h24;  // 36

        run_test("Test 1: Basic Sum (w=1, b=0)", 8, 4, inputs_t1, weights_t1, biases_t1, expected_t1);

        //======================================================================
        // Test 2: With bias - inputs [1,2,3,4,5,6,7,8], weights all 1, bias 10
        // Expected: 36 + 10 = 46 (0x2E) for each neuron
        //======================================================================
        for (i = 0; i < 8; i++) inputs_t2[i] = i + 1;
        for (i = 0; i < 32; i++) weights_t2[i] = 8'h01;
        for (i = 0; i < 4; i++) biases_t2[i] = 8'h0A;  // 10
        for (i = 0; i < 4; i++) expected_t2[i] = 8'h2E;  // 46

        run_test("Test 2: With Bias (w=1, b=10)", 8, 4, inputs_t2, weights_t2, biases_t2, expected_t2);

        //======================================================================
        // Test 3: Scaled weights - inputs [1,2,3,4,5,6,7,8], weights all 2, bias 0
        // Expected: 2*(1+2+3+4+5+6+7+8) = 72 (0x48) for each neuron
        //======================================================================
        for (i = 0; i < 8; i++) inputs_t3[i] = i + 1;
        for (i = 0; i < 32; i++) weights_t3[i] = 8'h02;
        for (i = 0; i < 4; i++) biases_t3[i] = 8'h00;
        for (i = 0; i < 4; i++) expected_t3[i] = 8'h48;  // 72

        run_test("Test 3: Scaled Weights (w=2, b=0)", 8, 4, inputs_t3, weights_t3, biases_t3, expected_t3);

        //======================================================================
        // Test 4: Different layer size - 8 inputs, 2 outputs
        // Inputs all 1, weights all 1, bias 0
        // Expected: 1*8 = 8 (0x08) for each neuron
        //======================================================================
        for (i = 0; i < 8; i++) inputs_t4[i] = 8'h01;
        for (i = 0; i < 16; i++) weights_t4[i] = 8'h01;
        for (i = 0; i < 2; i++) biases_t4[i] = 8'h00;
        for (i = 0; i < 2; i++) expected_t4[i] = 8'h08;  // 8

        run_test("Test 4: Different Size (8x2)", 8, 2, inputs_t4, weights_t4, biases_t4, expected_t4);

        //======================================================================
        // Test 5: ReLU test - negative result should clamp to 0
        // Use signed interpretation: inputs [1,1,1,1,1,1,1,1], weights [-1,-1,-1,-1,-1,-1,-1,-1], bias 0
        // Sum = -8, ReLU(-8) = 0
        //======================================================================
        for (i = 0; i < 8; i++) inputs_t5[i] = 8'h01;     // 1
        for (i = 0; i < 32; i++) weights_t5[i] = 8'hFF;   // -1 in signed
        for (i = 0; i < 4; i++) biases_t5[i] = 8'h00;
        for (i = 0; i < 4; i++) expected_t5[i] = 8'h00;   // ReLU clamps to 0

        run_test("Test 5: ReLU Clamp (negative -> 0)", 8, 4, inputs_t5, weights_t5, biases_t5, expected_t5);

        //======================================================================
        // Summary
        //======================================================================
        $display("\n========================================");
        $display("Test Summary");
        $display("========================================");
        $display("Tests passed: %0d", test_passed);
        $display("Tests failed: %0d", test_failed);

        if (test_failed == 0) begin
            $display("\n*** ALL TESTS PASSED ***");
        end else begin
            $display("\n*** SOME TESTS FAILED ***");
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
