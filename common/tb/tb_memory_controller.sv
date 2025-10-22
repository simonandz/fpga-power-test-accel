`timescale 1ns / 1ps

//==============================================================================
// Testbench: tb_memory_controller
// Description: Unit test for memory controller with BRAM banking
//==============================================================================

import accel_pkg::*;

module tb_memory_controller;

    parameter CLK_PERIOD = 10;

    //--------------------------------------------------------------------------
    // Signals
    //--------------------------------------------------------------------------
    logic                       clk;
    logic                       rst_n;
    mem_req_t                   req;
    mem_resp_t                  resp;
    logic [BRAM_BANKS-1:0]      bank_power_en;

    logic [BRAM_BANKS-1:0]              bram_en;
    logic [BRAM_BANKS-1:0]              bram_we;
    logic [BRAM_ADDR_WIDTH-1:0]         bram_addr   [BRAM_BANKS-1:0];
    logic [DATA_WIDTH-1:0]              bram_din    [BRAM_BANKS-1:0];
    logic [DATA_WIDTH-1:0]              bram_dout   [BRAM_BANKS-1:0];

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
    memory_controller dut (
        .clk            (clk),
        .rst_n          (rst_n),
        .req            (req),
        .resp           (resp),
        .bank_power_en  (bank_power_en),
        .bram_en        (bram_en),
        .bram_we        (bram_we),
        .bram_addr      (bram_addr),
        .bram_din       (bram_din),
        .bram_dout      (bram_dout)
    );

    //--------------------------------------------------------------------------
    // BRAM Models (simple behavioral)
    //--------------------------------------------------------------------------
    genvar i;
    generate
        for (i = 0; i < BRAM_BANKS; i++) begin : gen_bram
            bram_bank #(
                .DATA_WIDTH(DATA_WIDTH),
                .ADDR_WIDTH(BRAM_ADDR_WIDTH),
                .DEPTH(BRAM_DEPTH)
            ) bram (
                .clk    (clk),
                .en     (bram_en[i]),
                .we     (bram_we[i]),
                .addr   (bram_addr[i]),
                .din    (bram_din[i]),
                .dout   (bram_dout[i])
            );
        end
    endgenerate

    //--------------------------------------------------------------------------
    // Test Stimulus
    //--------------------------------------------------------------------------
    initial begin
        $display("=======================================================");
        $display("  Memory Controller Testbench");
        $display("=======================================================");

        // Initialize
        rst_n = 0;
        req.addr     = '0;
        req.data     = '0;
        req.we       = 1'b0;
        req.re       = 1'b0;
        req.bank_sel = '0;
        bank_power_en = '1;  // All banks powered

        repeat(5) @(posedge clk);
        rst_n = 1;
        @(posedge clk);

        //----------------------------------------------------------------------
        // Test 1: Write to different banks
        //----------------------------------------------------------------------
        $display("\n[%0t] TEST 1: Write to Multiple Banks", $time);
        $display("-------------------------------------------------------");

        // Write to bank 0
        write_mem(BANK_INPUT_0, 16'h0010, 8'hAA);
        repeat(3) @(posedge clk);  // Wait for write to settle
        // Write to bank 4 (weight bank)
        write_mem(BANK_WEIGHT_0, 16'h0020, 8'hBB);
        repeat(3) @(posedge clk);  // Wait for write to settle
        // Write to bank 18 (bias)
        write_mem(BANK_BIAS, 16'h0005, 8'hCC);

        repeat(10) @(posedge clk);  // Extra wait before reads

        //----------------------------------------------------------------------
        // Test 2: Read back and verify
        //----------------------------------------------------------------------
        $display("\n[%0t] TEST 2: Read and Verify", $time);
        $display("-------------------------------------------------------");

        read_and_check(BANK_INPUT_0, 16'h0010, 8'hAA);
        read_and_check(BANK_WEIGHT_0, 16'h0020, 8'hBB);
        read_and_check(BANK_BIAS, 16'h0005, 8'hCC);

        //----------------------------------------------------------------------
        // Test 3: Power-down bank access
        //----------------------------------------------------------------------
        $display("\n[%0t] TEST 3: Power-Down Bank", $time);
        $display("-------------------------------------------------------");

        // Power down bank 4
        bank_power_en[BANK_WEIGHT_0] = 1'b0;
        @(posedge clk);

        // Try to write (should not work)
        write_mem(BANK_WEIGHT_0, 16'h0030, 8'hDD);
        repeat(3) @(posedge clk);

        // Power back on
        bank_power_en[BANK_WEIGHT_0] = 1'b1;
        @(posedge clk);

        // Verify old data still there (write was blocked)
        read_and_check(BANK_WEIGHT_0, 16'h0020, 8'hBB);

        //----------------------------------------------------------------------
        // Test 4: Sequential burst write/read
        //----------------------------------------------------------------------
        $display("\n[%0t] TEST 4: Burst Access", $time);
        $display("-------------------------------------------------------");

        for (int j = 0; j < 16; j++) begin
            write_mem(BANK_INPUT_0, j, j[7:0]);
        end

        for (int j = 0; j < 16; j++) begin
            read_and_check(BANK_INPUT_0, j, j[7:0]);
        end

        //----------------------------------------------------------------------
        // Test 5: All banks independence
        //----------------------------------------------------------------------
        $display("\n[%0t] TEST 5: Bank Independence", $time);
        $display("-------------------------------------------------------");

        // Write same address to multiple banks
        write_mem(BANK_INPUT_0, 16'h0100, 8'h11);
        write_mem(BANK_INPUT_1, 16'h0100, 8'h22);
        write_mem(BANK_OUTPUT_0, 16'h0100, 8'h33);
        write_mem(BANK_OUTPUT_1, 16'h0100, 8'h44);

        repeat(3) @(posedge clk);

        // Verify each bank has different data
        read_and_check(BANK_INPUT_0, 16'h0100, 8'h11);
        read_and_check(BANK_INPUT_1, 16'h0100, 8'h22);
        read_and_check(BANK_OUTPUT_0, 16'h0100, 8'h33);
        read_and_check(BANK_OUTPUT_1, 16'h0100, 8'h44);

        //----------------------------------------------------------------------
        $display("\n=======================================================");
        $display("  All Memory Controller Tests Passed!");
        $display("=======================================================");
        repeat(10) @(posedge clk);
        $finish;
    end

    //--------------------------------------------------------------------------
    // Helper Tasks
    //--------------------------------------------------------------------------
    task write_mem(input logic [4:0] bank, input logic [15:0] addr, input logic [7:0] data);
        @(posedge clk);
        req.bank_sel = bank;
        req.addr     = addr;
        req.data     = data;
        req.we       = 1'b1;
        req.re       = 1'b0;
        @(posedge clk);
        req.we       = 1'b0;
        $display("  Write: Bank[%0d] Addr[0x%0h] = 0x%0h", bank, addr, data);
    endtask

    task read_and_check(input logic [4:0] bank, input logic [15:0] addr, input logic [7:0] expected);
        logic [7:0] read_data;
        @(posedge clk);
        req.bank_sel = bank;
        req.addr     = addr;
        req.we       = 1'b0;
        req.re       = 1'b1;
        @(posedge clk);  // Cycle N+1: BRAM reads, re_q=1
        req.re       = 1'b0;
        @(posedge clk);  // Cycle N+2: resp.valid=1, data available
        // Sample immediately after clock edge
        read_data = resp.data;

        if (resp.valid) begin
            if (read_data == expected) begin
                $display("  Read:  Bank[%0d] Addr[0x%0h] = 0x%0h ✓", bank, addr, read_data);
            end else begin
                $display("  ERROR: Bank[%0d] Addr[0x%0h] = 0x%0h (expected 0x%0h)",
                         bank, addr, read_data, expected);
                $fatal(1, "Data mismatch!");
            end
        end else begin
            $display("  ERROR: No valid response! (read_data=0x%0h)", read_data);
            $fatal(1, "Response not valid!");
        end
    endtask

    //--------------------------------------------------------------------------
    // Timeout
    //--------------------------------------------------------------------------
    initial begin
        #100000;
        $display("\nERROR: Simulation timeout!");
        $finish;
    end

    //--------------------------------------------------------------------------
    // Waveform
    //--------------------------------------------------------------------------
    initial begin
        $dumpfile("tb_memory_controller.vcd");
        $dumpvars(0, tb_memory_controller);
    end

endmodule
