// Testbench for MLP Memory Subsystem
// Tests all BRAM read/write operations

`timescale 1ns / 1ps

module tb_mlp_memory_subsystem;

    logic clk, rst_n;

    // Host write interface
    logic [15:0] input_addr, weight_addr, bias_addr;
    logic [7:0] input_data, weight_data, bias_data;
    logic input_we, weight_we, bias_we;

    // Compute read interface
    logic [15:0] input_rd_addr, weight_rd_addr;
    logic [7:0] bias_rd_addr;
    logic [7:0] input_rd_data, weight_rd_data, bias_rd_data;

    // Output interface
    logic [15:0] output_wr_addr, output_rd_addr;
    logic [7:0] output_wr_data, output_rd_data;
    logic output_wr_en;

    int test_passed = 0;
    int test_failed = 0;

    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // DUT
    mlp_memory_subsystem dut (
        .clk(clk),
        .rst_n(rst_n),
        .input_addr(input_addr),
        .input_data(input_data),
        .input_we(input_we),
        .weight_addr(weight_addr),
        .weight_data(weight_data),
        .weight_we(weight_we),
        .bias_addr(bias_addr),
        .bias_data(bias_data),
        .bias_we(bias_we),
        .input_rd_addr(input_rd_addr),
        .input_rd_data(input_rd_data),
        .weight_rd_addr(weight_rd_addr),
        .weight_rd_data(weight_rd_data),
        .bias_rd_addr(bias_rd_addr),
        .bias_rd_data(bias_rd_data),
        .output_wr_addr(output_wr_addr),
        .output_wr_data(output_wr_data),
        .output_wr_en(output_wr_en),
        .output_rd_addr(output_rd_addr),
        .output_rd_data(output_rd_data)
    );

    // Test write/read task
    task test_write_read(
        input string mem_name,
        input [15:0] wr_addr,
        input [7:0] wr_data,
        input [15:0] rd_addr,
        output [7:0] rd_data,
        input string test_name
    );
        $display("--- %s ---", test_name);

        // Write
        @(posedge clk);
        case (mem_name)
            "input": begin
                input_addr = wr_addr;
                input_data = wr_data;
                input_we = 1'b1;
            end
            "weight": begin
                weight_addr = wr_addr;
                weight_data = wr_data;
                weight_we = 1'b1;
            end
            "bias": begin
                bias_addr = wr_addr[7:0];
                bias_data = wr_data;
                bias_we = 1'b1;
            end
            "output": begin
                output_wr_addr = wr_addr;
                output_wr_data = wr_data;
                output_wr_en = 1'b1;
            end
        endcase

        @(posedge clk);
        input_we = 1'b0;
        weight_we = 1'b0;
        bias_we = 1'b0;
        output_wr_en = 1'b0;

        // Read (with 1 cycle latency)
        @(posedge clk);
        case (mem_name)
            "input": input_rd_addr = rd_addr;
            "weight": weight_rd_addr = rd_addr;
            "bias": bias_rd_addr = rd_addr[7:0];
            "output": output_rd_addr = rd_addr;
        endcase

        @(posedge clk);
        case (mem_name)
            "input": rd_data = input_rd_data;
            "weight": rd_data = weight_rd_data;
            "bias": rd_data = bias_rd_data;
            "output": rd_data = output_rd_data;
        endcase

        $display("  Written: 0x%02h at addr 0x%04h", wr_data, wr_addr);
        $display("  Read:    0x%02h from addr 0x%04h", rd_data, rd_addr);

        if (rd_data == wr_data) begin
            $display("✓ PASS\n");
            test_passed++;
        end else begin
            $display("✗ FAIL\n");
            test_failed++;
        end
    endtask

    initial begin
        logic [7:0] read_data;

        $display("========================================");
        $display("MLP Memory Subsystem Testbench");
        $display("========================================");

        // Initialize
        rst_n = 0;
        input_addr = 0; input_data = 0; input_we = 0;
        weight_addr = 0; weight_data = 0; weight_we = 0;
        bias_addr = 0; bias_data = 0; bias_we = 0;
        input_rd_addr = 0; weight_rd_addr = 0; bias_rd_addr = 0;
        output_wr_addr = 0; output_wr_data = 0; output_wr_en = 0;
        output_rd_addr = 0;

        repeat(10) @(posedge clk);
        rst_n = 1;
        repeat(5) @(posedge clk);

        // Test Input BRAM
        $display("\n=== Testing Input BRAM ===");
        test_write_read("input", 16'h0000, 8'hAA, 16'h0000, read_data, "Input: Address 0");
        test_write_read("input", 16'h0010, 8'h55, 16'h0010, read_data, "Input: Address 16");
        test_write_read("input", 16'h0FFF, 8'hFF, 16'h0FFF, read_data, "Input: Last address");

        // Test Weight BRAM
        $display("\n=== Testing Weight BRAM ===");
        test_write_read("weight", 16'h0000, 8'h11, 16'h0000, read_data, "Weight: Address 0");
        test_write_read("weight", 16'h0100, 8'h22, 16'h0100, read_data, "Weight: Address 256");
        test_write_read("weight", 16'h3FFF, 8'h33, 16'h3FFF, read_data, "Weight: Last address");

        // Test Bias BRAM
        $display("\n=== Testing Bias BRAM ===");
        test_write_read("bias", 16'h0000, 8'h44, 16'h0000, read_data, "Bias: Address 0");
        test_write_read("bias", 16'h0080, 8'h88, 16'h0080, read_data, "Bias: Address 128");
        test_write_read("bias", 16'h00FF, 8'hCC, 16'h00FF, read_data, "Bias: Last address");

        // Test Output BRAM
        $display("\n=== Testing Output BRAM ===");
        test_write_read("output", 16'h0000, 8'h77, 16'h0000, read_data, "Output: Address 0");
        test_write_read("output", 16'h0200, 8'hBB, 16'h0200, read_data, "Output: Address 512");
        test_write_read("output", 16'h0FFF, 8'hEE, 16'h0FFF, read_data, "Output: Last address");

        // Test sequential write/read
        $display("\n=== Testing Sequential Operations ===");
        for (int i = 0; i < 8; i++) begin
            @(posedge clk);
            input_addr = i;
            input_data = i + 1;
            input_we = 1'b1;
        end
        @(posedge clk);
        input_we = 1'b0;

        // Read back
        for (int i = 0; i < 8; i++) begin
            @(posedge clk);
            input_rd_addr = i;
            @(posedge clk);
            if (input_rd_data == (i + 1)) begin
                $display("  Sequential read [%0d]: 0x%02h ✓", i, input_rd_data);
                test_passed++;
            end else begin
                $display("  Sequential read [%0d]: 0x%02h (expected 0x%02h) ✗", i, input_rd_data, i+1);
                test_failed++;
            end
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
        $dumpfile("tb_mlp_memory_subsystem.vcd");
        $dumpvars(0, tb_mlp_memory_subsystem);
    end

endmodule
