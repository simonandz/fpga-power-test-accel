// CNN Power Measurement Test Wrapper - MINIMAL VERSION
// Target: Basys 3 (Artix-7 xc7a35tcpg236-1)
//
// Purpose: Measure idle vs. active power consumption of CNN accelerator
// with minimal I/O overhead (only 1 LED for heartbeat confirmation)
//
// Controls:
//   SW0  = rst_n (active low reset)
//   SW1  = run_enable (1 = continuous inference, 0 = idle)
//
// LED Indicators:
//   LD0  = heartbeat (slow blink when idle, fast when running)

`timescale 1ns / 1ps

module cnn_power_test_wrapper_minimal (
    input  logic        clk,           // 100 MHz
    input  logic        rst_n,         // SW0 - active low reset
    input  logic        run_enable,    // SW1 - enable continuous inference

    // Single LED output - minimal I/O
    output logic        led_heartbeat  // LD0 - heartbeat indicator
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

    // State machine
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
                next_state = S_LOAD_KERNEL;
            end

            S_LOAD_KERNEL: begin
                if (load_addr >= KER_DEPTH)
                    next_state = S_LOAD_BIAS;
            end

            S_LOAD_BIAS: begin
                if (load_addr >= 16'd1)
                    next_state = S_LOAD_IFMAP;
            end

            S_LOAD_IFMAP: begin
                if (load_addr >= IMG_SIZE)
                    next_state = S_IDLE;
            end

            S_IDLE: begin
                if (run_enable_clean)
                    next_state = S_RUNNING;
            end

            S_RUNNING: begin
                next_state = S_WAIT_DONE;
            end

            S_WAIT_DONE: begin
                if (cnn_done) begin
                    if (run_enable_clean)
                        next_state = S_RUNNING;
                    else
                        next_state = S_IDLE;
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
    // Fixed kernel: edge detection [0,-1,0; -1,4,-1; 0,-1,0]
    logic [7:0] kernel_pattern;
    always_comb begin
        case (load_addr[3:0])
            4'd0: kernel_pattern = 8'd0;
            4'd1: kernel_pattern = -8'd1;
            4'd2: kernel_pattern = 8'd0;
            4'd3: kernel_pattern = -8'd1;
            4'd4: kernel_pattern = 8'd4;
            4'd5: kernel_pattern = -8'd1;
            4'd6: kernel_pattern = 8'd0;
            4'd7: kernel_pattern = -8'd1;
            4'd8: kernel_pattern = 8'd0;
            default: kernel_pattern = 8'd0;
        endcase
    end

    logic [7:0] bias_pattern;
    assign bias_pattern = 8'd5;

    logic [7:0] ifmap_pattern;
    assign ifmap_pattern = load_addr[7:0];  // Gradient pattern

    always_comb begin
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
    // Heartbeat LED
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

        // Debug outputs (unused)
        .output_wr_addr(),
        .output_wr_data(),
        .output_wr_en()
    );

endmodule
