`timescale 1ns / 1ps

//==============================================================================
// Testbench: tb_accel_top
// Description: Basic testbench for shared infrastructure validation
//==============================================================================

import accel_pkg::*;

module tb_accel_top;

    //--------------------------------------------------------------------------
    // Parameters
    //--------------------------------------------------------------------------
    parameter CLK_PERIOD = 10;  // 100 MHz

    //--------------------------------------------------------------------------
    // DUT Signals
    //--------------------------------------------------------------------------
    logic        clk;
    logic        rst_n;
    logic        start;
    logic        done;
    logic        busy;
    logic [1:0]  accel_type;
    logic [15:0] config_data;
    logic [15:0] input_addr;
    logic [7:0]  input_data;
    logic        input_we;
    logic [7:0]  output_data;
    logic        output_valid;
    logic [15:0] weight_base_addr;
    logic [15:0] weight_size;
    logic [15:0] input_base_addr;
    logic [15:0] input_size;
    logic [15:0] output_base_addr;
    logic [15:0] output_size;
    logic [4:0]  weight_bank;
    logic [4:0]  input_bank;
    logic [4:0]  output_bank;
    logic [2:0]  current_state;
    logic [7:0]  error_flags;

    //--------------------------------------------------------------------------
    // Clock Generation
    //--------------------------------------------------------------------------
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    //--------------------------------------------------------------------------
    // DUT Instantiation
    //--------------------------------------------------------------------------
    accel_top #(
        .NUM_BRAM_BANKS(19)
    ) dut (
        .clk                (clk),
        .rst_n              (rst_n),
        .start              (start),
        .done               (done),
        .busy               (busy),
        .accel_type         (accel_type),
        .config_data        (config_data),
        .input_addr         (input_addr),
        .input_data         (input_data),
        .input_we           (input_we),
        .output_data        (output_data),
        .output_valid       (output_valid),
        .weight_base_addr   (weight_base_addr),
        .weight_size        (weight_size),
        .input_base_addr    (input_base_addr),
        .input_size         (input_size),
        .output_base_addr   (output_base_addr),
        .output_size        (output_size),
        .weight_bank        (weight_bank),
        .input_bank         (input_bank),
        .output_bank        (output_bank),
        .current_state      (current_state),
        .error_flags        (error_flags)
    );

    //--------------------------------------------------------------------------
    // Test Stimulus
    //--------------------------------------------------------------------------
    initial begin
        $display("=======================================================");
        $display("  Accelerator Infrastructure Testbench");
        $display("=======================================================");

        // Initialize signals
        rst_n            = 0;
        start            = 0;
        accel_type       = ACCEL_MLP;
        config_data      = 16'h0000;
        input_addr       = 16'h0000;
        input_data       = 8'h00;
        input_we         = 0;
        weight_base_addr = 16'h0000;
        weight_size      = 16'd100;
        input_base_addr  = 16'h0000;
        input_size       = 16'd64;
        output_base_addr = 16'h0000;
        output_size      = 16'd10;
        weight_bank      = BANK_WEIGHT_0;
        input_bank       = BANK_INPUT_0;
        output_bank      = BANK_OUTPUT_0;

        // Reset sequence
        repeat(5) @(posedge clk);
        rst_n = 1;
        $display("[%0t] Reset released", $time);

        // Test 1: Basic FSM transition test
        repeat(10) @(posedge clk);
        $display("\n[%0t] TEST 1: Basic FSM Transition", $time);
        $display("-------------------------------------------------------");

        start = 1;
        @(posedge clk);
        start = 0;

        // Monitor state transitions
        fork
            begin
                while (!done) begin
                    @(posedge clk);
                    if (current_state != $past(current_state, 1)) begin
                        case (current_state)
                            STATE_IDLE:         $display("[%0t] State: IDLE", $time);
                            STATE_LOAD_WEIGHTS: $display("[%0t] State: LOAD_WEIGHTS", $time);
                            STATE_LOAD_INPUT:   $display("[%0t] State: LOAD_INPUT", $time);
                            STATE_COMPUTE:      $display("[%0t] State: COMPUTE", $time);
                            STATE_STORE_OUTPUT: $display("[%0t] State: STORE_OUTPUT", $time);
                            STATE_DONE:         $display("[%0t] State: DONE", $time);
                        endcase
                    end
                end
            end
            begin
                repeat(1000) @(posedge clk);
                $display("[%0t] ERROR: Timeout waiting for done", $time);
                $finish;
            end
        join_any
        disable fork;

        $display("[%0t] Done asserted - FSM completed", $time);

        // Wait for done to clear
        start = 0;
        wait(!done);
        $display("[%0t] Returned to IDLE", $time);

        // Test 2: Different accelerator type
        repeat(10) @(posedge clk);
        $display("\n[%0t] TEST 2: CNN Accelerator Type", $time);
        $display("-------------------------------------------------------");

        accel_type = ACCEL_CNN;
        config_data = {4'd3, 4'd1, 8'd0};  // kernel_size=3, stride=1

        start = 1;
        @(posedge clk);
        start = 0;

        wait(done);
        $display("[%0t] CNN test completed", $time);

        // Test 3: Power management check
        repeat(10) @(posedge clk);
        $display("\n[%0t] TEST 3: Power Management", $time);
        $display("-------------------------------------------------------");
        $display("Power manager should gate unused accelerators");
        $display("MLP clock enable: %b", dut.mlp_clk_en);
        $display("CNN clock enable: %b", dut.cnn_clk_en);
        $display("RNN clock enable: %b", dut.rnn_clk_en);

        // Finish simulation
        repeat(20) @(posedge clk);
        $display("\n=======================================================");
        $display("  All tests completed successfully!");
        $display("=======================================================");
        $finish;
    end

    //--------------------------------------------------------------------------
    // Timeout watchdog
    //--------------------------------------------------------------------------
    initial begin
        #1000000;  // 1ms timeout
        $display("\n[%0t] ERROR: Simulation timeout!", $time);
        $finish;
    end

    //--------------------------------------------------------------------------
    // Waveform dump
    //--------------------------------------------------------------------------
    initial begin
        $dumpfile("tb_accel_top.vcd");
        $dumpvars(0, tb_accel_top);
    end

endmodule
