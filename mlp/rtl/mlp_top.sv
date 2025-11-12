// MLP Accelerator Top-Level
// Hierarchical design integrating:
// - Memory subsystem (BRAMs)
// - Compute datapath (MAC + activation)
// - Controller (FSM)
//
// Fully-connected layer compute: y = ReLU(W·x + b)
// INT8 inputs/weights, INT16 accumulators, INT8 outputs (Q4.4)

`timescale 1ns / 1ps

module mlp_top (
    // Clock and reset
    input  logic         clk,
    input  logic         rst_n,

    // Control interface
    input  logic         start,
    output logic         done,
    output logic         busy,

    // Configuration
    input  logic [15:0]  num_inputs,    // Number of input features
    input  logic [15:0]  num_outputs,   // Number of output neurons

    // Host input load interface
    input  logic [15:0]  input_addr,
    input  logic [7:0]   input_data,
    input  logic         input_we,

    // Host weight load interface
    input  logic [15:0]  weight_addr,
    input  logic [7:0]   weight_data,
    input  logic         weight_we,

    // Host bias load interface
    input  logic [15:0]  bias_addr,
    input  logic [7:0]   bias_data,
    input  logic         bias_we,

    // Output interface
    output logic [7:0]   output_data,
    output logic         output_valid
);

    // Memory subsystem signals
    logic [15:0] mem_input_rd_addr;
    logic [7:0]  mem_input_rd_data;
    logic [15:0] mem_weight_rd_addr;
    logic [7:0]  mem_weight_rd_data;
    logic [7:0]  mem_bias_rd_addr;
    logic [7:0]  mem_bias_rd_data;
    logic [15:0] mem_output_wr_addr;
    logic [7:0]  mem_output_wr_data;
    logic        mem_output_wr_en;
    logic [15:0] mem_output_rd_addr;
    logic [7:0]  mem_output_rd_data;

    // Datapath signals
    logic [7:0]  datapath_data_in[0:7];
    logic [7:0]  datapath_weight_in[0:7];
    logic signed [7:0] datapath_bias_in;
    logic [7:0]  datapath_result_out;
    logic        datapath_result_valid;
    logic signed [15:0] datapath_accumulator;
    logic        datapath_mac_valid;

    // Controller signals
    logic        ctrl_mac_enable;
    logic        ctrl_mac_clear;
    logic        ctrl_activation_enable;
    logic [1:0]  ctrl_activation_type;
    logic        ctrl_load_inputs_weights;
    logic [2:0]  ctrl_load_offset;

    //==========================================================================
    // Module Instantiations
    //==========================================================================

    // Memory Subsystem
    mlp_memory_subsystem memory_inst (
        .clk(clk),
        .rst_n(rst_n),

        // Host write interface
        .input_addr(input_addr),
        .input_data(input_data),
        .input_we(input_we),

        .weight_addr(weight_addr),
        .weight_data(weight_data),
        .weight_we(weight_we),

        .bias_addr(bias_addr),
        .bias_data(bias_data),
        .bias_we(bias_we),

        // Compute read interface
        .input_rd_addr(mem_input_rd_addr),
        .input_rd_data(mem_input_rd_data),

        .weight_rd_addr(mem_weight_rd_addr),
        .weight_rd_data(mem_weight_rd_data),

        .bias_rd_addr(mem_bias_rd_addr),
        .bias_rd_data(mem_bias_rd_data),

        // Output write interface
        .output_wr_addr(mem_output_wr_addr),
        .output_wr_data(mem_output_wr_data),
        .output_wr_en(mem_output_wr_en),

        // Output read interface
        .output_rd_addr(mem_output_rd_addr),
        .output_rd_data(mem_output_rd_data)
    );

    // Compute Datapath
    mlp_compute_datapath datapath_inst (
        .clk(clk),
        .rst_n(rst_n),

        // Control signals
        .mac_enable(ctrl_mac_enable),
        .mac_clear(ctrl_mac_clear),
        .activation_enable(ctrl_activation_enable),
        .activation_type(ctrl_activation_type),

        // Data inputs
        .data_in(datapath_data_in),
        .weight_in(datapath_weight_in),
        .bias_in(datapath_bias_in),

        // Data outputs
        .result_out(datapath_result_out),
        .result_valid(datapath_result_valid),

        // Status outputs
        .accumulator(datapath_accumulator),
        .mac_valid(datapath_mac_valid)
    );

    // Controller
    mlp_controller controller_inst (
        .clk(clk),
        .rst_n(rst_n),

        // Control interface
        .start(start),
        .done(done),
        .busy(busy),

        // Configuration
        .num_inputs(num_inputs),
        .num_outputs(num_outputs),

        // Memory read control
        .input_rd_addr(mem_input_rd_addr),
        .weight_rd_addr(mem_weight_rd_addr),
        .bias_rd_addr(mem_bias_rd_addr),

        // Memory write control
        .output_wr_addr(mem_output_wr_addr),
        .output_wr_en(mem_output_wr_en),

        // Datapath control
        .mac_enable(ctrl_mac_enable),
        .mac_clear(ctrl_mac_clear),
        .activation_enable(ctrl_activation_enable),
        .activation_type(ctrl_activation_type),

        // Datapath status
        .mac_valid(datapath_mac_valid),
        .result_valid(datapath_result_valid),

        // Data flow control
        .load_inputs_weights(ctrl_load_inputs_weights),
        .load_offset(ctrl_load_offset)
    );

    //==========================================================================
    // Data Loading Logic
    //==========================================================================

    // Load data from memory into datapath when signaled by controller
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < 8; i++) begin
                datapath_data_in[i] <= 8'h00;
                datapath_weight_in[i] <= 8'h00;
            end
            datapath_bias_in <= 8'h00;
        end else begin
            if (ctrl_load_inputs_weights) begin
                // Load 8 parallel inputs and weights from memory
                // Memory addresses are already set by controller
                for (int i = 0; i < 8; i++) begin
                    // Note: In real implementation, you'd need to handle
                    // the memory read latency properly. This is simplified.
                    datapath_data_in[i] <= mem_input_rd_data;
                    datapath_weight_in[i] <= mem_weight_rd_data;
                end
            end

            // Load bias for current neuron
            datapath_bias_in <= $signed(mem_bias_rd_data);
        end
    end

    //==========================================================================
    // Output Interface
    //==========================================================================

    // Connect datapath output to top-level output
    assign mem_output_wr_data = datapath_result_out;
    assign output_data = datapath_result_out;
    assign output_valid = datapath_result_valid;

    // Default output read address (can be extended for host readback)
    assign mem_output_rd_addr = 16'h0000;

endmodule
