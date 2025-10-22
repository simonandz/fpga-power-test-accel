`timescale 1ns / 1ps

`ifndef ACCEL_PKG_SV
`define ACCEL_PKG_SV

//==============================================================================
// Package: accel_pkg
// Description: Common types, parameters, and definitions for accelerator framework
//==============================================================================

package accel_pkg;

    //--------------------------------------------------------------------------
    // Global Parameters
    //--------------------------------------------------------------------------
    parameter int DATA_WIDTH     = 8;      // Input/Weight/Output width
    parameter int ACCUM_WIDTH    = 16;     // Accumulator width
    parameter int ADDR_WIDTH     = 16;     // Address width
    parameter int BRAM_BANKS     = 19;     // Total BRAM banks

    //--------------------------------------------------------------------------
    // Memory Map Configuration
    //--------------------------------------------------------------------------
    typedef enum logic [4:0] {
        BANK_INPUT_0      = 5'd0,    // Input buffer ping
        BANK_INPUT_1      = 5'd1,    // Input buffer pong
        BANK_OUTPUT_0     = 5'd2,    // Output buffer ping
        BANK_OUTPUT_1     = 5'd3,    // Output buffer pong
        BANK_WEIGHT_0     = 5'd4,    // Weight storage start
        BANK_WEIGHT_1     = 5'd5,
        BANK_WEIGHT_2     = 5'd6,
        BANK_WEIGHT_3     = 5'd7,
        BANK_WEIGHT_4     = 5'd8,
        BANK_WEIGHT_5     = 5'd9,
        BANK_WEIGHT_6     = 5'd10,
        BANK_WEIGHT_7     = 5'd11,
        BANK_WEIGHT_8     = 5'd12,
        BANK_WEIGHT_9     = 5'd13,
        BANK_WEIGHT_10    = 5'd14,
        BANK_WEIGHT_11    = 5'd15,   // Weight storage end
        BANK_ACTIVATION_0 = 5'd16,   // Intermediate activations
        BANK_ACTIVATION_1 = 5'd17,
        BANK_BIAS         = 5'd18    // Bias values
    } bram_bank_e;

    parameter int BRAM_DEPTH = 2048;      // 18Kb / 8-bit = 2048 words
    parameter int BRAM_ADDR_WIDTH = 11;   // log2(2048)

    //--------------------------------------------------------------------------
    // Accelerator Types
    //--------------------------------------------------------------------------
    typedef enum logic [1:0] {
        ACCEL_MLP = 2'b00,
        ACCEL_CNN = 2'b01,
        ACCEL_RNN = 2'b10
    } accel_type_e;

    //--------------------------------------------------------------------------
    // FSM States (unified for all accelerators)
    //--------------------------------------------------------------------------
    typedef enum logic [2:0] {
        STATE_IDLE         = 3'b000,
        STATE_LOAD_WEIGHTS = 3'b001,
        STATE_LOAD_INPUT   = 3'b010,
        STATE_COMPUTE      = 3'b011,
        STATE_STORE_OUTPUT = 3'b100,
        STATE_DONE         = 3'b101
    } state_e;

    //--------------------------------------------------------------------------
    // Memory Access Patterns
    //--------------------------------------------------------------------------
    typedef enum logic [1:0] {
        ACCESS_SEQUENTIAL  = 2'b00,  // Linear addressing (MLP)
        ACCESS_SLIDING_2D  = 2'b01,  // 2D sliding window (CNN)
        ACCESS_CIRCULAR    = 2'b10   // Circular buffer (RNN)
    } access_pattern_e;

    //--------------------------------------------------------------------------
    // Fixed-Point Format (Q4.4 - 4 integer bits, 4 fractional bits)
    //--------------------------------------------------------------------------
    parameter int INT_BITS  = 4;
    parameter int FRAC_BITS = 4;

    // Saturation bounds for Q4.4
    parameter logic signed [DATA_WIDTH-1:0] SAT_MAX = 8'sh7F;  // +7.9375
    parameter logic signed [DATA_WIDTH-1:0] SAT_MIN = 8'sh80;  // -8.0

    //--------------------------------------------------------------------------
    // DSP Allocation
    //--------------------------------------------------------------------------
    parameter int MLP_MACS = 8;
    parameter int CNN_MACS = 9;   // 3x3 kernel
    parameter int RNN_MACS = 4;

    //--------------------------------------------------------------------------
    // Common Structures
    //--------------------------------------------------------------------------
    typedef struct packed {
        logic [ADDR_WIDTH-1:0]      addr;
        logic [DATA_WIDTH-1:0]      data;
        logic                       we;
        logic                       re;
        logic [4:0]                 bank_sel;
    } mem_req_t;

    typedef struct packed {
        logic [DATA_WIDTH-1:0]      data;
        logic                       valid;
        logic                       ready;
    } mem_resp_t;

    typedef struct packed {
        logic                       start;
        logic [1:0]                 accel_type;
        logic [15:0]                config_data;  // Accelerator-specific config
    } ctrl_req_t;

    typedef struct packed {
        logic                       done;
        logic                       busy;
        logic [2:0]                 state;
        logic [7:0]                 error_flags;
    } ctrl_resp_t;

    //--------------------------------------------------------------------------
    // Utility Functions
    //--------------------------------------------------------------------------

    // Saturate accumulator to 8-bit output
    function automatic logic [DATA_WIDTH-1:0] saturate(
        input logic signed [ACCUM_WIDTH-1:0] acc
    );
        if (acc > $signed(SAT_MAX))
            return SAT_MAX;
        else if (acc < $signed(SAT_MIN))
            return SAT_MIN;
        else
            return acc[DATA_WIDTH-1:0];
    endfunction

    // ReLU activation
    function automatic logic [DATA_WIDTH-1:0] relu(
        input logic signed [DATA_WIDTH-1:0] x
    );
        return (x[DATA_WIDTH-1]) ? 8'h00 : x;
    endfunction

    // 3-segment piecewise linear tanh approximation
    // tanh(x) ≈ x for |x| < 1, sign(x) for |x| > 2, linear interpolation between
    function automatic logic signed [DATA_WIDTH-1:0] tanh_approx(
        input logic signed [DATA_WIDTH-1:0] x
    );
        logic signed [DATA_WIDTH-1:0] result;
        logic signed [DATA_WIDTH-1:0] abs_x;

        abs_x = (x[DATA_WIDTH-1]) ? -x : x;

        if (abs_x < 8'sh10) begin  // |x| < 1.0 in Q4.4
            result = x;
        end else if (abs_x > 8'sh20) begin  // |x| > 2.0 in Q4.4
            result = (x[DATA_WIDTH-1]) ? 8'sh F0 : 8'sh0F;  // ±1.0 in Q4.4
        end else begin  // Linear interpolation
            result = (x[DATA_WIDTH-1]) ? 8'shF0 : 8'sh0F;
            result = result - ((abs_x - 8'sh10) >> 1);
            if (x[DATA_WIDTH-1]) result = -result;
        end

        return result;
    endfunction

endpackage

`endif // ACCEL_PKG_SV
