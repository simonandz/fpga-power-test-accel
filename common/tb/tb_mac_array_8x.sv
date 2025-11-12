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

    // Test task
    task test_mac(
        input logic [7:0] inputs[0:7],
        input logic [7:0] weights[0:7],
        input int expected_sum,
        input string test_name
    );
        int i;
        logic signed [15:0] expected_products[0:7];
        int actual_sum;

        $display("\n--- %s ---", test_name);

        // Load inputs
        for (i = 0; i < 8; i++) begin
            data_in[i] = inputs[i];
            weight_in[i] = weights[i];
            expected_products[i] = $signed(inputs[i]) * $signed(weights[i]);
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

        // Display results
        $display("Inputs:   %d, %d, %d, %d, %d, %d, %d, %d",
            $signed(inputs[0]), $signed(inputs[1]), $signed(inputs[2]), $signed(inputs[3]),
            $signed(inputs[4]), $signed(inputs[5]), $signed(inputs[6]), $signed(inputs[7]));
        $display("Weights:  %d, %d, %d, %d, %d, %d, %d, %d",
            $signed(weights[0]), $signed(weights[1]), $signed(weights[2]), $signed(weights[3]),
            $signed(weights[4]), $signed(weights[5]), $signed(weights[6]), $signed(weights[7]));
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

    // Main test sequence
    initial begin
        logic [7:0] test_inputs[0:7];
        logic [7:0] test_weights[0:7];
        int i;

        $display("========================================");
        $display("MAC Array 8x Testbench");
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

        // Test 1: All ones
        $display("\n=== Test 1: All ones ===");
        for (i = 0; i < 8; i++) begin
            test_inputs[i] = 8'h01;   // 1
            test_weights[i] = 8'h01;  // 1
        end
        test_mac(test_inputs, test_weights, 8, "All ones (1*1)*8");

        // Test 2: Positive values
        $display("\n=== Test 2: Positive values ===");
        for (i = 0; i < 8; i++) begin
            test_inputs[i] = 8'h02;   // 2
            test_weights[i] = 8'h03;  // 3
        end
        test_mac(test_inputs, test_weights, 48, "2*3*8 = 48");

        // Test 3: Mixed signs
        $display("\n=== Test 3: Mixed signs ===");
        test_inputs[0] = 8'h02;   // 2
        test_inputs[1] = 8'hFE;   // -2
        test_inputs[2] = 8'h03;   // 3
        test_inputs[3] = 8'hFD;   // -3
        test_inputs[4] = 8'h01;   // 1
        test_inputs[5] = 8'hFF;   // -1
        test_inputs[6] = 8'h04;   // 4
        test_inputs[7] = 8'hFC;   // -4

        for (i = 0; i < 8; i++) begin
            test_weights[i] = 8'h02;  // 2
        end
        // 2*2 + (-2)*2 + 3*2 + (-3)*2 + 1*2 + (-1)*2 + 4*2 + (-4)*2
        // = 4 - 4 + 6 - 6 + 2 - 2 + 8 - 8 = 0
        test_mac(test_inputs, test_weights, 0, "Mixed signs sum to zero");

        // Test 4: Sequential values
        $display("\n=== Test 4: Sequential values ===");
        for (i = 0; i < 8; i++) begin
            test_inputs[i] = i + 1;   // 1,2,3,4,5,6,7,8
            test_weights[i] = 8'h01;  // 1
        end
        // 1+2+3+4+5+6+7+8 = 36
        test_mac(test_inputs, test_weights, 36, "Sum of 1 to 8");

        // Test 5: Clear accumulator
        $display("\n=== Test 5: Clear accumulator ===");
        @(posedge clk);
        clear_acc = 1'b1;
        @(posedge clk);
        clear_acc = 1'b0;
        @(posedge clk);

        for (i = 0; i < 8; i++) begin
            test_inputs[i] = 8'h00;
            test_weights[i] = 8'h00;
        end
        test_mac(test_inputs, test_weights, 0, "All zeros after clear");

        // Test 6: Large values
        $display("\n=== Test 6: Large values ===");
        for (i = 0; i < 8; i++) begin
            test_inputs[i] = 8'h10;   // 16
            test_weights[i] = 8'h10;  // 16
        end
        // 16*16*8 = 2048
        test_mac(test_inputs, test_weights, 2048, "Large values: 16*16*8");

        // Summary
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
