// CNN Controller
// FSM-based control logic for 3x3 CNN convolution accelerator
// Orchestrates memory access, 2D scanning, and compute operations
//
// Performs convolution over all output positions in raster order.
// For each output pixel: reads 9 window pixels from BRAM (with zero-padding),
// triggers MAC, bias addition, and activation.
// Supports configurable stride and zero-padding.

`timescale 1ns / 1ps

(* DONT_TOUCH = "TRUE" *)
module cnn_controller #(
    parameter IMG_W    = 16,
    parameter IMG_H    = 16,
    parameter KER_SIZE = 3,
    parameter STRIDE   = 1,
    parameter PAD      = 1,
    parameter DATA_W   = 8
)(
    input  logic         clk,
    input  logic         rst_n,

    // Control interface
    input  logic         start,
    output logic         done,
    output logic         busy,

    // Memory address outputs
    output logic [15:0]  ifmap_rd_addr,
    output logic [3:0]   kernel_rd_addr,
    output logic [15:0]  ofmap_wr_addr,
    output logic         ofmap_wr_en,

    // Datapath control
    output logic         mac_enable,
    output logic         mac_clear,
    output logic         activation_enable,
    output logic [1:0]   activation_type,

    // Datapath status
    input  logic         mac_valid,
    input  logic         conv_valid,

    // Data loading control (signals to cnn_top)
    output logic         load_kernel,           // Loading kernel weight from BRAM
    output logic [3:0]   load_kernel_idx,       // Which of 9 kernel regs to load
    output logic         load_window,           // Loading window pixel from BRAM
    output logic [3:0]   load_window_idx,       // Which of 9 window regs to load
    output logic         pad_zero,              // Current window pixel is zero (padding)

    // Current output position (for pooling logic in cnn_top)
    output logic [$clog2(IMG_H)-1:0]  out_row,
    output logic [$clog2(IMG_W)-1:0]  out_col,
    output logic         conv_result_ready,     // Pulses when conv_valid captured
    output logic [2:0]   stage                  // Current pipeline stage for perf_counters
);

    // =========================================================================
    // Computed parameters
    // =========================================================================
    // Output dimensions with stride and padding
    localparam OUT_H = (IMG_H + 2*PAD - KER_SIZE) / STRIDE + 1;
    localparam OUT_W = (IMG_W + 2*PAD - KER_SIZE) / STRIDE + 1;
    localparam TOTAL_OUT_PIXELS = OUT_H * OUT_W;
    localparam logic [$clog2(OUT_H)-1:0] OUT_H_LAST = OUT_H - 1;
    localparam logic [$clog2(OUT_W)-1:0] OUT_W_LAST = OUT_W - 1;

    // =========================================================================
    // FSM states
    // =========================================================================
    typedef enum logic [3:0] {
        S_IDLE        = 4'd0,
        S_LOAD_KERNEL = 4'd1,   // Load 9 kernel weights (10 cycles with BRAM latency)
        S_INIT_PIXEL  = 4'd2,   // Initialize for new output pixel
        S_READ_WINDOW = 4'd3,   // Read 9 input pixels for current position
        S_COMPUTE     = 4'd4,   // MAC enable, wait for mac_valid
        S_BIAS_ACT    = 4'd5,   // Bias add + activation, wait for conv_valid
        S_STORE       = 4'd6,   // Write result / signal to top-level
        S_NEXT_PIXEL  = 4'd7,   // Advance to next output position
        S_DONE        = 4'd8
    } state_t;

    state_t state, next_state;

    // =========================================================================
    // Internal registers
    // =========================================================================
    // Kernel loading
    logic [3:0] kernel_load_cnt;    // 0-9 for kernel loading

    // Window pixel reading
    logic [3:0] win_cnt;            // 0-9 for window pixel loading
    logic [1:0] kr_reg, kc_reg;     // Kernel row/col for current win_cnt

    // Output position counters
    logic [$clog2(OUT_H)-1:0] out_r;
    logic [$clog2(OUT_W)-1:0] out_c;
    logic [15:0] out_addr;          // Linear output address

    // Input coordinate calculation (signed to detect padding)
    logic signed [$clog2(IMG_H)+1:0] in_row;
    logic signed [$clog2(IMG_W)+1:0] in_col;
    logic                             pad_zero_comb;

    // Activation tracking
    logic activation_triggered;

    // MAC tracking
    logic mac_triggered;

    // =========================================================================
    // FSM state register
    // =========================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) state <= S_IDLE;
        else state <= next_state;
    end

    // =========================================================================
    // FSM next state logic
    // =========================================================================
    always_comb begin
        next_state = state;
        case (state)
            S_IDLE: begin
                if (start) next_state = S_LOAD_KERNEL;
            end

            S_LOAD_KERNEL: begin
                // 10 cycles: 0-8 issue addresses, 1-9 capture data
                if (kernel_load_cnt >= 4'd10) next_state = S_INIT_PIXEL;
            end

            S_INIT_PIXEL: begin
                next_state = S_READ_WINDOW;
            end

            S_READ_WINDOW: begin
                // 10 cycles: issue 9 addresses (0-8), capture 9 values (1-9)
                if (win_cnt >= 4'd10) next_state = S_COMPUTE;
            end

            S_COMPUTE: begin
                if (mac_valid) next_state = S_BIAS_ACT;
            end

            S_BIAS_ACT: begin
                if (conv_valid) next_state = S_STORE;
            end

            S_STORE: begin
                next_state = S_NEXT_PIXEL;
            end

            S_NEXT_PIXEL: begin
                // Check if all output pixels done
                if (out_r >= OUT_H_LAST &&
                    out_c >= OUT_W_LAST) begin
                    next_state = S_DONE;
                end else begin
                    next_state = S_INIT_PIXEL;
                end
            end

            S_DONE: begin
                if (!start) next_state = S_IDLE;
            end

            default: next_state = S_IDLE;
        endcase
    end

    // =========================================================================
    // Input coordinate calculation (combinational)
    // Maps (out_r, out_c, kr, kc) to input image coordinates
    // =========================================================================
    always_comb begin
        // With stride and padding:
        // in_row = out_r * STRIDE + kr - PAD
        // in_col = out_c * STRIDE + kc - PAD
        in_row = $signed({1'b0, out_r}) * STRIDE + $signed({2'b00, kr_reg}) - PAD;
        in_col = $signed({1'b0, out_c}) * STRIDE + $signed({2'b00, kc_reg}) - PAD;

        // Zero-padding detection
        pad_zero_comb = (in_row < 0) || (in_row >= IMG_H) ||
                        (in_col < 0) || (in_col >= IMG_W);

        // BRAM address (valid only when !pad_zero)
        if (!pad_zero_comb)
            ifmap_rd_addr = in_row[$clog2(IMG_H)-1:0] * IMG_W + in_col[$clog2(IMG_W)-1:0];
        else
            ifmap_rd_addr = 16'h0000;
    end

    // =========================================================================
    // Control and datapath logic
    // =========================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done <= 1'b0;
            busy <= 1'b0;
            kernel_load_cnt <= 4'd0;
            kernel_rd_addr <= 4'd0;
            win_cnt <= 4'd0;
            kr_reg <= 2'd0;
            kc_reg <= 2'd0;
            out_r <= '0;
            out_c <= '0;
            out_addr <= 16'h0000;
            mac_enable <= 1'b0;
            mac_clear <= 1'b0;
            activation_enable <= 1'b0;
            activation_type <= 2'b00;
            ofmap_wr_en <= 1'b0;
            ofmap_wr_addr <= 16'h0000;
            load_kernel <= 1'b0;
            load_kernel_idx <= 4'd0;
            load_window <= 1'b0;
            load_window_idx <= 4'd0;
            pad_zero <= 1'b0;
            activation_triggered <= 1'b0;
            mac_triggered <= 1'b0;
            conv_result_ready <= 1'b0;
        end else begin
            // Default values (pulse signals)
            mac_enable <= 1'b0;
            mac_clear <= 1'b0;
            activation_enable <= 1'b0;
            ofmap_wr_en <= 1'b0;
            load_kernel <= 1'b0;
            load_window <= 1'b0;
            conv_result_ready <= 1'b0;
            pad_zero <= pad_zero_comb;

            case (state)
                // =============================================================
                S_IDLE: begin
                    done <= 1'b0;
                    busy <= 1'b0;
                    out_r <= '0;
                    out_c <= '0;
                    out_addr <= 16'h0000;
                    kernel_load_cnt <= 4'd0;
                end

                // =============================================================
                S_LOAD_KERNEL: begin
                    busy <= 1'b1;
                    // Timeline (BRAM has 1-cycle read latency):
                    // Cnt 0: set kernel_rd_addr=0
                    // Cnt 1: BRAM outputs kernel[0], store to kernel_regs[0], set addr=1
                    // Cnt 2: BRAM outputs kernel[1], store to kernel_regs[1], set addr=2
                    // ...
                    // Cnt 9: BRAM outputs kernel[8], store to kernel_regs[8]

                    if (kernel_load_cnt == 4'd0) begin
                        // First cycle: set address, don't capture yet
                        kernel_rd_addr <= 4'd0;
                    end else if (kernel_load_cnt <= 4'd9) begin
                        // Capture data from previous address, set next address
                        load_kernel <= 1'b1;
                        load_kernel_idx <= kernel_load_cnt - 1;
                        if (kernel_load_cnt <= 4'd8)
                            kernel_rd_addr <= kernel_load_cnt[3:0];
                    end

                    kernel_load_cnt <= kernel_load_cnt + 1;
                end

                // =============================================================
                S_INIT_PIXEL: begin
                    // Prepare for new output pixel
                    mac_clear <= 1'b1;
                    win_cnt <= 4'd0;
                    kr_reg <= 2'd0;
                    kc_reg <= 2'd0;
                    activation_triggered <= 1'b0;
                    mac_triggered <= 1'b0;
                end

                // =============================================================
                S_READ_WINDOW: begin
                    // Timeline (BRAM has 1-cycle read latency):
                    // Cnt 0: set ifmap_rd_addr for pixel 0 (kr=0,kc=0), pad_zero computed
                    // Cnt 1: BRAM outputs pixel 0, store to window[0], set addr for pixel 1
                    // ...
                    // Cnt 9: BRAM outputs pixel 8, store to window[8]

                    if (win_cnt == 4'd0) begin
                        // First cycle: address already set via combinational logic
                        // Set kr/kc for pixel 0
                        kr_reg <= 2'd0;
                        kc_reg <= 2'd0;
                    end else if (win_cnt <= 4'd9) begin
                        // Capture data for previous pixel, advance kr/kc
                        load_window <= 1'b1;
                        load_window_idx <= win_cnt - 1;

                        // Advance kernel row/col counters for NEXT pixel
                        if (win_cnt <= 4'd8) begin
                            if (kc_reg == KER_SIZE - 1) begin
                                kc_reg <= 2'd0;
                                kr_reg <= kr_reg + 1;
                            end else begin
                                kc_reg <= kc_reg + 1;
                            end
                        end
                    end

                    win_cnt <= win_cnt + 1;
                end

                // =============================================================
                S_COMPUTE: begin
                    // Trigger MAC once on entry
                    if (!mac_triggered) begin
                        mac_enable <= 1'b1;
                        mac_triggered <= 1'b1;
                    end
                end

                // =============================================================
                S_BIAS_ACT: begin
                    // Trigger activation once
                    if (!activation_triggered) begin
                        activation_enable <= 1'b1;
                        activation_type <= 2'b00;  // ReLU
                        activation_triggered <= 1'b1;
                    end
                end

                // =============================================================
                S_STORE: begin
                    // Signal that conv result is ready
                    conv_result_ready <= 1'b1;
                    // Output write is handled by cnn_top (with pooling logic)
                    // For non-pooled mode, cnn_top directly writes to BRAM
                    ofmap_wr_addr <= out_addr;
                    ofmap_wr_en <= 1'b1;
                end

                // =============================================================
                S_NEXT_PIXEL: begin
                    // Advance output position (raster order)
                    if (out_c >= OUT_W_LAST) begin
                        out_c <= '0;
                        out_r <= out_r + 1;
                    end else begin
                        out_c <= out_c + 1;
                    end
                    out_addr <= out_addr + 1;

                    // Reset kr/kc for next pixel's window read
                    kr_reg <= 2'd0;
                    kc_reg <= 2'd0;
                end

                // =============================================================
                S_DONE: begin
                    done <= 1'b1;
                    busy <= 1'b0;
                end

                // =============================================================
                default: begin
                    done <= 1'b0;
                    busy <= 1'b0;
                end
            endcase
        end
    end

    // =========================================================================
    // Output position exposure (for pooling in cnn_top)
    // =========================================================================
    assign out_row = out_r;
    assign out_col = out_c;

    // =========================================================================
    // Stage encoding for performance counters
    // =========================================================================
    always_comb begin
        case (state)
            S_IDLE:        stage = 3'b000;  // STAGE_IDLE
            S_DONE:        stage = 3'b000;  // STAGE_IDLE
            S_LOAD_KERNEL: stage = 3'b001;  // STAGE_INIT
            S_INIT_PIXEL:  stage = 3'b001;  // STAGE_INIT
            S_READ_WINDOW: stage = 3'b010;  // STAGE_LOAD
            S_COMPUTE:     stage = 3'b011;  // STAGE_COMPUTE
            S_BIAS_ACT:    stage = 3'b100;  // STAGE_ACTIVATE
            S_STORE:       stage = 3'b101;  // STAGE_STORE
            S_NEXT_PIXEL:  stage = 3'b101;  // STAGE_STORE
            default:       stage = 3'b000;  // STAGE_IDLE
        endcase
    end

endmodule
