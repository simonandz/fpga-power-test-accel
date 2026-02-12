// Testbench for CNN Compute Datapath
// Tests MAC (9-way) + Activation + Pooling pipeline with INT8 values
// Pipeline: MAC (4 cyc) -> accumulate (1 cyc) -> bias add (1 cyc) -> activation (2 cyc) = ~8 cycles

`timescale 1ns / 1ps

module tb_cnn_compute_datapath;

    //==========================================================================
    // Signals
    //==========================================================================
    logic clk, rst_n;
    logic mac_enable, mac_clear;
    logic activation_enable;
    logic [1:0] activation_type;
    logic pool_enable, pool_clear;
    logic [1:0] pool_pixel_idx;
    logic signed [7:0] window_data[0:8];
    logic signed [7:0] kernel_data[0:8];
    logic signed [7:0] bias_in;
    logic signed [7:0] conv_result;
    logic conv_valid;
    logic signed [7:0] pool_result;
    logic pool_valid;
    logic signed [15:0] accumulator;
    logic mac_valid;

    int test_passed = 0;
    int test_failed = 0;

    //==========================================================================
    // Clock generation - 100 MHz (10ns period)
    //==========================================================================
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    //==========================================================================
    // DUT
    //==========================================================================
    cnn_compute_datapath dut (
        .clk(clk),
        .rst_n(rst_n),
        .mac_enable(mac_enable),
        .mac_clear(mac_clear),
        .activation_enable(activation_enable),
        .activation_type(activation_type),
        .pool_enable(pool_enable),
        .pool_clear(pool_clear),
        .pool_pixel_idx(pool_pixel_idx),
        .window_data(window_data),
        .kernel_data(kernel_data),
        .bias_in(bias_in),
        .conv_result(conv_result),
        .conv_valid(conv_valid),
        .pool_result(pool_result),
        .pool_valid(pool_valid),
        .accumulator(accumulator),
        .mac_valid(mac_valid)
    );

    //==========================================================================
    // Software reference model for 3x3 convolution + ReLU
    //==========================================================================
    function automatic logic signed [7:0] compute_expected(
        input logic signed [7:0] win[0:8],
        input logic signed [7:0] ker[0:8],
        input logic signed [7:0] bias,
        input logic [1:0] act_type
    );
        logic signed [15:0] acc;
        logic signed [15:0] with_bias;
        logic signed [7:0] result;
        int i;

        // Dot product
        acc = 0;
        for (i = 0; i < 9; i++) begin
            acc = acc + (win[i] * ker[i]);
        end

        // Add bias
        with_bias = acc + $signed(bias);

        // Activation
        case (act_type)
            2'b00: begin // ReLU
                if (with_bias < 0)
                    with_bias = 0;
            end
            2'b11: begin // None (pass-through)
                // no change
            end
            default: ; // Simplified: only test ReLU and none
        endcase

        // Saturate to INT8
        if (with_bias > 127)
            result = 8'sd127;
        else if (with_bias < -128)
            result = -8'sd128;
        else
            result = with_bias[7:0];

        return result;
    endfunction

    //==========================================================================
    // Task: Run a single convolution test through the datapath
    //==========================================================================
    task automatic run_conv_test(
        input logic signed [7:0] win[0:8],
        input logic signed [7:0] ker[0:8],
        input logic signed [7:0] bias,
        input logic [1:0] act_type,
        input logic signed [7:0] expected_result,
        input string test_name
    );
        int i;
        logic signed [7:0] actual_result;

        $display("\n--- %s ---", test_name);

        // Load data
        for (i = 0; i < 9; i++) begin
            window_data[i] = win[i];
            kernel_data[i] = ker[i];
        end
        bias_in = bias;
        activation_type = act_type;

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
        $display("  Bias: %0d", $signed(bias));

        // Enable activation
        activation_enable = 1'b1;
        @(posedge clk);
        activation_enable = 1'b0;

        // Wait for conv result
        wait(conv_valid);
        @(posedge clk);

        actual_result = conv_result;
        $display("  Result: %0d (0x%02h), Expected: %0d (0x%02h)",
            actual_result, actual_result, expected_result, expected_result);

        if (actual_result == expected_result) begin
            $display("  PASS");
            test_passed++;
        end else begin
            $display("  FAIL (delta = %0d)", actual_result - expected_result);
            test_failed++;
        end
    endtask

    //==========================================================================
    // Main Test Sequence
    //==========================================================================
    initial begin
        int i, t;
        logic signed [7:0] t_win[0:8];
        logic signed [7:0] t_ker[0:8];
        logic signed [7:0] t_bias;
        logic signed [7:0] t_expected;

        $display("========================================");
        $display("CNN Compute Datapath Testbench");
        $display("Pipeline: MAC(4) -> Acc(1) -> Bias(1) -> Act(2) = ~8 cycles");
        $display("========================================");

        // Initialize all signals
        rst_n = 0;
        mac_enable = 0;
        mac_clear = 0;
        activation_enable = 0;
        activation_type = 0;
        pool_enable = 0;
        pool_clear = 0;
        pool_pixel_idx = 0;
        bias_in = 0;
        for (i = 0; i < 9; i++) begin
            window_data[i] = 0;
            kernel_data[i] = 0;
        end

        // Reset
        repeat(10) @(posedge clk);
        rst_n = 1;
        repeat(5) @(posedge clk);

        //======================================================================
        // Test 1: All-ones window x all-ones kernel, bias=0, ReLU
        // Expected: 9 * (1*1) + 0 = 9, ReLU(9) = 9
        //======================================================================
        for (i = 0; i < 9; i++) begin
            t_win[i] = 8'sd1;
            t_ker[i] = 8'sd1;
        end
        t_expected = 8'sd9;
        run_conv_test(t_win, t_ker, 8'sd0, 2'b00, t_expected,
                      "Test 1: All-ones window x all-ones kernel, bias=0, ReLU -> 9");

        //======================================================================
        // Test 2: Identity kernel [0,0,0,0,1,0,0,0,0] x window with center=50
        // Expected: 0 + 0 + 0 + 0 + 50*1 + 0 + 0 + 0 + 0 = 50
        //======================================================================
        for (i = 0; i < 9; i++) begin
            t_win[i] = 8'sd10;  // Fill with some value
            t_ker[i] = 8'sd0;
        end
        t_win[4] = 8'sd50;     // Center pixel = 50
        t_ker[4] = 8'sd1;      // Identity center weight
        t_expected = 8'sd50;
        run_conv_test(t_win, t_ker, 8'sd0, 2'b00, t_expected,
                      "Test 2: Identity kernel, center=50, bias=0 -> 50");

        //======================================================================
        // Test 3: All-ones x all-ones + bias=10
        // Expected: 9 * (1*1) + 10 = 19
        //======================================================================
        for (i = 0; i < 9; i++) begin
            t_win[i] = 8'sd1;
            t_ker[i] = 8'sd1;
        end
        t_expected = 8'sd19;
        run_conv_test(t_win, t_ker, 8'sd10, 2'b00, t_expected,
                      "Test 3: All-ones + bias=10 -> 19");

        //======================================================================
        // Test 4: ReLU clamp: large negative accumulator -> result = 0
        // window = all 10, kernel = all -10, acc = 9*(-100) = -900
        // ReLU(-900) = 0
        //======================================================================
        for (i = 0; i < 9; i++) begin
            t_win[i] = 8'sd10;
            t_ker[i] = -8'sd10;
        end
        t_expected = 8'sd0;
        run_conv_test(t_win, t_ker, 8'sd0, 2'b00, t_expected,
                      "Test 4: Negative acc, ReLU clamp -> 0");

        //======================================================================
        // Test 5: Saturation test - large positive should saturate to 127
        // window = all 20, kernel = all 20, acc = 9*400 = 3600
        // ReLU(3600) = 3600, saturate to 127
        //======================================================================
        for (i = 0; i < 9; i++) begin
            t_win[i] = 8'sd20;
            t_ker[i] = 8'sd20;
        end
        t_expected = 8'sd127;
        run_conv_test(t_win, t_ker, 8'sd0, 2'b00, t_expected,
                      "Test 5: Positive saturation -> 127");

        //======================================================================
        // Test 6: Single weight with various positions
        // kernel = [0,0,0, 0,0,0, 0,0,1], window = [..., 33]
        // Expected: 33
        //======================================================================
        for (i = 0; i < 9; i++) begin
            t_win[i] = 8'sd5;
            t_ker[i] = 8'sd0;
        end
        t_win[8] = 8'sd33;
        t_ker[8] = 8'sd1;
        t_expected = 8'sd33;
        run_conv_test(t_win, t_ker, 8'sd0, 2'b00, t_expected,
                      "Test 6: Single weight at position 8 -> 33");

        //======================================================================
        // Test 7: Negative bias pulling result below zero
        // all-ones x all-ones = 9, bias = -20 -> 9 - 20 = -11 -> ReLU = 0
        //======================================================================
        for (i = 0; i < 9; i++) begin
            t_win[i] = 8'sd1;
            t_ker[i] = 8'sd1;
        end
        t_expected = 8'sd0;
        run_conv_test(t_win, t_ker, -8'sd20, 2'b00, t_expected,
                      "Test 7: Bias pulls negative, ReLU -> 0");

        //======================================================================
        // Test 8: Pass-through activation (no ReLU)
        // all-ones x all(-1) = -9, bias=0, no activation -> saturate(-9) = -9
        //======================================================================
        for (i = 0; i < 9; i++) begin
            t_win[i] = 8'sd1;
            t_ker[i] = -8'sd1;
        end
        t_expected = -8'sd9;
        run_conv_test(t_win, t_ker, 8'sd0, 2'b11, t_expected,
                      "Test 8: Pass-through, negative result -> -9");

        //======================================================================
        // Test 9: Weighted sum check
        // window = [1,2,3,4,5,6,7,8,9], kernel = [1,1,1,1,1,1,1,1,1], bias=0
        // Expected: 1+2+3+4+5+6+7+8+9 = 45
        //======================================================================
        for (i = 0; i < 9; i++) begin
            t_win[i] = i + 1;
            t_ker[i] = 8'sd1;
        end
        t_expected = 8'sd45;
        run_conv_test(t_win, t_ker, 8'sd0, 2'b00, t_expected,
                      "Test 9: Sum 1..9 with all-ones kernel -> 45");

        //======================================================================
        // Tests 10-19: Random tests comparing against software model
        //======================================================================
        $display("\n=== PHASE 2: RANDOM TESTS (10 iterations) ===");

        for (t = 0; t < 10; t++) begin
            // Generate random window and kernel
            for (i = 0; i < 9; i++) begin
                t_win[i] = $signed($urandom_range(0, 255) - 128);
                t_ker[i] = $signed($urandom_range(0, 255) - 128);
            end
            t_bias = $signed($urandom_range(0, 255) - 128);

            // Compute expected with software model
            t_expected = compute_expected(t_win, t_ker, t_bias, 2'b00);

            run_conv_test(t_win, t_ker, t_bias, 2'b00, t_expected,
                          $sformatf("Random Test %0d", t + 1));
        end

        //======================================================================
        // Test 20: Pool unit basic test
        // Feed 4 values through pool, expect max
        //======================================================================
        $display("\n=== PHASE 3: POOL UNIT TEST ===");
        $display("\n--- Test 20: MaxPool 2x2 ---");

        pool_clear = 1'b1;
        @(posedge clk);
        pool_clear = 1'b0;

        // Feed 4 activation results through pool unit
        // We'll do 4 conv computations and feed them to the pool
        begin
            logic signed [7:0] pool_vals[4];
            logic signed [7:0] expected_max;

            pool_vals[0] = 8'sd10;
            pool_vals[1] = 8'sd30;
            pool_vals[2] = 8'sd20;
            pool_vals[3] = 8'sd5;
            expected_max = 8'sd30;

            for (i = 0; i < 4; i++) begin
                // Set up a simple window where center = desired value
                for (int j = 0; j < 9; j++) begin
                    window_data[j] = 8'sd0;
                    kernel_data[j] = 8'sd0;
                end
                window_data[4] = pool_vals[i];
                kernel_data[4] = 8'sd1;
                bias_in = 8'sd0;
                activation_type = 2'b11; // Pass-through to preserve sign

                // Clear and compute
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
                @(posedge clk);

                activation_enable = 1'b1;
                @(posedge clk);
                activation_enable = 1'b0;

                wait(conv_valid);
                @(posedge clk);

                // Feed to pool
                pool_pixel_idx = i[1:0];
                pool_enable = 1'b1;
                @(posedge clk);
                pool_enable = 1'b0;
                @(posedge clk);
            end

            // Check pool result
            repeat(3) @(posedge clk);
            $display("  Pool result: %0d, Expected max: %0d", pool_result, expected_max);
            if (pool_result == expected_max) begin
                $display("  PASS");
                test_passed++;
            end else begin
                $display("  FAIL");
                test_failed++;
            end
        end

        //======================================================================
        // Summary
        //======================================================================
        $display("\n========================================");
        $display("Test Summary");
        $display("========================================");
        $display("Tests passed: %0d", test_passed);
        $display("Tests failed: %0d", test_failed);
        $display("Directed tests: 9");
        $display("Random tests:   10");
        $display("Pool test:      1");
        $display("Grand total:    20 tests");

        if (test_failed == 0) begin
            $display("\n*** ALL TESTS PASSED ***");
        end else begin
            $display("\n*** SOME TESTS FAILED ***");
        end
        $display("========================================\n");

        repeat(10) @(posedge clk);
        $finish;
    end

    //==========================================================================
    // Timeout
    //==========================================================================
    initial begin
        #200000;
        $display("\nERROR: Simulation timeout!\n");
        $finish;
    end

    //==========================================================================
    // VCD Dump
    //==========================================================================
    initial begin
        $dumpfile("tb_cnn_compute_datapath.vcd");
        $dumpvars(0, tb_cnn_compute_datapath);
    end

endmodule
