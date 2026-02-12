// CNN Accelerator Top-Level
// Hierarchical design integrating:
// - Memory subsystem (BRAMs + kernel/bias registers)
// - Compute datapath (9-way MAC + activation + pooling)
// - Controller (FSM + 2D address generation)
//
// Single-channel 3x3 convolution: y = ReLU(conv2d(input, kernel) + bias)
// INT8 quantized: INT8 inputs/weights, INT16 accumulators, INT8 outputs
// Optional 2x2 max pooling

`timescale 1ns / 1ps

module cnn_top #(
    parameter IMG_W    = 16,
    parameter IMG_H    = 16,
    parameter KER_SIZE = 3,
    parameter STRIDE   = 1,
    parameter PAD      = 1,
    parameter POOL_EN  = 1,
    parameter DATA_W   = 8,
    parameter ACC_W    = 16
)(
    // Clock and reset
    input  logic         clk,
    input  logic         rst_n,

    // Control interface
    input  logic         start,
    output logic         done,
    output logic         busy,

    // Configuration (runtime override for pooling)
    input  logic         pool_enable,

    // Host input feature map load interface
    input  logic [15:0]  ifmap_addr,
    input  logic [7:0]   ifmap_data,
    input  logic         ifmap_we,

    // Host kernel weight load interface
    input  logic [3:0]   kernel_addr,
    input  logic [7:0]   kernel_data,
    input  logic         kernel_we,

    // Host bias load interface
    input  logic [7:0]   bias_data,
    input  logic         bias_we,

    // Output interface
    output logic [7:0]   output_data,
    output logic         output_valid,

    // Debug: Output BRAM write interface (directly exposed for ILA)
    output logic [15:0]  output_wr_addr,
    output logic [7:0]   output_wr_data,
    output logic         output_wr_en,

    // Performance monitoring
    output logic [2:0]   stage           // Current pipeline stage for perf_counters
);

    // =========================================================================
    // Computed parameters
    // =========================================================================
    localparam OUT_H = (IMG_H + 2*PAD - KER_SIZE) / STRIDE + 1;
    localparam OUT_W = (IMG_W + 2*PAD - KER_SIZE) / STRIDE + 1;
    localparam NUM_MACS = KER_SIZE * KER_SIZE;  // 9

    // =========================================================================
    // Memory subsystem signals
    // =========================================================================
    logic [15:0] mem_ifmap_rd_addr;
    logic [7:0]  mem_ifmap_rd_data;
    logic [3:0]  mem_kernel_rd_addr;
    logic [7:0]  mem_kernel_rd_data;
    logic [7:0]  mem_bias_rd_data;
    logic [15:0] mem_ofmap_wr_addr;
    logic [7:0]  mem_ofmap_wr_data;
    logic        mem_ofmap_wr_en;
    logic [15:0] mem_ofmap_rd_addr;
    logic [7:0]  mem_ofmap_rd_data;

    // =========================================================================
    // Datapath signals
    // =========================================================================
    logic signed [7:0]  datapath_window[0:NUM_MACS-1];
    logic signed [7:0]  datapath_kernel[0:NUM_MACS-1];
    logic signed [7:0]  datapath_bias;
    logic signed [7:0]  datapath_conv_result;
    logic               datapath_conv_valid;
    logic signed [7:0]  datapath_pool_result;
    logic               datapath_pool_valid;
    logic signed [15:0] datapath_accumulator;
    logic               datapath_mac_valid;

    // =========================================================================
    // Controller signals
    // =========================================================================
    logic        ctrl_mac_enable;
    logic        ctrl_mac_clear;
    logic        ctrl_activation_enable;
    logic [1:0]  ctrl_activation_type;
    logic        ctrl_pool_enable;
    logic        ctrl_pool_clear;
    logic [1:0]  ctrl_pool_pixel_idx;
    logic        ctrl_load_kernel;
    logic [3:0]  ctrl_load_kernel_idx;
    logic        ctrl_load_window;
    logic [3:0]  ctrl_load_window_idx;
    logic        ctrl_pad_zero;
    logic [15:0] ctrl_ofmap_wr_addr;
    logic        ctrl_ofmap_wr_en;
    logic [$clog2(IMG_H)-1:0] ctrl_out_row;
    logic [$clog2(IMG_W)-1:0] ctrl_out_col;
    logic        ctrl_conv_result_ready;
    logic [2:0]  ctrl_stage;

    // =========================================================================
    // Pooling logic signals
    // =========================================================================
    logic signed [7:0] pool_row_buf [0:OUT_W-1];  // Buffer for even row conv results
    logic signed [7:0] pool_prev_col;              // Buffer for odd row, even col result
    logic        pool_row_is_odd;
    logic        pool_col_is_odd;
    logic signed [7:0] pool_max_top, pool_max_bot, pool_max_all;
    logic [15:0] pool_out_addr;
    logic        pool_write_en;

    // =========================================================================
    // Module Instantiations
    // =========================================================================

    // Memory Subsystem
    (* DONT_TOUCH = "TRUE" *)
    cnn_memory_subsystem #(
        .IMG_W(IMG_W),
        .IMG_H(IMG_H),
        .KER_SIZE(KER_SIZE)
    ) memory_inst (
        .clk(clk),
        .rst_n(rst_n),

        // Host write interface
        .ifmap_addr(ifmap_addr),
        .ifmap_data(ifmap_data),
        .ifmap_we(ifmap_we),

        .kernel_addr(kernel_addr),
        .kernel_data(kernel_data),
        .kernel_we(kernel_we),

        .bias_data(bias_data),
        .bias_we(bias_we),

        // Compute read interface
        .ifmap_rd_addr(mem_ifmap_rd_addr),
        .ifmap_rd_data(mem_ifmap_rd_data),

        .kernel_rd_addr(mem_kernel_rd_addr),
        .kernel_rd_data(mem_kernel_rd_data),

        .bias_rd_data(mem_bias_rd_data),

        // Output write interface
        .ofmap_wr_addr(mem_ofmap_wr_addr),
        .ofmap_wr_data(mem_ofmap_wr_data),
        .ofmap_we(mem_ofmap_wr_en),

        // Output read interface
        .ofmap_rd_addr(mem_ofmap_rd_addr),
        .ofmap_rd_data(mem_ofmap_rd_data)
    );

    // Compute Datapath
    (* DONT_TOUCH = "TRUE" *)
    cnn_compute_datapath datapath_inst (
        .clk(clk),
        .rst_n(rst_n),

        // Control signals
        .mac_enable(ctrl_mac_enable),
        .mac_clear(ctrl_mac_clear),
        .activation_enable(ctrl_activation_enable),
        .activation_type(ctrl_activation_type),

        // Pooling control (directly from pool unit, unused in top-level pooling mode)
        .pool_enable(1'b0),
        .pool_clear(1'b0),
        .pool_pixel_idx(2'b00),

        // Data inputs
        .window_data(datapath_window),
        .kernel_data(datapath_kernel),
        .bias_in(datapath_bias),

        // Data outputs
        .conv_result(datapath_conv_result),
        .conv_valid(datapath_conv_valid),
        .pool_result(datapath_pool_result),
        .pool_valid(datapath_pool_valid),

        // Status
        .accumulator(datapath_accumulator),
        .mac_valid(datapath_mac_valid)
    );

    // Controller
    (* DONT_TOUCH = "TRUE" *)
    cnn_controller #(
        .IMG_W(IMG_W),
        .IMG_H(IMG_H),
        .KER_SIZE(KER_SIZE),
        .STRIDE(STRIDE),
        .PAD(PAD)
    ) controller_inst (
        .clk(clk),
        .rst_n(rst_n),

        // Control interface
        .start(start),
        .done(done),
        .busy(busy),

        // Memory address control
        .ifmap_rd_addr(mem_ifmap_rd_addr),
        .kernel_rd_addr(mem_kernel_rd_addr),
        .ofmap_wr_addr(ctrl_ofmap_wr_addr),
        .ofmap_wr_en(ctrl_ofmap_wr_en),

        // Datapath control
        .mac_enable(ctrl_mac_enable),
        .mac_clear(ctrl_mac_clear),
        .activation_enable(ctrl_activation_enable),
        .activation_type(ctrl_activation_type),

        // Datapath status
        .mac_valid(datapath_mac_valid),
        .conv_valid(datapath_conv_valid),

        // Data loading control
        .load_kernel(ctrl_load_kernel),
        .load_kernel_idx(ctrl_load_kernel_idx),
        .load_window(ctrl_load_window),
        .load_window_idx(ctrl_load_window_idx),
        .pad_zero(ctrl_pad_zero),

        // Output position
        .out_row(ctrl_out_row),
        .out_col(ctrl_out_col),
        .conv_result_ready(ctrl_conv_result_ready),
        .stage(ctrl_stage)
    );

    // =========================================================================
    // Data Loading Logic
    // =========================================================================

    // Load kernel weights from memory into datapath registers
    // Load window pixels from memory (or zero for padding) into datapath registers
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < NUM_MACS; i++) begin
                datapath_window[i] <= 8'h00;
                datapath_kernel[i] <= 8'h00;
            end
            datapath_bias <= 8'h00;
        end else begin
            // Load kernel weights during S_LOAD_KERNEL
            if (ctrl_load_kernel) begin
                datapath_kernel[ctrl_load_kernel_idx] <= $signed(mem_kernel_rd_data);
            end

            // Load window pixels during S_READ_WINDOW
            if (ctrl_load_window) begin
                if (ctrl_pad_zero)
                    datapath_window[ctrl_load_window_idx] <= 8'h00;
                else
                    datapath_window[ctrl_load_window_idx] <= $signed(mem_ifmap_rd_data);
            end

            // Bias is continuously available from memory subsystem
            datapath_bias <= $signed(mem_bias_rd_data);
        end
    end

    // =========================================================================
    // Pooling Logic (handled at top-level for simplicity)
    // =========================================================================

    assign pool_row_is_odd = ctrl_out_row[0];
    assign pool_col_is_odd = ctrl_out_col[0];

    // Max-of-4 combinational logic for pooling
    always_comb begin
        pool_max_top = (pool_row_buf[ctrl_out_col - 1] > pool_row_buf[ctrl_out_col]) ?
                        pool_row_buf[ctrl_out_col - 1] : pool_row_buf[ctrl_out_col];
        pool_max_bot = (pool_prev_col > datapath_conv_result) ?
                        pool_prev_col : datapath_conv_result;
        pool_max_all = (pool_max_top > pool_max_bot) ? pool_max_top : pool_max_bot;
    end

    // Pooling buffer management
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < OUT_W; i++)
                pool_row_buf[i] <= 8'h00;
            pool_prev_col <= 8'h00;
            pool_out_addr <= 16'h0000;
            pool_write_en <= 1'b0;
        end else begin
            pool_write_en <= 1'b0;

            if (ctrl_conv_result_ready && pool_enable) begin
                if (!pool_row_is_odd) begin
                    // Even row: buffer the conv result
                    pool_row_buf[ctrl_out_col] <= datapath_conv_result;
                end else begin
                    if (!pool_col_is_odd) begin
                        // Odd row, even col: buffer as prev_col
                        pool_prev_col <= datapath_conv_result;
                    end else begin
                        // Odd row, odd col: compute max-of-4, write to output
                        pool_write_en <= 1'b1;
                        pool_out_addr <= pool_out_addr + 1;
                    end
                end
            end

            // Reset pool output address on start
            if (start && !busy) begin
                pool_out_addr <= 16'h0000;
            end
        end
    end

    // =========================================================================
    // Output Write Multiplexing
    // =========================================================================

    always_comb begin
        if (pool_enable) begin
            // Pooled output
            mem_ofmap_wr_addr = pool_out_addr;
            mem_ofmap_wr_data = pool_max_all;
            mem_ofmap_wr_en   = pool_write_en;
        end else begin
            // Direct conv output (no pooling)
            mem_ofmap_wr_addr = ctrl_ofmap_wr_addr;
            mem_ofmap_wr_data = datapath_conv_result;
            mem_ofmap_wr_en   = ctrl_ofmap_wr_en;
        end
    end

    // =========================================================================
    // Output Interface
    // =========================================================================

    assign output_data  = pool_enable ? pool_max_all : datapath_conv_result;
    assign output_valid = pool_enable ? pool_write_en : datapath_conv_valid;

    // Debug: Expose BRAM write signals
    assign output_wr_addr = mem_ofmap_wr_addr;
    assign output_wr_data = mem_ofmap_wr_data;
    assign output_wr_en   = mem_ofmap_wr_en;

    // Performance monitoring
    assign stage = ctrl_stage;

    // Default output read address
    assign mem_ofmap_rd_addr = 16'h0000;

endmodule
