// Testbench for CNN Memory Subsystem
// Tests all memory read/write operations: ifmap BRAM, kernel regs, bias reg, ofmap BRAM

`timescale 1ns / 1ps

module tb_cnn_memory_subsystem;

    parameter IMG_W    = 16;
    parameter IMG_H    = 16;
    parameter KER_SIZE = 3;

    logic clk, rst_n;

    // Host write interface
    logic [15:0] ifmap_addr;
    logic [7:0]  ifmap_data;
    logic        ifmap_we;

    logic [3:0]  kernel_addr;
    logic [7:0]  kernel_data;
    logic        kernel_we;

    logic [7:0]  bias_data;
    logic        bias_we;

    // Compute read interface
    logic [15:0] ifmap_rd_addr;
    logic [7:0]  ifmap_rd_data;

    logic [3:0]  kernel_rd_addr;
    logic [7:0]  kernel_rd_data;

    logic [7:0]  bias_rd_data;

    // Output write interface
    logic [15:0] ofmap_wr_addr;
    logic [7:0]  ofmap_wr_data;
    logic        ofmap_we;

    // Output read interface
    logic [15:0] ofmap_rd_addr;
    logic [7:0]  ofmap_rd_data;

    int test_passed = 0;
    int test_failed = 0;

    // Clock generation (100 MHz)
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // DUT instantiation
    cnn_memory_subsystem #(
        .IMG_W(IMG_W),
        .IMG_H(IMG_H),
        .KER_SIZE(KER_SIZE)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .ifmap_addr(ifmap_addr),
        .ifmap_data(ifmap_data),
        .ifmap_we(ifmap_we),
        .kernel_addr(kernel_addr),
        .kernel_data(kernel_data),
        .kernel_we(kernel_we),
        .bias_data(bias_data),
        .bias_we(bias_we),
        .ifmap_rd_addr(ifmap_rd_addr),
        .ifmap_rd_data(ifmap_rd_data),
        .kernel_rd_addr(kernel_rd_addr),
        .kernel_rd_data(kernel_rd_data),
        .bias_rd_data(bias_rd_data),
        .ofmap_wr_addr(ofmap_wr_addr),
        .ofmap_wr_data(ofmap_wr_data),
        .ofmap_we(ofmap_we),
        .ofmap_rd_addr(ofmap_rd_addr),
        .ofmap_rd_data(ofmap_rd_data)
    );

    // Task: write then read ifmap BRAM (1-cycle read latency)
    task automatic test_ifmap_write_read(
        input [15:0] addr,
        input [7:0]  wr_data,
        input string test_name
    );
        logic [7:0] rd_data;

        $display("  --- %s ---", test_name);

        // Write
        @(posedge clk);
        ifmap_addr = addr;
        ifmap_data = wr_data;
        ifmap_we = 1'b1;
        @(posedge clk);
        ifmap_we = 1'b0;

        // Read (1-cycle latency)
        @(posedge clk);
        ifmap_rd_addr = addr;
        @(posedge clk);
        rd_data = ifmap_rd_data;

        $display("    Written: 0x%02h at addr %0d", wr_data, addr);
        $display("    Read:    0x%02h from addr %0d", rd_data, addr);

        if (rd_data == wr_data) begin
            $display("    PASS");
            test_passed++;
        end else begin
            $display("    FAIL");
            test_failed++;
        end
    endtask

    // Task: write then read kernel register (1-cycle read latency)
    task automatic test_kernel_write_read(
        input [3:0]  addr,
        input [7:0]  wr_data,
        input string test_name
    );
        logic [7:0] rd_data;

        $display("  --- %s ---", test_name);

        // Write
        @(posedge clk);
        kernel_addr = addr;
        kernel_data = wr_data;
        kernel_we = 1'b1;
        @(posedge clk);
        kernel_we = 1'b0;

        // Read (1-cycle latency)
        @(posedge clk);
        kernel_rd_addr = addr;
        @(posedge clk);
        rd_data = kernel_rd_data;

        $display("    Written: 0x%02h at kernel[%0d]", wr_data, addr);
        $display("    Read:    0x%02h from kernel[%0d]", rd_data, addr);

        if (rd_data == wr_data) begin
            $display("    PASS");
            test_passed++;
        end else begin
            $display("    FAIL");
            test_failed++;
        end
    endtask

    // Task: write then read bias register (combinational read - no latency)
    task automatic test_bias_write_read(
        input [7:0]  wr_data,
        input string test_name
    );
        logic [7:0] rd_data;

        $display("  --- %s ---", test_name);

        // Write
        @(posedge clk);
        bias_data = wr_data;
        bias_we = 1'b1;
        @(posedge clk);
        bias_we = 1'b0;

        // Bias read is combinational (assign), available immediately after write registers
        @(posedge clk);
        rd_data = bias_rd_data;

        $display("    Written: 0x%02h", wr_data);
        $display("    Read:    0x%02h", rd_data);

        if (rd_data == wr_data) begin
            $display("    PASS");
            test_passed++;
        end else begin
            $display("    FAIL");
            test_failed++;
        end
    endtask

    // Task: write then read ofmap BRAM (1-cycle read latency)
    task automatic test_ofmap_write_read(
        input [15:0] addr,
        input [7:0]  wr_data,
        input string test_name
    );
        logic [7:0] rd_data;

        $display("  --- %s ---", test_name);

        // Write
        @(posedge clk);
        ofmap_wr_addr = addr;
        ofmap_wr_data = wr_data;
        ofmap_we = 1'b1;
        @(posedge clk);
        ofmap_we = 1'b0;

        // Read (1-cycle latency)
        @(posedge clk);
        ofmap_rd_addr = addr;
        @(posedge clk);
        rd_data = ofmap_rd_data;

        $display("    Written: 0x%02h at addr %0d", wr_data, addr);
        $display("    Read:    0x%02h from addr %0d", rd_data, addr);

        if (rd_data == wr_data) begin
            $display("    PASS");
            test_passed++;
        end else begin
            $display("    FAIL");
            test_failed++;
        end
    endtask

    // Main test sequence
    initial begin
        $display("========================================");
        $display("CNN Memory Subsystem Testbench");
        $display("IMG: %0dx%0d, Kernel: %0dx%0d", IMG_W, IMG_H, KER_SIZE, KER_SIZE);
        $display("========================================");

        // Initialize all signals
        rst_n = 0;
        ifmap_addr = 0; ifmap_data = 0; ifmap_we = 0;
        kernel_addr = 0; kernel_data = 0; kernel_we = 0;
        bias_data = 0; bias_we = 0;
        ifmap_rd_addr = 0;
        kernel_rd_addr = 0;
        ofmap_wr_addr = 0; ofmap_wr_data = 0; ofmap_we = 0;
        ofmap_rd_addr = 0;

        // Reset
        repeat(10) @(posedge clk);
        rst_n = 1;
        repeat(5) @(posedge clk);

        // =================================================================
        // Test 1: Write/Read ifmap BRAM at addresses 0, 128, 255
        // =================================================================
        $display("\n=== Test 1: ifmap BRAM Write/Read ===");
        test_ifmap_write_read(16'd0,   8'hAA, "ifmap addr 0");
        test_ifmap_write_read(16'd128, 8'h55, "ifmap addr 128");
        test_ifmap_write_read(16'd255, 8'hFF, "ifmap addr 255");

        // =================================================================
        // Test 2: Write/Read all 9 kernel registers (addresses 0-8)
        // =================================================================
        $display("\n=== Test 2: Kernel Registers Write/Read ===");
        test_kernel_write_read(4'd0, 8'h11, "kernel[0]");
        test_kernel_write_read(4'd1, 8'h22, "kernel[1]");
        test_kernel_write_read(4'd2, 8'h33, "kernel[2]");
        test_kernel_write_read(4'd3, 8'h44, "kernel[3]");
        test_kernel_write_read(4'd4, 8'h55, "kernel[4]");
        test_kernel_write_read(4'd5, 8'h66, "kernel[5]");
        test_kernel_write_read(4'd6, 8'h77, "kernel[6]");
        test_kernel_write_read(4'd7, 8'h88, "kernel[7]");
        test_kernel_write_read(4'd8, 8'h99, "kernel[8]");

        // =================================================================
        // Test 3: Write/Read bias register
        // =================================================================
        $display("\n=== Test 3: Bias Register Write/Read ===");
        test_bias_write_read(8'hAB, "bias = 0xAB");
        test_bias_write_read(8'h00, "bias = 0x00");
        test_bias_write_read(8'hFF, "bias = 0xFF");

        // =================================================================
        // Test 4: Write/Read ofmap BRAM at addresses 0, 128, 255
        // =================================================================
        $display("\n=== Test 4: ofmap BRAM Write/Read ===");
        test_ofmap_write_read(16'd0,   8'hDE, "ofmap addr 0");
        test_ofmap_write_read(16'd128, 8'hAD, "ofmap addr 128");
        test_ofmap_write_read(16'd255, 8'hBE, "ofmap addr 255");

        // =================================================================
        // Test 5: Sequential write 16 values to ifmap, then read all back
        // =================================================================
        $display("\n=== Test 5: Sequential Write 16, Read Back ===");

        // Write 16 consecutive values
        for (int i = 0; i < 16; i++) begin
            @(posedge clk);
            ifmap_addr = i;
            ifmap_data = (i * 13 + 7) & 8'hFF;  // Pseudo-pattern
            ifmap_we = 1'b1;
        end
        @(posedge clk);
        ifmap_we = 1'b0;

        // Read back all 16 values (1-cycle read latency)
        for (int i = 0; i < 16; i++) begin
            logic [7:0] expected_val;
            expected_val = (i * 13 + 7) & 8'hFF;

            @(posedge clk);
            ifmap_rd_addr = i;
            @(posedge clk);

            if (ifmap_rd_data == expected_val) begin
                $display("  Sequential read [%0d]: 0x%02h PASS", i, ifmap_rd_data);
                test_passed++;
            end else begin
                $display("  Sequential read [%0d]: 0x%02h (expected 0x%02h) FAIL",
                    i, ifmap_rd_data, expected_val);
                test_failed++;
            end
        end

        // =================================================================
        // Additional: Sequential write 16 values to ofmap, read back
        // =================================================================
        $display("\n=== Test 5b: Sequential ofmap Write 16, Read Back ===");

        for (int i = 0; i < 16; i++) begin
            @(posedge clk);
            ofmap_wr_addr = i;
            ofmap_wr_data = (i * 7 + 3) & 8'hFF;
            ofmap_we = 1'b1;
        end
        @(posedge clk);
        ofmap_we = 1'b0;

        for (int i = 0; i < 16; i++) begin
            logic [7:0] expected_val;
            expected_val = (i * 7 + 3) & 8'hFF;

            @(posedge clk);
            ofmap_rd_addr = i;
            @(posedge clk);

            if (ofmap_rd_data == expected_val) begin
                $display("  Sequential read [%0d]: 0x%02h PASS", i, ofmap_rd_data);
                test_passed++;
            end else begin
                $display("  Sequential read [%0d]: 0x%02h (expected 0x%02h) FAIL",
                    i, ofmap_rd_data, expected_val);
                test_failed++;
            end
        end

        // =================================================================
        // Summary
        // =================================================================
        $display("\n========================================");
        $display("Test Summary");
        $display("========================================");
        $display("Tests passed: %0d", test_passed);
        $display("Tests failed: %0d", test_failed);

        if (test_failed == 0) begin
            $display("\nALL TESTS PASSED");
        end else begin
            $display("\nSOME TESTS FAILED");
        end
        $display("========================================\n");

        repeat(10) @(posedge clk);
        $finish;
    end

    // Timeout watchdog
    initial begin
        #100000;
        $display("\nERROR: Simulation timeout!\n");
        $finish;
    end

    // Waveform dump
    initial begin
        $dumpfile("tb_cnn_memory_subsystem.vcd");
        $dumpvars(0, tb_cnn_memory_subsystem);
    end

endmodule
