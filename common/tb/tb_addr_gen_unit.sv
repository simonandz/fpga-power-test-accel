`timescale 1ns / 1ps

//==============================================================================
// Testbench: tb_addr_gen_unit
// Description: Unit test for address generation unit
//              Tests sequential, 2D sliding window, and circular patterns
//==============================================================================

import accel_pkg::*;

module tb_addr_gen_unit;

    parameter CLK_PERIOD = 10;

    //--------------------------------------------------------------------------
    // Signals
    //--------------------------------------------------------------------------
    logic                       clk;
    logic                       rst_n;
    logic                       start;
    access_pattern_e            pattern;
    logic [ADDR_WIDTH-1:0]      base_addr;
    logic [15:0]                length;
    logic                       done;
    logic [7:0]                 stride;
    logic [7:0]                 width;
    logic [7:0]                 height;
    logic [7:0]                 kernel_size;
    logic [ADDR_WIDTH-1:0]      addr;
    logic                       addr_valid;
    logic                       addr_ready;

    // Capture addresses
    logic [ADDR_WIDTH-1:0]      captured_addrs[1024];
    integer                     addr_count;

    //--------------------------------------------------------------------------
    // Clock Generation
    //--------------------------------------------------------------------------
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    //--------------------------------------------------------------------------
    // DUT
    //--------------------------------------------------------------------------
    addr_gen_unit dut (
        .clk            (clk),
        .rst_n          (rst_n),
        .start          (start),
        .pattern        (pattern),
        .base_addr      (base_addr),
        .length         (length),
        .done           (done),
        .stride         (stride),
        .width          (width),
        .height         (height),
        .kernel_size    (kernel_size),
        .addr           (addr),
        .addr_valid     (addr_valid),
        .addr_ready     (addr_ready)
    );

    //--------------------------------------------------------------------------
    // Capture addresses
    //--------------------------------------------------------------------------
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            addr_count <= 0;
        end else if (addr_valid && addr_ready) begin
            captured_addrs[addr_count] <= addr;
            addr_count <= addr_count + 1;
        end
    end

    //--------------------------------------------------------------------------
    // Test Stimulus
    //--------------------------------------------------------------------------
    initial begin
        $display("=======================================================");
        $display("  Address Generator Unit Testbench");
        $display("=======================================================");

        // Initialize
        rst_n = 0;
        start = 0;
        pattern = ACCESS_SEQUENTIAL;
        base_addr = '0;
        length = '0;
        stride = 8'd1;
        width = 8'd28;
        height = 8'd28;
        kernel_size = 8'd3;
        addr_ready = 1'b1;  // Always ready for this test

        repeat(5) @(posedge clk);
        rst_n = 1;
        repeat(5) @(posedge clk);

        //----------------------------------------------------------------------
        // Test 1: Sequential Access
        //----------------------------------------------------------------------
        $display("\n[%0t] TEST 1: Sequential Access Pattern", $time);
        $display("-------------------------------------------------------");

        addr_count = 0;
        pattern = ACCESS_SEQUENTIAL;
        base_addr = 16'h1000;
        length = 16'd10;

        start_test();

        // Verify addresses
        for (int i = 0; i < 10; i++) begin
            if (captured_addrs[i] != (16'h1000 + i)) begin
                $display("  ERROR: Addr[%0d] = 0x%0h, expected 0x%0h",
                         i, captured_addrs[i], 16'h1000 + i);
                $fatal(1, "Sequential pattern failed!");
            end
        end
        $display("  Sequential pattern: PASS (%0d addresses)", addr_count);

        //----------------------------------------------------------------------
        // Test 2: Sliding 2D Window (3x3 kernel, stride=1)
        //----------------------------------------------------------------------
        $display("\n[%0t] TEST 2: 2D Sliding Window (3x3, stride=1)", $time);
        $display("-------------------------------------------------------");

        addr_count = 0;
        pattern = ACCESS_SLIDING_2D;
        base_addr = 16'h2000;
        width = 8'd5;        // 5x5 input
        height = 8'd5;
        kernel_size = 8'd3;  // 3x3 kernel
        stride = 8'd1;
        length = 16'd27;     // 3 output positions × 9 kernel elements

        start_test();

        // Display first window addresses
        $display("  First 3x3 window at position (0,0):");
        for (int i = 0; i < 9; i++) begin
            $display("    Addr[%0d] = 0x%0h (offset %0d)",
                     i, captured_addrs[i], captured_addrs[i] - 16'h2000);
        end

        // Verify first window pattern:
        // Row 0: [0, 1, 2]
        // Row 1: [5, 6, 7]  (width=5)
        // Row 2: [10, 11, 12]
        if (captured_addrs[0] != 16'h2000 + 0 ||
            captured_addrs[1] != 16'h2000 + 1 ||
            captured_addrs[2] != 16'h2000 + 2 ||
            captured_addrs[3] != 16'h2000 + 5 ||
            captured_addrs[4] != 16'h2000 + 6 ||
            captured_addrs[5] != 16'h2000 + 7 ||
            captured_addrs[6] != 16'h2000 + 10 ||
            captured_addrs[7] != 16'h2000 + 11 ||
            captured_addrs[8] != 16'h2000 + 12) begin
            $display("  ERROR: 2D window pattern incorrect!");
            $fatal(1, "2D pattern failed!");
        end
        $display("  2D sliding window: PASS (%0d addresses)", addr_count);

        //----------------------------------------------------------------------
        // Test 3: Circular Buffer
        //----------------------------------------------------------------------
        $display("\n[%0t] TEST 3: Circular Buffer Access", $time);
        $display("-------------------------------------------------------");

        addr_count = 0;
        pattern = ACCESS_CIRCULAR;
        base_addr = 16'h3000;
        length = 16'd8;      // Buffer size = 8

        start_test();

        // First 8 should be sequential
        for (int i = 0; i < 8; i++) begin
            if (captured_addrs[i] != (16'h3000 + i)) begin
                $display("  ERROR: Circular addr[%0d] = 0x%0h, expected 0x%0h",
                         i, captured_addrs[i], 16'h3000 + i);
                $fatal(1, "Circular pattern failed!");
            end
        end
        $display("  Circular buffer: PASS (%0d addresses)", addr_count);

        //----------------------------------------------------------------------
        // Test 4: Backpressure handling
        //----------------------------------------------------------------------
        $display("\n[%0t] TEST 4: Backpressure (addr_ready toggling)", $time);
        $display("-------------------------------------------------------");

        addr_count = 0;
        pattern = ACCESS_SEQUENTIAL;
        base_addr = 16'h4000;
        length = 16'd5;

        fork
            // Start generation
            begin
                @(posedge clk);
                start = 1'b1;
                @(posedge clk);
                start = 1'b0;
            end

            // Toggle addr_ready
            begin
                repeat(2) @(posedge clk);
                for (int i = 0; i < 20; i++) begin
                    addr_ready = ~addr_ready;
                    @(posedge clk);
                end
                addr_ready = 1'b1;
            end
        join

        wait(done);
        @(posedge clk);

        if (addr_count == 5) begin
            $display("  Backpressure handling: PASS (received %0d addresses)", addr_count);
        end else begin
            $display("  ERROR: Expected 5 addresses, got %0d", addr_count);
            $fatal(1, "Backpressure test failed!");
        end

        //----------------------------------------------------------------------
        $display("\n=======================================================");
        $display("  All Address Generator Tests Passed!");
        $display("=======================================================");
        repeat(10) @(posedge clk);
        $finish;
    end

    //--------------------------------------------------------------------------
    // Helper Tasks
    //--------------------------------------------------------------------------
    task start_test();
        @(posedge clk);
        start = 1'b1;
        @(posedge clk);
        start = 1'b0;

        // Wait for completion
        wait(done);
        @(posedge clk);
    endtask

    //--------------------------------------------------------------------------
    // Monitor
    //--------------------------------------------------------------------------
    initial begin
        forever begin
            @(posedge clk);
            if (addr_valid && addr_ready) begin
                // Optionally log each address
                // $display("    [%0t] Generated addr: 0x%0h", $time, addr);
            end
        end
    end

    //--------------------------------------------------------------------------
    // Timeout
    //--------------------------------------------------------------------------
    initial begin
        #500000;
        $display("\nERROR: Simulation timeout!");
        $finish;
    end

    //--------------------------------------------------------------------------
    // Waveform
    //--------------------------------------------------------------------------
    initial begin
        $dumpfile("tb_addr_gen_unit.vcd");
        $dumpvars(0, tb_addr_gen_unit);
    end

endmodule
