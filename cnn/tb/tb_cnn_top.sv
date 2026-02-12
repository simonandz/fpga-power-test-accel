// Testbench for CNN Top-Level
// Full integration test for 3x3 CNN convolution accelerator
// Tests convolution correctness against software reference model
//
// Configuration: 16x16 input, 3x3 kernel, stride=1, pad=1
// Output: 16x16 (same spatial dimensions with padding)

`timescale 1ns / 1ps

module tb_cnn_top;

    //==========================================================================
    // Parameters
    //==========================================================================
    parameter IMG_W    = 16;
    parameter IMG_H    = 16;
    parameter KER_SIZE = 3;
    parameter STRIDE   = 1;
    parameter PAD      = 1;
    parameter POOL_EN  = 1;
    parameter OUT_H    = (IMG_H + 2*PAD - KER_SIZE) / STRIDE + 1;  // 16
    parameter OUT_W    = (IMG_W + 2*PAD - KER_SIZE) / STRIDE + 1;  // 16
    parameter CLK_PERIOD_NS = 10;  // 100 MHz

    //==========================================================================
    // Signals
    //==========================================================================
    logic        clk, rst_n;
    logic        start, done, busy;
    logic        pool_enable;

    // Host load interfaces
    logic [15:0] ifmap_addr;
    logic [7:0]  ifmap_data;
    logic        ifmap_we;
    logic [3:0]  kernel_addr;
    logic [7:0]  kernel_data;
    logic        kernel_we;
    logic [7:0]  bias_data;
    logic        bias_we;

    // Output interface
    logic [7:0]  output_data;
    logic        output_valid;
    logic [15:0] output_wr_addr;
    logic [7:0]  output_wr_data;
    logic        output_wr_en;

    // Test tracking
    int test_passed = 0;
    int test_failed = 0;

    // Captured output map
    logic signed [7:0] captured_ofmap [0:OUT_H*OUT_W-1];
    int output_count;

    // Test data storage
    logic signed [7:0] test_ifmap  [0:IMG_H-1][0:IMG_W-1];
    logic signed [7:0] test_kernel [0:KER_SIZE-1][0:KER_SIZE-1];
    logic signed [7:0] test_bias;

    //==========================================================================
    // Clock generation - 100 MHz (10ns period)
    //==========================================================================
    initial begin
        clk = 0;
        forever #(CLK_PERIOD_NS/2) clk = ~clk;
    end

    //==========================================================================
    // DUT
    //==========================================================================
    cnn_top #(
        .IMG_W(IMG_W),
        .IMG_H(IMG_H),
        .KER_SIZE(KER_SIZE),
        .STRIDE(STRIDE),
        .PAD(PAD),
        .POOL_EN(POOL_EN)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .done(done),
        .busy(busy),
        .pool_enable(pool_enable),
        .ifmap_addr(ifmap_addr),
        .ifmap_data(ifmap_data),
        .ifmap_we(ifmap_we),
        .kernel_addr(kernel_addr),
        .kernel_data(kernel_data),
        .kernel_we(kernel_we),
        .bias_data(bias_data),
        .bias_we(bias_we),
        .output_data(output_data),
        .output_valid(output_valid),
        .output_wr_addr(output_wr_addr),
        .output_wr_data(output_wr_data),
        .output_wr_en(output_wr_en)
    );

    //==========================================================================
    // Output capture: monitor output_wr_en, store output_wr_data at output_wr_addr
    //==========================================================================
    always @(posedge clk) begin
        if (output_wr_en) begin
            if (output_wr_addr < OUT_H*OUT_W) begin
                captured_ofmap[output_wr_addr] = output_wr_data;
            end
            output_count++;
        end
    end

    //==========================================================================
    // Helper Tasks
    //==========================================================================

    task automatic load_ifmap_pixel(input int addr, input logic [7:0] data);
        @(posedge clk);
        ifmap_addr = addr[15:0];
        ifmap_data = data;
        ifmap_we   = 1'b1;
        @(posedge clk);
        ifmap_we = 1'b0;
    endtask

    task automatic load_kernel_weight(input int addr, input logic [7:0] data);
        @(posedge clk);
        kernel_addr = addr[3:0];
        kernel_data = data;
        kernel_we   = 1'b1;
        @(posedge clk);
        kernel_we = 1'b0;
    endtask

    task automatic load_bias(input logic [7:0] data);
        @(posedge clk);
        bias_data = data;
        bias_we   = 1'b1;
        @(posedge clk);
        bias_we = 1'b0;
    endtask

    task automatic run_inference();
        @(posedge clk);
        start = 1'b1;
        @(posedge clk);
        start = 1'b0;
        wait(done);
        @(posedge clk);
    endtask

    // Load entire input feature map from test_ifmap array
    task automatic load_full_ifmap();
        int r, c;
        for (r = 0; r < IMG_H; r++) begin
            for (c = 0; c < IMG_W; c++) begin
                load_ifmap_pixel(r * IMG_W + c, test_ifmap[r][c]);
            end
        end
    endtask

    // Load entire kernel from test_kernel array
    task automatic load_full_kernel();
        int kr, kc;
        for (kr = 0; kr < KER_SIZE; kr++) begin
            for (kc = 0; kc < KER_SIZE; kc++) begin
                load_kernel_weight(kr * KER_SIZE + kc, test_kernel[kr][kc]);
            end
        end
    endtask

    //==========================================================================
    // Software Reference Model
    //==========================================================================
    function automatic void compute_conv_reference(
        input logic signed [7:0] ifmap [0:IMG_H-1][0:IMG_W-1],
        input logic signed [7:0] kernel [0:KER_SIZE-1][0:KER_SIZE-1],
        input logic signed [7:0] bias,
        output logic signed [7:0] expected [0:OUT_H-1][0:OUT_W-1]
    );
        int r, c, kr, kc;
        int in_r, in_c;
        logic signed [15:0] acc;
        logic signed [15:0] with_bias;

        for (r = 0; r < OUT_H; r++) begin
            for (c = 0; c < OUT_W; c++) begin
                acc = 0;
                for (kr = 0; kr < KER_SIZE; kr++) begin
                    for (kc = 0; kc < KER_SIZE; kc++) begin
                        in_r = r * STRIDE + kr - PAD;
                        in_c = c * STRIDE + kc - PAD;
                        // Zero-pad out-of-bounds
                        if (in_r >= 0 && in_r < IMG_H && in_c >= 0 && in_c < IMG_W) begin
                            acc = acc + (ifmap[in_r][in_c] * kernel[kr][kc]);
                        end
                    end
                end
                // Bias add
                with_bias = acc + $signed(bias);
                // ReLU
                if (with_bias < 0)
                    with_bias = 0;
                // Saturate to INT8
                if (with_bias > 127)
                    expected[r][c] = 8'sd127;
                else
                    expected[r][c] = with_bias[7:0];
            end
        end
    endfunction

    //==========================================================================
    // Task: Run a complete test case with comparison
    //==========================================================================
    task automatic run_test_case(
        input string test_name
    );
        logic signed [7:0] expected [0:OUT_H-1][0:OUT_W-1];
        int r, c, mismatches;
        logic signed [7:0] got_val, exp_val;

        $display("\n================================================================");
        $display("  %s", test_name);
        $display("================================================================");

        // Reset DUT
        rst_n = 0;
        start = 0;
        output_count = 0;
        for (int i = 0; i < OUT_H*OUT_W; i++)
            captured_ofmap[i] = 8'h00;
        repeat(5) @(posedge clk);
        rst_n = 1;
        repeat(5) @(posedge clk);

        // Load data
        $display("[%0t] Loading input feature map (%0dx%0d)...", $time, IMG_H, IMG_W);
        load_full_ifmap();

        $display("[%0t] Loading kernel (%0dx%0d)...", $time, KER_SIZE, KER_SIZE);
        load_full_kernel();

        $display("[%0t] Loading bias = %0d...", $time, $signed(test_bias));
        load_bias(test_bias);
        repeat(2) @(posedge clk);

        // Run inference
        $display("[%0t] Starting inference...", $time);
        run_inference();
        $display("[%0t] Inference complete! Captured %0d output writes.", $time, output_count);

        // Compute reference
        compute_conv_reference(test_ifmap, test_kernel, test_bias, expected);

        // Compare
        mismatches = 0;
        for (r = 0; r < OUT_H; r++) begin
            for (c = 0; c < OUT_W; c++) begin
                got_val = captured_ofmap[r * OUT_W + c];
                exp_val = expected[r][c];
                if (got_val !== exp_val) begin
                    if (mismatches < 10) begin
                        $display("  MISMATCH at [%0d][%0d]: got %0d, expected %0d",
                                 r, c, got_val, exp_val);
                    end
                    mismatches++;
                end
            end
        end

        // Print a few sample outputs for debugging
        $display("  Sample outputs (first row):");
        for (c = 0; c < OUT_W && c < 8; c++) begin
            $display("    [0][%0d]: got=%0d, exp=%0d",
                     c, $signed(captured_ofmap[c]), $signed(expected[0][c]));
        end

        if (mismatches == 0) begin
            $display("  >>> TEST PASSED (all %0d pixels match) <<<", OUT_H * OUT_W);
            test_passed++;
        end else begin
            $display("  >>> TEST FAILED (%0d / %0d mismatches) <<<",
                     mismatches, OUT_H * OUT_W);
            test_failed++;
        end
    endtask

    //==========================================================================
    // Main Test Sequence
    //==========================================================================
    initial begin
        int r, c;

        $display("");
        $display("================================================================");
        $display("CNN Top-Level Integration Testbench");
        $display("Configuration: %0dx%0d input, %0dx%0d kernel, stride=%0d, pad=%0d",
                 IMG_H, IMG_W, KER_SIZE, KER_SIZE, STRIDE, PAD);
        $display("Output: %0dx%0d", OUT_H, OUT_W);
        $display("================================================================");

        // Initialize signals
        rst_n = 0;
        start = 0;
        pool_enable = 0;  // Conv-only mode for tests 1-4
        ifmap_addr = 0; ifmap_data = 0; ifmap_we = 0;
        kernel_addr = 0; kernel_data = 0; kernel_we = 0;
        bias_data = 0; bias_we = 0;
        output_count = 0;

        repeat(10) @(posedge clk);

        //======================================================================
        // Test 1: Identity kernel, bias=0, uniform input=42
        // Identity kernel [0,0,0; 0,1,0; 0,0,0]
        // All pixels should be 42 (identity passes center through)
        //======================================================================
        for (r = 0; r < IMG_H; r++)
            for (c = 0; c < IMG_W; c++)
                test_ifmap[r][c] = 8'sd42;

        for (r = 0; r < KER_SIZE; r++)
            for (c = 0; c < KER_SIZE; c++)
                test_kernel[r][c] = 8'sd0;
        test_kernel[1][1] = 8'sd1;  // Center = 1

        test_bias = 8'sd0;
        pool_enable = 0;

        run_test_case("Test 1: Identity kernel, uniform input=42, bias=0");

        //======================================================================
        // Test 2: All-ones kernel, bias=0, input=1 everywhere
        // Center pixels = 9 (sum of 3x3 all-ones)
        // Edge/corner pixels vary due to zero-padding
        //======================================================================
        for (r = 0; r < IMG_H; r++)
            for (c = 0; c < IMG_W; c++)
                test_ifmap[r][c] = 8'sd1;

        for (r = 0; r < KER_SIZE; r++)
            for (c = 0; c < KER_SIZE; c++)
                test_kernel[r][c] = 8'sd1;

        test_bias = 8'sd0;
        pool_enable = 0;

        run_test_case("Test 2: All-ones kernel, input=1, bias=0 (edges vary)");

        //======================================================================
        // Test 3: Identity kernel + bias=10, input=20
        // Expected output = 20 + 10 = 30 everywhere
        //======================================================================
        for (r = 0; r < IMG_H; r++)
            for (c = 0; c < IMG_W; c++)
                test_ifmap[r][c] = 8'sd20;

        for (r = 0; r < KER_SIZE; r++)
            for (c = 0; c < KER_SIZE; c++)
                test_kernel[r][c] = 8'sd0;
        test_kernel[1][1] = 8'sd1;

        test_bias = 8'sd10;
        pool_enable = 0;

        run_test_case("Test 3: Identity kernel, input=20, bias=10 -> 30");

        //======================================================================
        // Test 4: ReLU test - identity kernel, bias=0, input with negatives
        // Negative inputs should produce 0 (ReLU clamp)
        // Positive inputs should pass through
        //======================================================================
        for (r = 0; r < IMG_H; r++)
            for (c = 0; c < IMG_W; c++) begin
                if ((r + c) % 2 == 0)
                    test_ifmap[r][c] = -8'sd30;  // Negative -> ReLU to 0
                else
                    test_ifmap[r][c] = 8'sd25;   // Positive -> pass through
            end

        for (r = 0; r < KER_SIZE; r++)
            for (c = 0; c < KER_SIZE; c++)
                test_kernel[r][c] = 8'sd0;
        test_kernel[1][1] = 8'sd1;

        test_bias = 8'sd0;
        pool_enable = 0;

        run_test_case("Test 4: ReLU test, negative inputs clamped to 0");

        //======================================================================
        // Test 5: Gradient input with edge-detect kernel
        // Horizontal gradient input (0..15 per row)
        // Kernel: [-1, 0, 1; -1, 0, 1; -1, 0, 1] (horizontal edge detect)
        //======================================================================
        for (r = 0; r < IMG_H; r++)
            for (c = 0; c < IMG_W; c++)
                test_ifmap[r][c] = c[7:0];  // Horizontal gradient 0..15

        test_kernel[0][0] = -8'sd1; test_kernel[0][1] = 8'sd0; test_kernel[0][2] = 8'sd1;
        test_kernel[1][0] = -8'sd1; test_kernel[1][1] = 8'sd0; test_kernel[1][2] = 8'sd1;
        test_kernel[2][0] = -8'sd1; test_kernel[2][1] = 8'sd0; test_kernel[2][2] = 8'sd1;

        test_bias = 8'sd0;
        pool_enable = 0;

        run_test_case("Test 5: Gradient input + edge-detect kernel");

        //======================================================================
        // Test 6: Bias saturation - large input + large bias -> saturate 127
        // input = 60, identity kernel, bias = 80 -> 60+80 = 140 -> saturate to 127
        //======================================================================
        for (r = 0; r < IMG_H; r++)
            for (c = 0; c < IMG_W; c++)
                test_ifmap[r][c] = 8'sd60;

        for (r = 0; r < KER_SIZE; r++)
            for (c = 0; c < KER_SIZE; c++)
                test_kernel[r][c] = 8'sd0;
        test_kernel[1][1] = 8'sd1;

        test_bias = 8'sd80;
        pool_enable = 0;

        run_test_case("Test 6: Saturation test, 60+80=140 -> saturate to 127");

        //======================================================================
        // Summary
        //======================================================================
        $display("\n================================================================");
        $display("FINAL TEST SUMMARY");
        $display("================================================================");
        $display("Tests passed: %0d", test_passed);
        $display("Tests failed: %0d", test_failed);

        if (test_failed == 0) begin
            $display("\n*** ALL TESTS PASSED ***");
        end else begin
            $display("\n*** SOME TESTS FAILED ***");
        end
        $display("================================================================\n");

        repeat(20) @(posedge clk);
        $finish;
    end

    //==========================================================================
    // Timeout
    //==========================================================================
    initial begin
        #50000000;  // 50ms timeout
        $display("\nERROR: Simulation timeout!\n");
        $finish;
    end

    //==========================================================================
    // VCD Dump
    //==========================================================================
    initial begin
        $dumpfile("tb_cnn_top.vcd");
        $dumpvars(0, tb_cnn_top);
    end

endmodule
