// MLP Power Measurement Test Wrapper - MINIMAL VERSION
// Target: Basys 3 (Artix-7 xc7a35tcpg236-1)
//
// Purpose: Measure idle vs. active power consumption of MLP accelerator
// with minimal I/O overhead (only 1 LED for heartbeat confirmation)
//
// Controls:
//   SW0  = rst_n (active low reset)
//   SW1  = run_enable (1 = continuous inference, 0 = idle)
//
// LED Indicators:
//   LD0  = heartbeat (slow blink when idle, fast when running)

`timescale 1ns / 1ps

module mlp_power_test_wrapper_minimal (
    input  logic        clk,           // 100 MHz
    input  logic        rst_n,         // SW0 - active low reset
    input  logic        run_enable,    // SW1 - enable continuous inference

    // Single LED output - minimal I/O
    output logic        led_heartbeat  // LD0 - heartbeat indicator
);

    //==========================================================================
    // Parameters - Network Configuration
    //==========================================================================
    localparam NUM_INPUTS  = 16'd8;    // 8 input features
    localparam NUM_OUTPUTS = 16'd4;    // 4 output neurons

    //==========================================================================
    // Internal Signals
    //==========================================================================

    // MLP control signals
    logic        mlp_start;
    logic        mlp_done;
    logic        mlp_busy;
    logic [7:0]  mlp_output_data;
    logic        mlp_output_valid;

    // BRAM loading signals
    logic [15:0] input_addr;
    logic [7:0]  input_data;
    logic        input_we;
    logic [15:0] weight_addr;
    logic [7:0]  weight_data;
    logic        weight_we;
    logic [15:0] bias_addr;
    logic [7:0]  bias_data;
    logic        bias_we;

    // State machine for initialization and continuous run
    typedef enum logic [2:0] {
        S_RESET,
        S_LOAD_WEIGHTS,
        S_LOAD_BIAS,
        S_LOAD_INPUTS,
        S_IDLE,
        S_RUNNING,
        S_WAIT_DONE
    } state_t;

    state_t state, next_state;

    // Counters
    logic [15:0] load_addr;
    logic [25:0] heartbeat_counter;

    // Synchronizer for switch input
    logic [2:0] run_enable_sync;
    logic       run_enable_clean;

    //==========================================================================
    // Input Synchronization
    //==========================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            run_enable_sync <= 3'b0;
        end else begin
            run_enable_sync <= {run_enable_sync[1:0], run_enable};
        end
    end

    assign run_enable_clean = run_enable_sync[2];

    //==========================================================================
    // State Machine
    //==========================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_RESET;
        end else begin
            state <= next_state;
        end
    end

    always_comb begin
        next_state = state;

        case (state)
            S_RESET: begin
                next_state = S_LOAD_WEIGHTS;
            end

            S_LOAD_WEIGHTS: begin
                if (load_addr >= (NUM_INPUTS * NUM_OUTPUTS)) begin
                    next_state = S_LOAD_BIAS;
                end
            end

            S_LOAD_BIAS: begin
                if (load_addr >= NUM_OUTPUTS) begin
                    next_state = S_LOAD_INPUTS;
                end
            end

            S_LOAD_INPUTS: begin
                if (load_addr >= NUM_INPUTS) begin
                    next_state = S_IDLE;
                end
            end

            S_IDLE: begin
                if (run_enable_clean) begin
                    next_state = S_RUNNING;
                end
            end

            S_RUNNING: begin
                next_state = S_WAIT_DONE;
            end

            S_WAIT_DONE: begin
                if (mlp_done) begin
                    if (run_enable_clean) begin
                        next_state = S_RUNNING;  // Continue inference
                    end else begin
                        next_state = S_IDLE;
                    end
                end
            end

            default: next_state = S_RESET;
        endcase
    end

    //==========================================================================
    // Load Address Counter
    //==========================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            load_addr <= 16'd0;
        end else begin
            case (state)
                S_RESET: load_addr <= 16'd0;

                S_LOAD_WEIGHTS: begin
                    if (load_addr < (NUM_INPUTS * NUM_OUTPUTS)) begin
                        load_addr <= load_addr + 1;
                    end else begin
                        load_addr <= 16'd0;
                    end
                end

                S_LOAD_BIAS: begin
                    if (load_addr < NUM_OUTPUTS) begin
                        load_addr <= load_addr + 1;
                    end else begin
                        load_addr <= 16'd0;
                    end
                end

                S_LOAD_INPUTS: begin
                    if (load_addr < NUM_INPUTS) begin
                        load_addr <= load_addr + 1;
                    end else begin
                        load_addr <= 16'd0;
                    end
                end

                default: load_addr <= 16'd0;
            endcase
        end
    end

    //==========================================================================
    // BRAM Write Signals
    //==========================================================================
    logic [7:0] weight_pattern;
    assign weight_pattern = 8'd1 + load_addr[7:0];

    logic [7:0] bias_pattern;
    assign bias_pattern = 8'd10 + load_addr[3:0];

    logic [7:0] input_pattern;
    assign input_pattern = 8'd1 + load_addr[7:0];

    always_comb begin
        input_addr  = 16'd0;
        input_data  = 8'd0;
        input_we    = 1'b0;
        weight_addr = 16'd0;
        weight_data = 8'd0;
        weight_we   = 1'b0;
        bias_addr   = 16'd0;
        bias_data   = 8'd0;
        bias_we     = 1'b0;

        case (state)
            S_LOAD_WEIGHTS: begin
                weight_addr = load_addr;
                weight_data = weight_pattern;
                weight_we   = (load_addr < (NUM_INPUTS * NUM_OUTPUTS));
            end

            S_LOAD_BIAS: begin
                bias_addr = load_addr;
                bias_data = bias_pattern;
                bias_we   = (load_addr < NUM_OUTPUTS);
            end

            S_LOAD_INPUTS: begin
                input_addr = load_addr;
                input_data = input_pattern;
                input_we   = (load_addr < NUM_INPUTS);
            end

            default: ;
        endcase
    end

    //==========================================================================
    // MLP Start Signal
    //==========================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mlp_start <= 1'b0;
        end else begin
            mlp_start <= (state == S_RUNNING);
        end
    end

    //==========================================================================
    // Heartbeat LED (slow when idle, fast when running)
    //==========================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            heartbeat_counter <= 26'd0;
        end else begin
            heartbeat_counter <= heartbeat_counter + 1;
        end
    end

    // Slow blink (bit 25 = ~0.67s) when idle, fast blink (bit 22 = ~84ms) when running
    assign led_heartbeat = run_enable_clean ? heartbeat_counter[22] : heartbeat_counter[25];

    //==========================================================================
    // MLP Accelerator Instance
    //==========================================================================
    (* DONT_TOUCH = "TRUE" *)
    mlp_top mlp_inst (
        .clk(clk),
        .rst_n(rst_n),

        // Control
        .start(mlp_start),
        .done(mlp_done),
        .busy(mlp_busy),

        // Configuration
        .num_inputs(NUM_INPUTS),
        .num_outputs(NUM_OUTPUTS),

        // Host input load interface
        .input_addr(input_addr),
        .input_data(input_data),
        .input_we(input_we),

        // Host weight load interface
        .weight_addr(weight_addr),
        .weight_data(weight_data),
        .weight_we(weight_we),

        // Host bias load interface
        .bias_addr(bias_addr),
        .bias_data(bias_data),
        .bias_we(bias_we),

        // Output interface
        .output_data(mlp_output_data),
        .output_valid(mlp_output_valid),

        // Debug outputs (unused)
        .output_wr_addr(),
        .output_wr_data(),
        .output_wr_en()
    );

endmodule
