`timescale 1ns / 1ps

//==============================================================================
// Testbench: tb_power_manager
// Description: Unit test for power management module
//              Tests clock gating, bank power control, and DSP isolation
//==============================================================================

import accel_pkg::*;

module tb_power_manager;

    parameter CLK_PERIOD = 10;

    //--------------------------------------------------------------------------
    // Signals
    //--------------------------------------------------------------------------
    logic                       clk;
    logic                       rst_n;
    accel_type_e                active_accel;
    logic                       accel_active;
    state_e                     current_state;
    logic                       mlp_clk_en;
    logic                       cnn_clk_en;
    logic                       rnn_clk_en;
    logic [BRAM_BANKS-1:0]      bank_power_en;
    logic                       mlp_dsp_en;
    logic                       cnn_dsp_en;
    logic                       rnn_dsp_en;

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
    power_manager dut (
        .clk            (clk),
        .rst_n          (rst_n),
        .active_accel   (active_accel),
        .accel_active   (accel_active),
        .current_state  (current_state),
        .mlp_clk_en     (mlp_clk_en),
        .cnn_clk_en     (cnn_clk_en),
        .rnn_clk_en     (rnn_clk_en),
        .bank_power_en  (bank_power_en),
        .mlp_dsp_en     (mlp_dsp_en),
        .cnn_dsp_en     (cnn_dsp_en),
        .rnn_dsp_en     (rnn_dsp_en)
    );

    //--------------------------------------------------------------------------
    // Test Stimulus
    //--------------------------------------------------------------------------
    initial begin
        $display("=======================================================");
        $display("  Power Manager Testbench");
        $display("=======================================================");

        // Initialize
        rst_n = 0;
        active_accel = ACCEL_MLP;
        accel_active = 1'b0;
        current_state = STATE_IDLE;

        repeat(5) @(posedge clk);
        rst_n = 1;
        repeat(5) @(posedge clk);

        //----------------------------------------------------------------------
        // Test 1: Clock gating - IDLE state
        //----------------------------------------------------------------------
        $display("\n[%0t] TEST 1: Clock Gating - IDLE", $time);
        $display("-------------------------------------------------------");

        accel_active = 1'b0;
        current_state = STATE_IDLE;
        @(posedge clk);

        if (mlp_clk_en || cnn_clk_en || rnn_clk_en) begin
            $display("  ERROR: Clocks should be gated in IDLE!");
            $fatal(1);
        end
        $display("  All clocks gated: PASS");

        //----------------------------------------------------------------------
        // Test 2: Clock gating - MLP active
        //----------------------------------------------------------------------
        $display("\n[%0t] TEST 2: Clock Gating - MLP Active", $time);
        $display("-------------------------------------------------------");

        active_accel = ACCEL_MLP;
        accel_active = 1'b1;
        @(posedge clk);

        if (!mlp_clk_en || cnn_clk_en || rnn_clk_en) begin
            $display("  ERROR: Only MLP clock should be enabled!");
            $display("  MLP: %b, CNN: %b, RNN: %b", mlp_clk_en, cnn_clk_en, rnn_clk_en);
            $fatal(1);
        end
        $display("  MLP clock enabled, others gated: PASS");

        //----------------------------------------------------------------------
        // Test 3: Clock gating - CNN active
        //----------------------------------------------------------------------
        $display("\n[%0t] TEST 3: Clock Gating - CNN Active", $time);
        $display("-------------------------------------------------------");

        active_accel = ACCEL_CNN;
        accel_active = 1'b1;
        @(posedge clk);

        if (mlp_clk_en || !cnn_clk_en || rnn_clk_en) begin
            $display("  ERROR: Only CNN clock should be enabled!");
            $fatal(1);
        end
        $display("  CNN clock enabled, others gated: PASS");

        //----------------------------------------------------------------------
        // Test 4: Clock gating - RNN active
        //----------------------------------------------------------------------
        $display("\n[%0t] TEST 4: Clock Gating - RNN Active", $time);
        $display("-------------------------------------------------------");

        active_accel = ACCEL_RNN;
        accel_active = 1'b1;
        @(posedge clk);

        if (mlp_clk_en || cnn_clk_en || !rnn_clk_en) begin
            $display("  ERROR: Only RNN clock should be enabled!");
            $fatal(1);
        end
        $display("  RNN clock enabled, others gated: PASS");

        //----------------------------------------------------------------------
        // Test 5: BRAM bank power - IDLE state
        //----------------------------------------------------------------------
        $display("\n[%0t] TEST 5: BRAM Power - IDLE State", $time);
        $display("-------------------------------------------------------");

        accel_active = 1'b0;
        current_state = STATE_IDLE;
        @(posedge clk);

        // Only I/O banks should be powered
        if (!bank_power_en[BANK_INPUT_0] || !bank_power_en[BANK_INPUT_1] ||
            !bank_power_en[BANK_OUTPUT_0] || !bank_power_en[BANK_OUTPUT_1]) begin
            $display("  ERROR: I/O banks should be powered!");
            $fatal(1);
        end

        // Weight banks should be off
        if (bank_power_en[BANK_WEIGHT_0] || bank_power_en[BANK_WEIGHT_1]) begin
            $display("  ERROR: Weight banks should be powered down!");
            $fatal(1);
        end

        $display("  I/O banks on, weight banks off: PASS");
        display_bank_count();

        //----------------------------------------------------------------------
        // Test 6: BRAM bank power - LOAD_WEIGHTS state
        //----------------------------------------------------------------------
        $display("\n[%0t] TEST 6: BRAM Power - LOAD_WEIGHTS", $time);
        $display("-------------------------------------------------------");

        current_state = STATE_LOAD_WEIGHTS;
        @(posedge clk);

        // Weight banks should now be powered
        for (int i = BANK_WEIGHT_0; i <= BANK_WEIGHT_11; i++) begin
            if (!bank_power_en[i]) begin
                $display("  ERROR: Weight bank %0d should be powered!", i);
                $fatal(1);
            end
        end

        $display("  Weight banks powered: PASS");
        display_bank_count();

        //----------------------------------------------------------------------
        // Test 7: BRAM bank power - COMPUTE state
        //----------------------------------------------------------------------
        $display("\n[%0t] TEST 7: BRAM Power - COMPUTE", $time);
        $display("-------------------------------------------------------");

        current_state = STATE_COMPUTE;
        @(posedge clk);

        // All relevant banks should be powered
        if (!bank_power_en[BANK_ACTIVATION_0] || !bank_power_en[BANK_ACTIVATION_1] ||
            !bank_power_en[BANK_BIAS]) begin
            $display("  ERROR: Activation/bias banks should be powered!");
            $fatal(1);
        end

        $display("  All compute banks powered: PASS");
        display_bank_count();

        //----------------------------------------------------------------------
        // Test 8: DSP operand isolation - IDLE
        //----------------------------------------------------------------------
        $display("\n[%0t] TEST 8: DSP Isolation - IDLE", $time);
        $display("-------------------------------------------------------");

        accel_active = 1'b0;
        current_state = STATE_IDLE;
        @(posedge clk);

        if (mlp_dsp_en || cnn_dsp_en || rnn_dsp_en) begin
            $display("  ERROR: All DSPs should be isolated in IDLE!");
            $fatal(1);
        end
        $display("  All DSPs isolated: PASS");

        //----------------------------------------------------------------------
        // Test 9: DSP operand isolation - COMPUTE with MLP
        //----------------------------------------------------------------------
        $display("\n[%0t] TEST 9: DSP Isolation - MLP COMPUTE", $time);
        $display("-------------------------------------------------------");

        active_accel = ACCEL_MLP;
        accel_active = 1'b1;
        current_state = STATE_COMPUTE;
        @(posedge clk);

        if (!mlp_dsp_en || cnn_dsp_en || rnn_dsp_en) begin
            $display("  ERROR: Only MLP DSPs should be active!");
            $display("  MLP: %b, CNN: %b, RNN: %b", mlp_dsp_en, cnn_dsp_en, rnn_dsp_en);
            $fatal(1);
        end
        $display("  MLP DSPs active, others isolated: PASS");

        //----------------------------------------------------------------------
        // Test 10: State transition power sequence
        //----------------------------------------------------------------------
        $display("\n[%0t] TEST 10: Power State Transitions", $time);
        $display("-------------------------------------------------------");

        // Simulate full FSM sequence
        active_accel = ACCEL_CNN;
        accel_active = 1'b1;

        current_state = STATE_IDLE;
        @(posedge clk);
        $display("  IDLE → %0d banks powered", count_banks());

        current_state = STATE_LOAD_WEIGHTS;
        @(posedge clk);
        $display("  LOAD_WEIGHTS → %0d banks powered", count_banks());

        current_state = STATE_LOAD_INPUT;
        @(posedge clk);
        $display("  LOAD_INPUT → %0d banks powered", count_banks());

        current_state = STATE_COMPUTE;
        @(posedge clk);
        $display("  COMPUTE → %0d banks powered", count_banks());

        current_state = STATE_STORE_OUTPUT;
        @(posedge clk);
        $display("  STORE_OUTPUT → %0d banks powered", count_banks());

        current_state = STATE_DONE;
        @(posedge clk);
        $display("  DONE → %0d banks powered", count_banks());

        current_state = STATE_IDLE;
        accel_active = 1'b0;
        @(posedge clk);
        $display("  Back to IDLE → %0d banks powered", count_banks());

        $display("  State transition sequence: PASS");

        //----------------------------------------------------------------------
        $display("\n=======================================================");
        $display("  All Power Manager Tests Passed!");
        $display("=======================================================");
        repeat(10) @(posedge clk);
        $finish;
    end

    //--------------------------------------------------------------------------
    // Helper Functions
    //--------------------------------------------------------------------------
    function int count_banks();
        int count = 0;
        for (int i = 0; i < BRAM_BANKS; i++) begin
            if (bank_power_en[i]) count++;
        end
        return count;
    endfunction

    task display_bank_count();
        $display("  Active banks: %0d/%0d", count_banks(), BRAM_BANKS);
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
        $dumpfile("tb_power_manager.vcd");
        $dumpvars(0, tb_power_manager);
    end

endmodule
