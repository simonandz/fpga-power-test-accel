// Testbench for Fixed-Point Package
// Tests all Q4.4 utility functions

`timescale 1ns / 1ps

import fixed_point_pkg::*;

module tb_fixed_point_pkg;

    int test_passed = 0;
    int test_failed = 0;

    // Test int_to_q44
    task test_int_to_q44();
        logic [7:0] result;
        $display("\n=== Testing int_to_q44 ===");

        result = int_to_q44(1);
        if (result == 8'h10) begin
            $display("PASS: int_to_q44(1) = 0x%02h", result);
            test_passed++;
        end else begin
            $display("FAIL: int_to_q44(1) = 0x%02h (expected 0x10)", result);
            test_failed++;
        end

        result = int_to_q44(5);
        if (result == 8'h50) begin
            $display("PASS: int_to_q44(5) = 0x%02h", result);
            test_passed++;
        end else begin
            $display("FAIL: int_to_q44(5) = 0x%02h (expected 0x50)", result);
            test_failed++;
        end
    endtask

    // Test q44_to_int
    task test_q44_to_int();
        int result;
        $display("\n=== Testing q44_to_int ===");

        result = q44_to_int(8'h10);
        if (result == 1) begin
            $display("PASS: q44_to_int(0x10) = %0d", result);
            test_passed++;
        end else begin
            $display("FAIL: q44_to_int(0x10) = %0d (expected 1)", result);
            test_failed++;
        end

        result = q44_to_int(8'h50);
        if (result == 5) begin
            $display("PASS: q44_to_int(0x50) = %0d", result);
            test_passed++;
        end else begin
            $display("FAIL: q44_to_int(0x50) = %0d (expected 5)", result);
            test_failed++;
        end
    endtask

    // Test add_bias_q44
    task test_add_bias_q44();
        logic signed [15:0] result;
        $display("\n=== Testing add_bias_q44 ===");

        result = add_bias_q44(16'h0100, 8'h01);
        if (result == 16'h0110) begin
            $display("PASS: add_bias_q44(0x0100, 0x01) = 0x%04h", result);
            test_passed++;
        end else begin
            $display("FAIL: add_bias_q44(0x0100, 0x01) = 0x%04h (expected 0x0110)", result);
            test_failed++;
        end
    endtask

    // Test saturate_to_q44
    task test_saturate_to_q44();
        logic [7:0] result;
        $display("\n=== Testing saturate_to_q44 ===");

        // Normal case
        result = saturate_to_q44(16'h0100);
        if (result == 8'h10) begin
            $display("PASS: saturate_to_q44(0x0100) = 0x%02h", result);
            test_passed++;
        end else begin
            $display("FAIL: saturate_to_q44(0x0100) = 0x%02h (expected 0x10)", result);
            test_failed++;
        end

        // Overflow case
        result = saturate_to_q44(16'h1000);
        if (result == 8'hFF) begin
            $display("PASS: saturate_to_q44(0x1000) = 0x%02h (saturated)", result);
            test_passed++;
        end else begin
            $display("FAIL: saturate_to_q44(0x1000) = 0x%02h (expected 0xFF)", result);
            test_failed++;
        end

        // Underflow case
        result = saturate_to_q44(-16'h0100);
        if (result == 8'h00) begin
            $display("PASS: saturate_to_q44(-0x0100) = 0x%02h (clamped to 0)", result);
            test_passed++;
        end else begin
            $display("FAIL: saturate_to_q44(-0x0100) = 0x%02h (expected 0x00)", result);
            test_failed++;
        end
    endtask

    // Test relu_q44
    task test_relu_q44();
        logic [7:0] result;
        $display("\n=== Testing relu_q44 ===");

        // Positive case
        result = relu_q44(16'h0100);
        if (result == 8'h10) begin
            $display("PASS: relu_q44(0x0100) = 0x%02h", result);
            test_passed++;
        end else begin
            $display("FAIL: relu_q44(0x0100) = 0x%02h (expected 0x10)", result);
            test_failed++;
        end

        // Negative case
        result = relu_q44(-16'h0100);
        if (result == 8'h00) begin
            $display("PASS: relu_q44(-0x0100) = 0x%02h (clamped to 0)", result);
            test_passed++;
        end else begin
            $display("FAIL: relu_q44(-0x0100) = 0x%02h (expected 0x00)", result);
            test_failed++;
        end
    endtask

    // Test float_to_q44 and q44_to_float
    task test_float_conversions();
        logic [7:0] q44_val;
        real float_val;
        $display("\n=== Testing float conversions ===");

        q44_val = float_to_q44(2.5);
        float_val = q44_to_float(q44_val);
        if (float_val >= 2.4 && float_val <= 2.6) begin
            $display("PASS: float_to_q44(2.5) -> q44_to_float = %f", float_val);
            test_passed++;
        end else begin
            $display("FAIL: float_to_q44(2.5) -> q44_to_float = %f (expected ~2.5)", float_val);
            test_failed++;
        end

        q44_val = float_to_q44(-1.5);
        float_val = q44_to_float(q44_val);
        if (float_val >= -1.6 && float_val <= -1.4) begin
            $display("PASS: float_to_q44(-1.5) -> q44_to_float = %f", float_val);
            test_passed++;
        end else begin
            $display("FAIL: float_to_q44(-1.5) -> q44_to_float = %f (expected ~-1.5)", float_val);
            test_failed++;
        end
    endtask

    // Test max and min
    task test_max_min();
        logic [7:0] result;
        $display("\n=== Testing max_q44 and min_q44 ===");

        result = max_q44(8'h10, 8'h20);
        if (result == 8'h20) begin
            $display("PASS: max_q44(0x10, 0x20) = 0x%02h", result);
            test_passed++;
        end else begin
            $display("FAIL: max_q44(0x10, 0x20) = 0x%02h (expected 0x20)", result);
            test_failed++;
        end

        result = min_q44(8'h10, 8'h20);
        if (result == 8'h10) begin
            $display("PASS: min_q44(0x10, 0x20) = 0x%02h", result);
            test_passed++;
        end else begin
            $display("FAIL: min_q44(0x10, 0x20) = 0x%02h (expected 0x10)", result);
            test_failed++;
        end
    endtask

    // Main test sequence
    initial begin
        $display("========================================");
        $display("Fixed-Point Package Testbench");
        $display("========================================");

        test_int_to_q44();
        test_q44_to_int();
        test_add_bias_q44();
        test_saturate_to_q44();
        test_relu_q44();
        test_float_conversions();
        test_max_min();

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

        $finish;
    end

endmodule
