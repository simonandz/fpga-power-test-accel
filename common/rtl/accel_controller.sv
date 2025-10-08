`timescale 1ns / 1ps

//==============================================================================
// Module: accel_controller
// Description: Unified FSM controller for all accelerator types
//              Manages state transitions: IDLE -> LOAD_WEIGHTS -> LOAD_INPUT ->
//                                        COMPUTE -> STORE_OUTPUT -> DONE
//==============================================================================

import accel_pkg::*;

module accel_controller (
    input  logic                    clk,
    input  logic                    rst_n,

    // Control interface
    input  ctrl_req_t               ctrl_req,
    output ctrl_resp_t              ctrl_resp,

    // Memory controller interface
    output mem_req_t                mem_req,
    input  mem_resp_t               mem_resp,

    // Address generator interface
    output logic                    agu_start,
    output access_pattern_e         agu_pattern,
    output logic [ADDR_WIDTH-1:0]   agu_base_addr,
    output logic [15:0]             agu_length,
    input  logic                    agu_done,
    input  logic [ADDR_WIDTH-1:0]   agu_addr,
    input  logic                    agu_addr_valid,
    output logic                    agu_addr_ready,

    // Accelerator-specific compute interface
    output logic                    compute_start,
    output logic [15:0]             compute_config,
    input  logic                    compute_done,
    input  logic [7:0]              compute_error,

    // Configuration registers (from top-level)
    input  logic [ADDR_WIDTH-1:0]   weight_base_addr,
    input  logic [15:0]             weight_size,
    input  logic [ADDR_WIDTH-1:0]   input_base_addr,
    input  logic [15:0]             input_size,
    input  logic [ADDR_WIDTH-1:0]   output_base_addr,
    input  logic [15:0]             output_size,
    input  logic [4:0]              weight_bank,
    input  logic [4:0]              input_bank,
    input  logic [4:0]              output_bank
);

    //--------------------------------------------------------------------------
    // State Machine
    //--------------------------------------------------------------------------
    state_e state_q, state_d;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            state_q <= STATE_IDLE;
        else
            state_q <= state_d;
    end

    //--------------------------------------------------------------------------
    // State Transition Logic
    //--------------------------------------------------------------------------
    always_comb begin
        state_d = state_q;

        case (state_q)
            STATE_IDLE: begin
                if (ctrl_req.start)
                    state_d = STATE_LOAD_WEIGHTS;
            end

            STATE_LOAD_WEIGHTS: begin
                if (agu_done)
                    state_d = STATE_LOAD_INPUT;
            end

            STATE_LOAD_INPUT: begin
                if (agu_done)
                    state_d = STATE_COMPUTE;
            end

            STATE_COMPUTE: begin
                if (compute_done)
                    state_d = STATE_STORE_OUTPUT;
            end

            STATE_STORE_OUTPUT: begin
                if (agu_done)
                    state_d = STATE_DONE;
            end

            STATE_DONE: begin
                if (!ctrl_req.start)
                    state_d = STATE_IDLE;
            end

            default: state_d = STATE_IDLE;
        endcase
    end

    //--------------------------------------------------------------------------
    // AGU Control
    //--------------------------------------------------------------------------
    always_comb begin
        agu_start      = 1'b0;
        agu_pattern    = ACCESS_SEQUENTIAL;
        agu_base_addr  = '0;
        agu_length     = '0;
        agu_addr_ready = 1'b0;

        case (state_q)
            STATE_LOAD_WEIGHTS: begin
                agu_start      = (state_d == STATE_LOAD_WEIGHTS && state_q == STATE_IDLE);
                agu_pattern    = ACCESS_SEQUENTIAL;
                agu_base_addr  = weight_base_addr;
                agu_length     = weight_size;
                agu_addr_ready = 1'b1;
            end

            STATE_LOAD_INPUT: begin
                agu_start      = (state_d == STATE_LOAD_INPUT && state_q == STATE_LOAD_WEIGHTS);
                // Pattern depends on accelerator type
                case (ctrl_req.accel_type)
                    ACCEL_CNN: agu_pattern = ACCESS_SLIDING_2D;
                    ACCEL_RNN: agu_pattern = ACCESS_CIRCULAR;
                    default:   agu_pattern = ACCESS_SEQUENTIAL;
                endcase
                agu_base_addr  = input_base_addr;
                agu_length     = input_size;
                agu_addr_ready = 1'b1;
            end

            STATE_STORE_OUTPUT: begin
                agu_start      = (state_d == STATE_STORE_OUTPUT && state_q == STATE_COMPUTE);
                agu_pattern    = ACCESS_SEQUENTIAL;
                agu_base_addr  = output_base_addr;
                agu_length     = output_size;
                agu_addr_ready = 1'b1;
            end
        endcase
    end

    //--------------------------------------------------------------------------
    // Memory Request Generation
    //--------------------------------------------------------------------------
    always_comb begin
        mem_req.addr     = agu_addr;
        mem_req.data     = '0;
        mem_req.we       = 1'b0;
        mem_req.re       = 1'b0;
        mem_req.bank_sel = '0;

        case (state_q)
            STATE_LOAD_WEIGHTS: begin
                mem_req.bank_sel = weight_bank;
                mem_req.re       = agu_addr_valid;
            end

            STATE_LOAD_INPUT: begin
                mem_req.bank_sel = input_bank;
                mem_req.re       = agu_addr_valid;
            end

            STATE_STORE_OUTPUT: begin
                mem_req.bank_sel = output_bank;
                mem_req.we       = agu_addr_valid;
                // Data would come from compute unit (not shown in this interface)
            end
        endcase
    end

    //--------------------------------------------------------------------------
    // Compute Control
    //--------------------------------------------------------------------------
    assign compute_start  = (state_q == STATE_COMPUTE && state_d == STATE_COMPUTE &&
                            state_q != state_d);  // Pulse on entry
    assign compute_config = ctrl_req.config_data;

    //--------------------------------------------------------------------------
    // Control Response
    //--------------------------------------------------------------------------
    assign ctrl_resp.done        = (state_q == STATE_DONE);
    assign ctrl_resp.busy        = (state_q != STATE_IDLE) && (state_q != STATE_DONE);
    assign ctrl_resp.state       = state_q;
    assign ctrl_resp.error_flags = compute_error;

    //--------------------------------------------------------------------------
    // Assertions
    //--------------------------------------------------------------------------
    `ifdef SIMULATION
    // Check for valid state transitions
    always_ff @(posedge clk) begin
        if (rst_n) begin
            case (state_q)
                STATE_IDLE: begin
                    assert (state_d == STATE_IDLE || state_d == STATE_LOAD_WEIGHTS)
                        else $error("Invalid transition from IDLE");
                end
                STATE_LOAD_WEIGHTS: begin
                    assert (state_d == STATE_LOAD_WEIGHTS || state_d == STATE_LOAD_INPUT)
                        else $error("Invalid transition from LOAD_WEIGHTS");
                end
                STATE_LOAD_INPUT: begin
                    assert (state_d == STATE_LOAD_INPUT || state_d == STATE_COMPUTE)
                        else $error("Invalid transition from LOAD_INPUT");
                end
                STATE_COMPUTE: begin
                    assert (state_d == STATE_COMPUTE || state_d == STATE_STORE_OUTPUT)
                        else $error("Invalid transition from COMPUTE");
                end
                STATE_STORE_OUTPUT: begin
                    assert (state_d == STATE_STORE_OUTPUT || state_d == STATE_DONE)
                        else $error("Invalid transition from STORE_OUTPUT");
                end
                STATE_DONE: begin
                    assert (state_d == STATE_DONE || state_d == STATE_IDLE)
                        else $error("Invalid transition from DONE");
                end
            endcase
        end
    end
    `endif

endmodule
