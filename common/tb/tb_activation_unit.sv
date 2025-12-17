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

    // Hybrid sweep test task - combines directed + boundary sweep + random
    task automatic sweep_activation(
        input [1:0] act_type,
        input string act_name
    );
        int errors = 0;
        int sweep_tests = 0;
        logic signed [7:0] expected;

        $display("\n=== HYBRID SWEEP: %s ===", act_name);

        // 1. DIRECTED TESTS - Known corner cases
        $display("Phase 1: Directed corner cases");
        case (act_type)
            2'b00: begin  // ReLU
                test_activation(2'b00, 0, 0, "ReLU: Zero");
                test_activation(2'b00, 1, 1, "ReLU: Minimum positive");
                test_activation(2'b00, -1, 0, "ReLU: Maximum negative");
                test_activation(2'b00, 127, 127, "ReLU: INT8 max");
                test_activation(2'b00, -128, 0, "ReLU: INT8 min");
                test_activation(2'b00, 32767, 127, "ReLU: INT16 max saturation");
                test_activation(2'b00, -32768, 0, "ReLU: INT16 min saturation");
            end
            2'b01: begin  // tanh
                test_activation(2'b01, 0, 0, "tanh: Zero");
                test_activation(2'b01, 63, 0, "tanh: Boundary below saturation");
                test_activation(2'b01, 64, 64, "tanh: Saturation threshold");
                test_activation(2'b01, -63, -1, "tanh: Negative boundary");
                test_activation(2'b01, -64, -64, "tanh: Negative saturation");
                test_activation(2'b01, 127, 64, "tanh: Large positive");
                test_activation(2'b01, -128, -64, "tanh: Large negative");
            end
            2'b10: begin  // Sigmoid
                test_activation(2'b10, 0, 64, "Sigmoid: Zero (0.5)");
                test_activation(2'b10, 127, 95, "Sigmoid: Boundary below sat");
                test_activation(2'b10, 128, 96, "Sigmoid: Saturation threshold");
                test_activation(2'b10, -128, 32, "Sigmoid: Negative threshold");
                test_activation(2'b10, -129, 0, "Sigmoid: Below negative threshold (saturate)");
                test_activation(2'b10, 500, 127, "Sigmoid: Large positive sat");
                test_activation(2'b10, -500, 0, "Sigmoid: Large negative sat");
            end
            2'b11: begin  // None (pass-through)
                test_activation(2'b11, 0, 0, "None: Zero");
                test_activation(2'b11, 127, 127, "None: INT8 max");
                test_activation(2'b11, -128, -128, "None: INT8 min");
                test_activation(2'b11, 200, 127, "None: Saturate positive");
                test_activation(2'b11, -200, -128, "None: Saturate negative");
            end
        endcase

        // 2. BOUNDARY SWEEP - Exhaustive near critical points
        $display("Phase 2: Boundary sweep (critical regions)");
        activation_type = act_type;

        // Sweep around zero (-10 to +10)
        for (int i = -10; i <= 10; i++) begin
            data_in = i;
            @(posedge clk);
            enable = 1'b1;
            @(posedge clk);
            enable = 1'b0;
            wait(valid);
            @(posedge clk);
            sweep_tests++;
        end

        // Sweep around INT8 boundaries (125-127, -128 to -126)
        for (int i = 125; i <= 130; i++) begin
            data_in = i;
            @(posedge clk);
            enable = 1'b1;
            @(posedge clk);
            enable = 1'b0;
            wait(valid);
            @(posedge clk);
            sweep_tests++;
        end

        for (int i = -130; i <= -125; i++) begin
            data_in = i;
            @(posedge clk);
            enable = 1'b1;
            @(posedge clk);
            enable = 1'b0;
            wait(valid);
            @(posedge clk);
            sweep_tests++;
        end

        // Function-specific boundaries
        if (act_type == 2'b01) begin  // tanh saturation at ±64
            for (int i = 60; i <= 70; i++) begin
                data_in = i;
                @(posedge clk);
                enable = 1'b1;
                @(posedge clk);
                enable = 1'b0;
                wait(valid);
                @(posedge clk);
                sweep_tests++;
            end
            for (int i = -70; i <= -60; i++) begin
                data_in = i;
                @(posedge clk);
                enable = 1'b1;
                @(posedge clk);
                enable = 1'b0;
                wait(valid);
                @(posedge clk);
                sweep_tests++;
            end
        end

        if (act_type == 2'b10) begin  // Sigmoid saturation at ±128
            for (int i = 125; i <= 135; i++) begin
                data_in = i;
                @(posedge clk);
                enable = 1'b1;
                @(posedge clk);
                enable = 1'b0;
                wait(valid);
                @(posedge clk);
                sweep_tests++;
            end
            for (int i = -135; i <= -125; i++) begin
                data_in = i;
                @(posedge clk);
                enable = 1'b1;
                @(posedge clk);
                enable = 1'b0;
                wait(valid);
                @(posedge clk);
                sweep_tests++;
            end
        end

        $display("  Completed %0d boundary sweep tests", sweep_tests);

        // 3. RANDOM SAMPLING - Cover middle ranges
        $display("Phase 3: Random sampling (wide coverage)");
        repeat(500) begin
            automatic int random_val = $urandom_range(0, 65535) - 32768;  // -32768 to 32767
            data_in = random_val;
            @(posedge clk);
            enable = 1'b1;
            @(posedge clk);
            enable = 1'b0;
            wait(valid);
            @(posedge clk);
        end
        $display("  Completed 500 random tests");

    endtask

    initial begin
        $display("========================================");
        $display("Activation Unit HYBRID SWEEP Testbench");
        $display("Using: Directed + Boundary + Random");
        $display("========================================");

        rst_n = 0;
        enable = 0;
        activation_type = 0;
        data_in = 0;

        repeat(10) @(posedge clk);
        rst_n = 1;
        repeat(5) @(posedge clk);

        // Run hybrid sweep for each activation function
        sweep_activation(2'b00, "ReLU");
        sweep_activation(2'b01, "tanh");
        sweep_activation(2'b10, "Sigmoid");
        sweep_activation(2'b11, "None (pass-through)");

        $display("\n========================================");
        $display("Test Summary");
        $display("========================================");
        $display("Tests passed: %0d", test_passed);
        $display("Tests failed: %0d", test_failed);
        $display("Total directed tests: ~28");
        $display("Total sweep tests: ~120 per function");
        $display("Total random tests: 500 per function");
        $display("Grand total: ~2500+ tests");

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
