// Testbench for Activation Unit
// Tests ReLU, tanh, sigmoid activations
// Uses INT8/INT16 integer values

`timescale 1ns / 1ps

module tb_activation_unit;

    logic clk, rst_n;
    logic [1:0] activation_type;
    logic enable;
    logic signed [15:0] data_in;
    logic signed [7:0] data_out;
    logic valid;

    int test_passed = 0;
    int test_failed = 0;

    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // DUT
    activation_unit dut (
        .clk(clk),
        .rst_n(rst_n),
        .activation_type(activation_type),
        .enable(enable),
        .data_in(data_in),
        .data_out(data_out),
        .valid(valid)
    );

    // Test task
    task test_activation(
        input [1:0] act_type,
        input signed [15:0] input_val,
        input signed [7:0] expected_out,
        input string test_name
    );
        $display("--- %s ---", test_name);
        $display("Input: %0d, Expected: %0d", $signed(input_val), $signed(expected_out));

        activation_type = act_type;
        data_in = input_val;
        @(posedge clk);
        enable = 1'b1;
        @(posedge clk);
        enable = 1'b0;

        wait(valid);
        @(posedge clk);

        $display("Output: %0d", $signed(data_out));

        // Allow some tolerance for approximations
        if (data_out == expected_out ||
            ($signed(data_out) >= $signed(expected_out) - 2 &&
             $signed(data_out) <= $signed(expected_out) + 2)) begin
            $display("✓ PASS\n");
            test_passed++;
        end else begin
            $display("✗ FAIL\n");
            test_failed++;
        end
    endtask

    initial begin
        $display("========================================");
        $display("Activation Unit Testbench (INT8)");
        $display("========================================");

        rst_n = 0;
        enable = 0;
        activation_type = 0;
        data_in = 0;

        repeat(10) @(posedge clk);
        rst_n = 1;
        repeat(5) @(posedge clk);

        // Test ReLU (type = 2'b00)
        $display("\n=== Testing ReLU ===");
        test_activation(2'b00, 50, 50, "ReLU: Positive value");
        test_activation(2'b00, -50, 0, "ReLU: Negative value");
        test_activation(2'b00, 0, 0, "ReLU: Zero");
        test_activation(2'b00, 200, 127, "ReLU: Large positive (saturate)");
        test_activation(2'b00, -200, 0, "ReLU: Large negative");

        // Test tanh (type = 2'b01)
        $display("\n=== Testing tanh ===");
        test_activation(2'b01, 0, 0, "tanh: Zero");
        test_activation(2'b01, 32, 32, "tanh: Small positive (linear)");
        test_activation(2'b01, -32, -32, "tanh: Small negative (linear)");
        test_activation(2'b01, 100, 64, "tanh: Large positive (saturate)");
        test_activation(2'b01, -100, -64, "tanh: Large negative (saturate)");

        // Test Sigmoid (type = 2'b10)
        $display("\n=== Testing Sigmoid ===");
        test_activation(2'b10, 0, 64, "Sigmoid: Zero (should be ~0.5 * 128 = 64)");
        test_activation(2'b10, 64, 80, "Sigmoid: Positive");
        test_activation(2'b10, -64, 48, "Sigmoid: Negative");
        test_activation(2'b10, 200, 127, "Sigmoid: Large positive (saturate)");
        test_activation(2'b10, -200, 0, "Sigmoid: Large negative (saturate)");

        // Test None (type = 2'b11)
        $display("\n=== Testing None (pass-through) ===");
        test_activation(2'b11, 50, 50, "None: Positive");
        test_activation(2'b11, -50, -50, "None: Negative");
        test_activation(2'b11, 200, 127, "None: Saturate positive");
        test_activation(2'b11, -200, -128, "None: Saturate negative");

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
        $dumpfile("tb_activation_unit.vcd");
        $dumpvars(0, tb_activation_unit);
    end

endmodule
