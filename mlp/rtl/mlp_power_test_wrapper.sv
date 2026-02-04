// MLP Power Measurement Test Wrapper
// Target: Basys 3 (Artix-7 xc7a35tcpg236-1)
//
// Purpose: Measure idle vs. active power consumption of MLP accelerator
// using a USB power meter.
//
// Controls:
//   SW0  = rst_n (active low reset)
//   SW1  = run_enable (1 = continuous inference, 0 = idle)
//   SW15 = randomize_inputs (1 = new random inputs each inference)
//
// LED Indicators:
//   LD0  = heartbeat (slow blink when idle, fast when running)
//   LD1  = run_enable status
//   LD2  = busy
//   LD3  = done pulse
//   LD15:LD8 = inference_count[7:0] (lower 8 bits)
//
// 7-Segment Display: Shows inference count (4 hex digits)

`timescale 1ns / 1ps

module mlp_power_test_wrapper (
    input  logic        clk,           // 100 MHz
    input  logic        rst_n,         // SW0 - active low reset
    input  logic        run_enable,    // SW1 - enable continuous inference
    input  logic        randomize_en,  // SW15 - randomize inputs each inference

    // LED outputs
    output logic        led_heartbeat, // LD0 - heartbeat indicator
    output logic        led_running,   // LD1 - run_enable status
    output logic        led_busy,      // LD2 - accelerator busy
    output logic        led_done,      // LD3 - done pulse (active for ~10ms)
    output logic [7:0]  led_count,     // LD15:LD8 - inference count [7:0]

    // 7-segment display (active low)
    output logic [6:0]  seg,           // segment outputs (active low)
    output logic [3:0]  an             // anode enables (active low)
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
    logic [31:0] inference_count;
    logic [15:0] load_addr;
    logic [25:0] heartbeat_counter;
    logic [19:0] done_pulse_counter;

    // LFSR for pseudo-random input generation
    logic [15:0] lfsr;

    // 7-segment display refresh
    logic [19:0] refresh_counter;
    logic [1:0]  digit_select;
    logic [3:0]  current_digit;

    // Synchronizers for switch inputs
    logic [2:0] run_enable_sync;
    logic [2:0] randomize_sync;
    logic       run_enable_clean;
    logic       randomize_clean;

    //==========================================================================
    // Input Synchronization
    //==========================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            run_enable_sync <= 3'b0;
            randomize_sync  <= 3'b0;
        end else begin
            run_enable_sync <= {run_enable_sync[1:0], run_enable};
            randomize_sync  <= {randomize_sync[1:0], randomize_en};
        end
    end

    assign run_enable_clean = run_enable_sync[2];
    assign randomize_clean  = randomize_sync[2];

    //==========================================================================
    // LFSR for Pseudo-Random Input Generation
    //==========================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            lfsr <= 16'hACE1;  // Non-zero seed
        end else if (state == S_LOAD_INPUTS && input_we) begin
            // Galois LFSR with taps at 16, 14, 13, 11
            lfsr <= {lfsr[0] ^ lfsr[2] ^ lfsr[3] ^ lfsr[5], lfsr[15:1]};
        end
    end

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
                // Load all weights (NUM_INPUTS * NUM_OUTPUTS = 8 * 4 = 32)
                if (load_addr >= (NUM_INPUTS * NUM_OUTPUTS)) begin
                    next_state = S_LOAD_BIAS;
                end
            end

            S_LOAD_BIAS: begin
                // Load all biases (NUM_OUTPUTS = 4)
                if (load_addr >= NUM_OUTPUTS) begin
                    next_state = S_LOAD_INPUTS;
                end
            end

            S_LOAD_INPUTS: begin
                // Load initial inputs (NUM_INPUTS = 8)
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
                // Start inference
                next_state = S_WAIT_DONE;
            end

            S_WAIT_DONE: begin
                if (mlp_done) begin
                    if (run_enable_clean) begin
                        // Continue with next inference
                        if (randomize_clean) begin
                            next_state = S_LOAD_INPUTS;  // Load new random inputs
                        end else begin
                            next_state = S_RUNNING;      // Reuse same inputs
                        end
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

    // Weight data: simple pattern (all 1s for easy verification, or varying)
    // Using weights that create measurable switching activity
    logic [7:0] weight_pattern;
    assign weight_pattern = 8'd1 + load_addr[7:0];  // 1, 2, 3, ... pattern

    // Bias data: small values
    logic [7:0] bias_pattern;
    assign bias_pattern = 8'd10 + load_addr[3:0];   // 10, 11, 12, 13

    // Input data: either sequential or random
    logic [7:0] input_pattern;
    assign input_pattern = randomize_clean ? lfsr[7:0] : (8'd1 + load_addr[7:0]);

    always_comb begin
        // Defaults
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
    // Inference Counter
    //==========================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            inference_count <= 32'd0;
        end else if (mlp_done && (state == S_WAIT_DONE)) begin
            inference_count <= inference_count + 1;
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
    // Done Pulse Stretcher (make done visible on LED)
    //==========================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done_pulse_counter <= 20'd0;
        end else if (mlp_done) begin
            done_pulse_counter <= 20'hFFFFF;  // ~10ms at 100MHz
        end else if (done_pulse_counter > 0) begin
            done_pulse_counter <= done_pulse_counter - 1;
        end
    end

    assign led_done = (done_pulse_counter > 0);

    //==========================================================================
    // LED Outputs
    //==========================================================================
    assign led_running = run_enable_clean;
    assign led_busy    = mlp_busy;
    assign led_count   = inference_count[7:0];

    //==========================================================================
    // 7-Segment Display - Shows inference count
    //==========================================================================

    // Refresh counter for multiplexing (need ~1kHz refresh per digit)
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            refresh_counter <= 20'd0;
        end else begin
            refresh_counter <= refresh_counter + 1;
        end
    end

    assign digit_select = refresh_counter[19:18];  // ~380Hz per digit

    // Select which digit to display
    always_comb begin
        case (digit_select)
            2'b00: current_digit = inference_count[3:0];
            2'b01: current_digit = inference_count[7:4];
            2'b10: current_digit = inference_count[11:8];
            2'b11: current_digit = inference_count[15:12];
        endcase
    end

    // Anode enables (active low)
    always_comb begin
        an = 4'b1111;  // All off
        an[digit_select] = 1'b0;  // Enable current digit
    end

    // 7-segment decoder (active low: 0 = segment on)
    always_comb begin
        case (current_digit)
            4'h0: seg = 7'b1000000;
            4'h1: seg = 7'b1111001;
            4'h2: seg = 7'b0100100;
            4'h3: seg = 7'b0110000;
            4'h4: seg = 7'b0011001;
            4'h5: seg = 7'b0010010;
            4'h6: seg = 7'b0000010;
            4'h7: seg = 7'b1111000;
            4'h8: seg = 7'b0000000;
            4'h9: seg = 7'b0010000;
            4'hA: seg = 7'b0001000;
            4'hB: seg = 7'b0000011;
            4'hC: seg = 7'b1000110;
            4'hD: seg = 7'b0100001;
            4'hE: seg = 7'b0000110;
            4'hF: seg = 7'b0001110;
        endcase
    end

    //==========================================================================
    // MLP Accelerator Instance
    //==========================================================================
    // DONT_TOUCH prevents synthesis from optimizing away the MLP core
    // even though its outputs aren't fully used by the wrapper.
    // This is essential for accurate power measurement.
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

        // Debug outputs (unused here)
        .output_wr_addr(),
        .output_wr_data(),
        .output_wr_en()
    );

endmodule
