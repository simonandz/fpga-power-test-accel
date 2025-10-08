`timescale 1ns / 1ps

//==============================================================================
// Module: accel_top
// Description: Top-level accelerator framework with memory-mapped I/O
//              Integrates all shared infrastructure components
//==============================================================================

import accel_pkg::*;

module accel_top #(
    parameter NUM_BRAM_BANKS = 19
) (
    input  logic        clk,
    input  logic        rst_n,

    //--------------------------------------------------------------------------
    // Memory-Mapped Control/Status Interface
    //--------------------------------------------------------------------------
    input  logic        start,
    output logic        done,
    output logic        busy,

    // Configuration registers
    input  logic [1:0]  accel_type,       // Select MLP/CNN/RNN
    input  logic [15:0] config_data,      // Accelerator-specific config

    // Memory interface (simple)
    input  logic [15:0] input_addr,
    input  logic [7:0]  input_data,
    input  logic        input_we,
    output logic [7:0]  output_data,
    output logic        output_valid,

    // Configuration (base addresses and sizes)
    input  logic [15:0] weight_base_addr,
    input  logic [15:0] weight_size,
    input  logic [15:0] input_base_addr,
    input  logic [15:0] input_size,
    input  logic [15:0] output_base_addr,
    input  logic [15:0] output_size,

    // Bank assignments
    input  logic [4:0]  weight_bank,
    input  logic [4:0]  input_bank,
    input  logic [4:0]  output_bank,

    //--------------------------------------------------------------------------
    // Debug/Status
    //--------------------------------------------------------------------------
    output logic [2:0]  current_state,
    output logic [7:0]  error_flags
);

    //--------------------------------------------------------------------------
    // Internal Signals
    //--------------------------------------------------------------------------

    // Control signals
    ctrl_req_t      ctrl_req;
    ctrl_resp_t     ctrl_resp;

    // Memory controller
    mem_req_t       mem_req;
    mem_resp_t      mem_resp;

    // Address generator
    logic                   agu_start;
    access_pattern_e        agu_pattern;
    logic [ADDR_WIDTH-1:0]  agu_base_addr;
    logic [15:0]            agu_length;
    logic                   agu_done;
    logic [ADDR_WIDTH-1:0]  agu_addr;
    logic                   agu_addr_valid;
    logic                   agu_addr_ready;

    // Address generator config (for 2D patterns)
    logic [7:0]             agu_stride;
    logic [7:0]             agu_width;
    logic [7:0]             agu_height;
    logic [7:0]             agu_kernel_size;

    // Compute interface (to be connected to specific accelerator)
    logic                   compute_start;
    logic [15:0]            compute_config;
    logic                   compute_done;
    logic [7:0]             compute_error;

    // Power management
    logic [BRAM_BANKS-1:0]  bank_power_en;
    logic                   mlp_clk_en;
    logic                   cnn_clk_en;
    logic                   rnn_clk_en;
    logic                   mlp_dsp_en;
    logic                   cnn_dsp_en;
    logic                   rnn_dsp_en;

    // BRAM interfaces
    logic [BRAM_BANKS-1:0]              bram_en;
    logic [BRAM_BANKS-1:0]              bram_we;
    logic [BRAM_ADDR_WIDTH-1:0]         bram_addr   [BRAM_BANKS-1:0];
    logic [DATA_WIDTH-1:0]              bram_din    [BRAM_BANKS-1:0];
    logic [DATA_WIDTH-1:0]              bram_dout   [BRAM_BANKS-1:0];

    //--------------------------------------------------------------------------
    // Input Mapping
    //--------------------------------------------------------------------------
    assign ctrl_req.start       = start;
    assign ctrl_req.accel_type  = accel_type;
    assign ctrl_req.config_data = config_data;

    // Extract AGU configuration from config_data (example mapping)
    // Bits [15:12]: kernel_size
    // Bits [11:8]:  stride
    // Bits [7:0]:   reserved
    assign agu_kernel_size = config_data[15:12];
    assign agu_stride      = config_data[11:8];
    assign agu_width       = 8'd28;  // Example: 28x28 input
    assign agu_height      = 8'd28;

    //--------------------------------------------------------------------------
    // Output Mapping
    //--------------------------------------------------------------------------
    assign done          = ctrl_resp.done;
    assign busy          = ctrl_resp.busy;
    assign current_state = ctrl_resp.state;
    assign error_flags   = ctrl_resp.error_flags;

    // Simple output - return memory read data
    assign output_data   = mem_resp.data;
    assign output_valid  = mem_resp.valid;

    //--------------------------------------------------------------------------
    // Temporary: Compute done (to be replaced by actual accelerators)
    //--------------------------------------------------------------------------
    // Placeholder - pulse done after a few cycles in compute state
    logic [7:0] compute_counter;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            compute_counter <= '0;
        end else begin
            if (compute_start)
                compute_counter <= '0;
            else if (compute_counter < 8'd10)
                compute_counter <= compute_counter + 1;
        end
    end

    assign compute_done  = (compute_counter == 8'd10);
    assign compute_error = 8'h00;

    //--------------------------------------------------------------------------
    // Module Instantiations
    //--------------------------------------------------------------------------

    // Unified controller
    accel_controller u_controller (
        .clk                (clk),
        .rst_n              (rst_n),
        .ctrl_req           (ctrl_req),
        .ctrl_resp          (ctrl_resp),
        .mem_req            (mem_req),
        .mem_resp           (mem_resp),
        .agu_start          (agu_start),
        .agu_pattern        (agu_pattern),
        .agu_base_addr      (agu_base_addr),
        .agu_length         (agu_length),
        .agu_done           (agu_done),
        .agu_addr           (agu_addr),
        .agu_addr_valid     (agu_addr_valid),
        .agu_addr_ready     (agu_addr_ready),
        .compute_start      (compute_start),
        .compute_config     (compute_config),
        .compute_done       (compute_done),
        .compute_error      (compute_error),
        .weight_base_addr   (weight_base_addr),
        .weight_size        (weight_size),
        .input_base_addr    (input_base_addr),
        .input_size         (input_size),
        .output_base_addr   (output_base_addr),
        .output_size        (output_size),
        .weight_bank        (weight_bank),
        .input_bank         (input_bank),
        .output_bank        (output_bank)
    );

    // Address generation unit
    addr_gen_unit u_agu (
        .clk                (clk),
        .rst_n              (rst_n),
        .start              (agu_start),
        .pattern            (agu_pattern),
        .base_addr          (agu_base_addr),
        .length             (agu_length),
        .done               (agu_done),
        .stride             (agu_stride),
        .width              (agu_width),
        .height             (agu_height),
        .kernel_size        (agu_kernel_size),
        .addr               (agu_addr),
        .addr_valid         (agu_addr_valid),
        .addr_ready         (agu_addr_ready)
    );

    // Memory controller
    memory_controller u_mem_ctrl (
        .clk                (clk),
        .rst_n              (rst_n),
        .req                (mem_req),
        .resp               (mem_resp),
        .bank_power_en      (bank_power_en),
        .bram_en            (bram_en),
        .bram_we            (bram_we),
        .bram_addr          (bram_addr),
        .bram_din           (bram_din),
        .bram_dout          (bram_dout)
    );

    // Power manager
    power_manager u_power_mgr (
        .clk                (clk),
        .rst_n              (rst_n),
        .active_accel       (accel_type_e'(accel_type)),
        .accel_active       (busy),
        .current_state      (state_e'(current_state)),
        .mlp_clk_en         (mlp_clk_en),
        .cnn_clk_en         (cnn_clk_en),
        .rnn_clk_en         (rnn_clk_en),
        .bank_power_en      (bank_power_en),
        .mlp_dsp_en         (mlp_dsp_en),
        .cnn_dsp_en         (cnn_dsp_en),
        .rnn_dsp_en         (rnn_dsp_en)
    );

    //--------------------------------------------------------------------------
    // BRAM Bank Instances
    //--------------------------------------------------------------------------
    genvar i;
    generate
        for (i = 0; i < BRAM_BANKS; i++) begin : gen_bram_banks
            bram_bank #(
                .DATA_WIDTH     (DATA_WIDTH),
                .ADDR_WIDTH     (BRAM_ADDR_WIDTH),
                .DEPTH          (BRAM_DEPTH)
            ) u_bram (
                .clk            (clk),
                .en             (bram_en[i]),
                .we             (bram_we[i]),
                .addr           (bram_addr[i]),
                .din            (bram_din[i]),
                .dout           (bram_dout[i])
            );
        end
    endgenerate

    //--------------------------------------------------------------------------
    // TODO: Instantiate compute units (MLP, CNN, RNN)
    // These will be added in subsequent weeks
    //--------------------------------------------------------------------------
    // mlp_core u_mlp (...);
    // cnn_core u_cnn (...);
    // rnn_core u_rnn (...);

endmodule
