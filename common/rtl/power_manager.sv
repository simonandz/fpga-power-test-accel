`timescale 1ns / 1ps

//==============================================================================
// Module: power_manager
// Description: Centralized power management for accelerator framework
//              - Clock gating for idle compute units
//              - BRAM bank power-down control
//              - DSP operand isolation
//==============================================================================

import accel_pkg::*;

module power_manager (
    input  logic                    clk,
    input  logic                    rst_n,

    // Accelerator selection
    input  accel_type_e             active_accel,
    input  logic                    accel_active,

    // State information
    input  state_e                  current_state,

    // Clock gating outputs
    output logic                    mlp_clk_en,
    output logic                    cnn_clk_en,
    output logic                    rnn_clk_en,

    // BRAM bank power control
    output logic [BRAM_BANKS-1:0]   bank_power_en,

    // DSP operand isolation
    output logic                    mlp_dsp_en,
    output logic                    cnn_dsp_en,
    output logic                    rnn_dsp_en
);

    //--------------------------------------------------------------------------
    // Clock Gate Control
    //--------------------------------------------------------------------------
    always_comb begin
        mlp_clk_en = 1'b0;
        cnn_clk_en = 1'b0;
        rnn_clk_en = 1'b0;

        if (accel_active) begin
            case (active_accel)
                ACCEL_MLP: mlp_clk_en = 1'b1;
                ACCEL_CNN: cnn_clk_en = 1'b1;
                ACCEL_RNN: rnn_clk_en = 1'b1;
                default:   ;  // All disabled
            endcase
        end
    end

    //--------------------------------------------------------------------------
    // BRAM Bank Power Management
    //--------------------------------------------------------------------------
    always_comb begin
        // Default: power down all banks
        bank_power_en = '0;

        // Always-on banks
        bank_power_en[BANK_INPUT_0]  = 1'b1;  // Input buffers always accessible
        bank_power_en[BANK_INPUT_1]  = 1'b1;
        bank_power_en[BANK_OUTPUT_0] = 1'b1;  // Output buffers always accessible
        bank_power_en[BANK_OUTPUT_1] = 1'b1;

        // State-dependent power management
        case (current_state)
            STATE_IDLE: begin
                // Only input/output banks powered (done above)
            end

            STATE_LOAD_WEIGHTS: begin
                // Power on weight banks
                bank_power_en[BANK_WEIGHT_0]  = 1'b1;
                bank_power_en[BANK_WEIGHT_1]  = 1'b1;
                bank_power_en[BANK_WEIGHT_2]  = 1'b1;
                bank_power_en[BANK_WEIGHT_3]  = 1'b1;
                bank_power_en[BANK_WEIGHT_4]  = 1'b1;
                bank_power_en[BANK_WEIGHT_5]  = 1'b1;
                bank_power_en[BANK_WEIGHT_6]  = 1'b1;
                bank_power_en[BANK_WEIGHT_7]  = 1'b1;
                bank_power_en[BANK_WEIGHT_8]  = 1'b1;
                bank_power_en[BANK_WEIGHT_9]  = 1'b1;
                bank_power_en[BANK_WEIGHT_10] = 1'b1;
                bank_power_en[BANK_WEIGHT_11] = 1'b1;
            end

            STATE_LOAD_INPUT: begin
                // Input banks already powered
            end

            STATE_COMPUTE: begin
                // Power on all required banks during computation
                bank_power_en[BANK_WEIGHT_0]      = 1'b1;
                bank_power_en[BANK_WEIGHT_1]      = 1'b1;
                bank_power_en[BANK_WEIGHT_2]      = 1'b1;
                bank_power_en[BANK_WEIGHT_3]      = 1'b1;
                bank_power_en[BANK_WEIGHT_4]      = 1'b1;
                bank_power_en[BANK_WEIGHT_5]      = 1'b1;
                bank_power_en[BANK_WEIGHT_6]      = 1'b1;
                bank_power_en[BANK_WEIGHT_7]      = 1'b1;
                bank_power_en[BANK_WEIGHT_8]      = 1'b1;
                bank_power_en[BANK_WEIGHT_9]      = 1'b1;
                bank_power_en[BANK_WEIGHT_10]     = 1'b1;
                bank_power_en[BANK_WEIGHT_11]     = 1'b1;
                bank_power_en[BANK_ACTIVATION_0]  = 1'b1;
                bank_power_en[BANK_ACTIVATION_1]  = 1'b1;
                bank_power_en[BANK_BIAS]          = 1'b1;
            end

            STATE_STORE_OUTPUT: begin
                // Output banks already powered
            end

            STATE_DONE: begin
                // Output banks remain powered for readout
            end

            default: begin
                // Minimal power in unknown state
            end
        endcase
    end

    //--------------------------------------------------------------------------
    // DSP Operand Isolation
    // Zero inputs to unused DSP slices to reduce toggle activity
    //--------------------------------------------------------------------------
    always_comb begin
        mlp_dsp_en = 1'b0;
        cnn_dsp_en = 1'b0;
        rnn_dsp_en = 1'b0;

        if (current_state == STATE_COMPUTE && accel_active) begin
            case (active_accel)
                ACCEL_MLP: mlp_dsp_en = 1'b1;
                ACCEL_CNN: cnn_dsp_en = 1'b1;
                ACCEL_RNN: rnn_dsp_en = 1'b1;
                default:   ;
            endcase
        end
    end

    //--------------------------------------------------------------------------
    // Power State Reporting (for debug/monitoring)
    //--------------------------------------------------------------------------
    `ifdef SIMULATION
    integer active_banks;

    function automatic integer count_active_banks;
        input logic [BRAM_BANKS-1:0] banks;
        integer i, count;
        begin
            count = 0;
            for (i = 0; i < BRAM_BANKS; i = i + 1) begin
                if (banks[i])
                    count = count + 1;
            end
            count_active_banks = count;
        end
    endfunction

    always_comb begin
        active_banks = count_active_banks(bank_power_en);
    end

    // Monitor power state changes
    logic [BRAM_BANKS-1:0] bank_power_en_q;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            bank_power_en_q <= '0;
        end else begin
            bank_power_en_q <= bank_power_en;
            if (bank_power_en != bank_power_en_q)
                $display("[PowerMgr @ %0t] Active BRAM banks: %0d/%0d",
                        $time, active_banks, BRAM_BANKS);
        end
    end
    `endif

endmodule
