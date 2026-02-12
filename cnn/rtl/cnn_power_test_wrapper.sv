// CNN Power Measurement Test Wrapper
// Target: Basys 3 (Artix-7 xc7a35tcpg236-1)
//
// Purpose: Measure idle vs. active power consumption of CNN accelerator
// using a USB power meter. Fair comparison with MLP power test wrapper.
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

module cnn_power_test_wrapper (
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
    // Parameters - CNN Configuration
    //==========================================================================
    localparam IMG_W    = 16;
    localparam IMG_H    = 16;
    localparam IMG_SIZE = IMG_W * IMG_H;   // 256 pixels
    localparam KER_SIZE = 3;
    localparam KER_DEPTH = KER_SIZE * KER_SIZE;  // 9 weights
    localparam STRIDE   = 1;
    localparam PAD      = 1;
    localparam POOL_EN  = 1;

    //==========================================================================
    // Internal Signals
    //==========================================================================

    // CNN control signals
    logic        cnn_start;
    logic        cnn_done;
    logic        cnn_busy;
    logic [7:0]  cnn_output_data;
    logic        cnn_output_valid;

    // BRAM loading signals
    logic [15:0] ifmap_addr;
    logic [7:0]  ifmap_data;
    logic        ifmap_we;
    logic [3:0]  kernel_addr;
    logic [7:0]  kernel_data;
    logic        kernel_we;
    logic [7:0]  bias_data;
    logic        bias_we;

    // State machine for initialization and continuous run
    typedef enum logic [2:0] {
        S_RESET,
        S_LOAD_KERNEL,
        S_LOAD_BIAS,
        S_LOAD_IFMAP,
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
        end else if (state == S_LOAD_IFMAP && ifmap_we) begin
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
                next_state = S_LOAD_KERNEL;
            end

            S_LOAD_KERNEL: begin
                // Load 9 kernel weights
                if (load_addr >= KER_DEPTH) begin
                    next_state = S_LOAD_BIAS;
                end
            end

            S_LOAD_BIAS: begin
                // Load 1 bias value
                if (load_addr >= 16'd1) begin
                    next_state = S_LOAD_IFMAP;
                end
            end

            S_LOAD_IFMAP: begin
                // Load 256 input pixels (16x16)
                if (load_addr >= IMG_SIZE) begin
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
                if (cnn_done) begin
                    if (run_enable_clean) begin
                        if (randomize_clean) begin
                            next_state = S_LOAD_IFMAP;  // Load new random inputs
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

                S_LOAD_KERNEL: begin
                    if (load_addr < KER_DEPTH)
                        load_addr <= load_addr + 1;
                    else
                        load_addr <= 16'd0;
                end

                S_LOAD_BIAS: begin
                    if (load_addr < 16'd1)
                        load_addr <= load_addr + 1;
                    else
                        load_addr <= 16'd0;
                end

                S_LOAD_IFMAP: begin
                    if (load_addr < IMG_SIZE)
                        load_addr <= load_addr + 1;
                    else
                        load_addr <= 16'd0;
                end

                default: load_addr <= 16'd0;
            endcase
        end
    end

    //==========================================================================
    // BRAM Write Signals
    //==========================================================================

    // Kernel data: edge-detection-like pattern for realistic switching
    logic [7:0] kernel_pattern;
    always_comb begin
        case (load_addr[3:0])
            4'd0: kernel_pattern = 8'd0;    // Top-left
            4'd1: kernel_pattern = -8'd1;   // Top-center
            4'd2: kernel_pattern = 8'd0;    // Top-right
            4'd3: kernel_pattern = -8'd1;   // Mid-left
            4'd4: kernel_pattern = 8'd4;    // Center
            4'd5: kernel_pattern = -8'd1;   // Mid-right
            4'd6: kernel_pattern = 8'd0;    // Bot-left
            4'd7: kernel_pattern = -8'd1;   // Bot-center
            4'd8: kernel_pattern = 8'd0;    // Bot-right
            default: kernel_pattern = 8'd0;
        endcase
    end

    // Bias data: small offset
    logic [7:0] bias_pattern;
    assign bias_pattern = 8'd5;

    // Input data: either gradient or random
    logic [7:0] ifmap_pattern;
    assign ifmap_pattern = randomize_clean ? lfsr[7:0] : load_addr[7:0];

    always_comb begin
        // Defaults
        ifmap_addr  = 16'd0;
        ifmap_data  = 8'd0;
        ifmap_we    = 1'b0;
        kernel_addr = 4'd0;
        kernel_data = 8'd0;
        kernel_we   = 1'b0;
        bias_data   = 8'd0;
        bias_we     = 1'b0;

        case (state)
            S_LOAD_KERNEL: begin
                kernel_addr = load_addr[3:0];
                kernel_data = kernel_pattern;
                kernel_we   = (load_addr < KER_DEPTH);
            end

            S_LOAD_BIAS: begin
                bias_data = bias_pattern;
                bias_we   = (load_addr < 16'd1);
            end

            S_LOAD_IFMAP: begin
                ifmap_addr = load_addr;
                ifmap_data = ifmap_pattern;
                ifmap_we   = (load_addr < IMG_SIZE);
            end

            default: ;
        endcase
    end

    //==========================================================================
    // CNN Start Signal
    //==========================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cnn_start <= 1'b0;
        end else begin
            cnn_start <= (state == S_RUNNING);
        end
    end

    //==========================================================================
    // Inference Counter
    //==========================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            inference_count <= 32'd0;
        end else if (cnn_done && (state == S_WAIT_DONE)) begin
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

    assign led_heartbeat = run_enable_clean ? heartbeat_counter[22] : heartbeat_counter[25];

    //==========================================================================
    // Done Pulse Stretcher
    //==========================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done_pulse_counter <= 20'd0;
        end else if (cnn_done) begin
            done_pulse_counter <= 20'hFFFFF;
        end else if (done_pulse_counter > 0) begin
            done_pulse_counter <= done_pulse_counter - 1;
        end
    end

    assign led_done = (done_pulse_counter > 0);

    //==========================================================================
    // LED Outputs
    //==========================================================================
    assign led_running = run_enable_clean;
    assign led_busy    = cnn_busy;
    assign led_count   = inference_count[7:0];

    //==========================================================================
    // 7-Segment Display - Shows inference count
    //==========================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            refresh_counter <= 20'd0;
        end else begin
            refresh_counter <= refresh_counter + 1;
        end
    end

    assign digit_select = refresh_counter[19:18];

    always_comb begin
        case (digit_select)
            2'b00: current_digit = inference_count[3:0];
            2'b01: current_digit = inference_count[7:4];
            2'b10: current_digit = inference_count[11:8];
            2'b11: current_digit = inference_count[15:12];
        endcase
    end

    always_comb begin
        an = 4'b1111;
        an[digit_select] = 1'b0;
    end

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
    // CNN Accelerator Instance
    //==========================================================================
    (* DONT_TOUCH = "TRUE" *)
    cnn_top #(
        .IMG_W(IMG_W),
        .IMG_H(IMG_H),
        .KER_SIZE(KER_SIZE),
        .STRIDE(STRIDE),
        .PAD(PAD),
        .POOL_EN(POOL_EN)
    ) cnn_inst (
        .clk(clk),
        .rst_n(rst_n),

        // Control
        .start(cnn_start),
        .done(cnn_done),
        .busy(cnn_busy),

        // Configuration
        .pool_enable(1'b1),

        // Host input load
        .ifmap_addr(ifmap_addr),
        .ifmap_data(ifmap_data),
        .ifmap_we(ifmap_we),

        // Host kernel load
        .kernel_addr(kernel_addr),
        .kernel_data(kernel_data),
        .kernel_we(kernel_we),

        // Host bias load
        .bias_data(bias_data),
        .bias_we(bias_we),

        // Output interface
        .output_data(cnn_output_data),
        .output_valid(cnn_output_valid),

        // Debug outputs (unused here)
        .output_wr_addr(),
        .output_wr_data(),
        .output_wr_en()
    );

endmodule
