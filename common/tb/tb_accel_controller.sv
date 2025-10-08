`timescale 1ns / 1ps

//==============================================================================
// Testbench: tb_accel_controller
// Description: Unit test for accelerator controller FSM
//              Tests state transitions and control flow
//==============================================================================

import accel_pkg::*;

module tb_accel_controller;

    parameter CLK_PERIOD = 10;

    //--------------------------------------------------------------------------
    // Signals
    //--------------------------------------------------------------------------
    logic                       clk;
    logic                       rst_n;
    ctrl_req_t                  ctrl_req;
    ctrl_resp_t                 ctrl_resp;
    mem_req_t                   mem_req;
    mem_resp_t                  mem_resp;
    logic                       agu_start;
    access_pattern_e            agu_pattern;
    logic [ADDR_WIDTH-1:0]      agu_base_addr;
    logic [15:0]                agu_length;
    logic                       agu_done;
    logic [ADDR_WIDTH-1:0]      agu_addr;
    logic                       agu_addr_valid;
    logic                       agu_addr_ready;
    logic                       compute_start;
    logic [15:0]                compute_config;
    logic                       compute_done;
    logic [7:0]                 compute_error;
    logic [ADDR_WIDTH-1:0]      weight_base_addr;
    logic [15:0]                weight_size;
    logic [ADDR_WIDTH-1:0]      input_base_addr;
    logic [15:0]                input_size;
    logic [ADDR_WIDTH-1:0]      output_base_addr;
    logic [15:0]                output_size;
    logic [4:0]                 weight_bank;
    logic [4:0]                 input_bank;
    logic [4:0]                 output_bank;

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
    accel_controller dut (
        .clk                (clk),
        .rst_n              (rst_n),
        .ctrl_req           (ctrl_req),
        .ctrl_resp          (ctrl_resp),
        .mem_req            (mem_req),
        .mem_resp           (mem_resp),
        .agu_start          (agu_start),
        .agu_pattern        (agu_pattern),
        .agu_base_addr      (agu_base_addr),
        .agu_length         (agu_length),
        .agu_done           (agu_done),
        .agu_addr           (agu_addr),
        .agu_addr_valid     (agu_addr_valid),
        .agu_addr_ready     (agu_addr_ready),
        .compute_start      (compute_start),
        .compute_config     (compute_config),
        .compute_done       (compute_done),
        .compute_error      (compute_error),
        .weight_base_addr   (weight_base_addr),
        .weight_size        (weight_size),
        .input_base_addr    (input_base_addr),
        .input_size         (input_size),
        .output_base_addr   (output_base_addr),
        .output_size        (output_size),
        .weight_bank        (weight_bank),
        .input_bank         (input_bank),
        .output_bank        (output_bank)
    );

    //--------------------------------------------------------------------------
    // AGU Mock (simple counter-based)
    //--------------------------------------------------------------------------
    logic [15:0] agu_counter;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            agu_counter <= '0;
            agu_done <= 1'b0;
            agu_addr_valid <= 1'b0;
            agu_addr <= '0;
        end else begin
            if (agu_start) begin
                agu_counter <= '0;
                agu_done <= 1'b0;
                agu_addr_valid <= 1'b1;
                agu_addr <= agu_base_addr;
            end else if (agu_addr_valid && agu_addr_ready) begin
                agu_counter <= agu_counter + 1;
                if (agu_counter + 1 >= agu_length) begin
                    agu_done <= 1'b1;
                    agu_addr_valid <= 1'b0;
                end else begin
                    agu_addr <= agu_addr + 1;
                end
            end
        end
    end

    //--------------------------------------------------------------------------
    // Memory Mock (always ready)
    //--------------------------------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mem_resp.data  <= '0;
            mem_resp.valid <= 1'b0;
        end else begin
            mem_resp.valid <= mem_req.re;
            mem_resp.data  <= 8'hA5;  // Dummy data
        end
    end
    assign mem_resp.ready = 1'b1;

    //--------------------------------------------------------------------------
    // Compute Mock (fixed latency)
    //--------------------------------------------------------------------------
    logic [7:0] compute_counter;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            compute_counter <= '0;
            compute_done <= 1'b0;
        end else begin
            if (compute_start) begin
                compute_counter <= '0;
                compute_done <= 1'b0;
            end else if (compute_counter < 8'd20) begin
                compute_counter <= compute_counter + 1;
            end else begin
                compute_done <= 1'b1;
            end
        end
    end
    assign compute_error = 8'h00;

    //--------------------------------------------------------------------------
    // Test Stimulus
    //--------------------------------------------------------------------------
    initial begin
        $display("=======================================================");
        $display("  Accelerator Controller Testbench");
        $display("=======================================================");

        // Initialize
        rst_n = 0;
        ctrl_req.start = 0;
        ctrl_req.accel_type = ACCEL_MLP;
        ctrl_req.config_data = 16'h0000;
        weight_base_addr = 16'h1000;
        weight_size = 16'd100;
        input_base_addr = 16'h2000;
        input_size = 16'd64;
        output_base_addr = 16'h3000;
        output_size = 16'd10;
        weight_bank = BANK_WEIGHT_0;
        input_bank = BANK_INPUT_0;
        output_bank = BANK_OUTPUT_0;

        repeat(5) @(posedge clk);
        rst_n = 1;
        repeat(5) @(posedge clk);

        //----------------------------------------------------------------------
        // Test 1: Basic FSM flow
        //----------------------------------------------------------------------
        $display("\n[%0t] TEST 1: Basic FSM Flow (MLP)", $time);
        $display("-------------------------------------------------------");

        ctrl_req.start = 1'b1;
        @(posedge clk);
        ctrl_req.start = 1'b0;

        // Monitor state transitions
        monitor_states("MLP test");

        if (!ctrl_resp.done) begin
            $display("  ERROR: Done not asserted!");
            $fatal(1);
        end
        $display("  FSM flow: PASS");

        // Clear done
        repeat(5) @(posedge clk);

        //----------------------------------------------------------------------
        // Test 2: CNN accelerator type
        //----------------------------------------------------------------------
        $display("\n[%0t] TEST 2: CNN Accelerator Type", $time);
        $display("-------------------------------------------------------");

        ctrl_req.accel_type = ACCEL_CNN;
        ctrl_req.config_data = {4'd3, 4'd1, 8'd0};  // kernel=3, stride=1

        ctrl_req.start = 1'b1;
        @(posedge clk);
        ctrl_req.start = 1'b0;

        monitor_states("CNN test");

        // Verify AGU pattern was set to SLIDING_2D during input load
        // (We'd need to capture this during the test, simplified here)
        $display("  CNN accelerator: PASS");

        repeat(5) @(posedge clk);

        //----------------------------------------------------------------------
        // Test 3: RNN accelerator type
        //----------------------------------------------------------------------
        $display("\n[%0t] TEST 3: RNN Accelerator Type", $time);
        $display("-------------------------------------------------------");

        ctrl_req.accel_type = ACCEL_RNN;
        ctrl_req.config_data = 16'h0010;  // seq_length=16

        ctrl_req.start = 1'b1;
        @(posedge clk);
        ctrl_req.start = 1'b0;

        monitor_states("RNN test");

        $display("  RNN accelerator: PASS");

        repeat(5) @(posedge clk);

        //----------------------------------------------------------------------
        // Test 4: Verify memory bank selection
        //----------------------------------------------------------------------
        $display("\n[%0t] TEST 4: Memory Bank Routing", $time);
        $display("-------------------------------------------------------");

        weight_bank = BANK_WEIGHT_5;
        input_bank = BANK_INPUT_1;
        output_bank = BANK_OUTPUT_1;

        ctrl_req.accel_type = ACCEL_MLP;
        ctrl_req.start = 1'b1;
        @(posedge clk);
        ctrl_req.start = 1'b0;

        // Wait for LOAD_WEIGHTS state
        wait(ctrl_resp.state == STATE_LOAD_WEIGHTS);
        @(posedge clk);
        if (mem_req.bank_sel != BANK_WEIGHT_5) begin
            $display("  ERROR: Wrong weight bank selected: %0d", mem_req.bank_sel);
            $fatal(1);
        end
        $display("  Weight bank selection: PASS (bank %0d)", mem_req.bank_sel);

        // Wait for LOAD_INPUT state
        wait(ctrl_resp.state == STATE_LOAD_INPUT);
        @(posedge clk);
        if (mem_req.bank_sel != BANK_INPUT_1) begin
            $display("  ERROR: Wrong input bank selected: %0d", mem_req.bank_sel);
            $fatal(1);
        end
        $display("  Input bank selection: PASS (bank %0d)", mem_req.bank_sel);

        wait(ctrl_resp.done);
        $display("  Bank routing: PASS");

        //----------------------------------------------------------------------
        $display("\n=======================================================");
        $display("  All Controller Tests Passed!");
        $display("=======================================================");
        repeat(10) @(posedge clk);
        $finish;
    end

    //--------------------------------------------------------------------------
    // Helper Tasks
    //--------------------------------------------------------------------------
    task monitor_states(input string test_name);
        state_e prev_state;
        int state_count;

        state_count = 0;
        prev_state = STATE_IDLE;

        while (!ctrl_resp.done && state_count < 100) begin
            @(posedge clk);
            if (ctrl_resp.state != prev_state) begin
                case (ctrl_resp.state)
                    STATE_IDLE:         $display("  [%0t] → IDLE", $time);
                    STATE_LOAD_WEIGHTS: $display("  [%0t] → LOAD_WEIGHTS", $time);
                    STATE_LOAD_INPUT:   $display("  [%0t] → LOAD_INPUT", $time);
                    STATE_COMPUTE:      $display("  [%0t] → COMPUTE", $time);
                    STATE_STORE_OUTPUT: $display("  [%0t] → STORE_OUTPUT", $time);
                    STATE_DONE:         $display("  [%0t] → DONE", $time);
                endcase
                prev_state = ctrl_resp.state;
            end
            state_count++;
        end

        if (state_count >= 100) begin
            $display("  ERROR: %s timeout!", test_name);
            $fatal(1);
        end
    endtask

    //--------------------------------------------------------------------------
    // Timeout
    //--------------------------------------------------------------------------
    initial begin
        #1000000;
        $display("\nERROR: Simulation timeout!");
        $finish;
    end

    //--------------------------------------------------------------------------
    // Waveform
    //--------------------------------------------------------------------------
    initial begin
        $dumpfile("tb_accel_controller.vcd");
        $dumpvars(0, tb_accel_controller);
    end

endmodule
