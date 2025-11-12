// MLP Controller
// FSM-based control logic for MLP accelerator
// Orchestrates memory access and compute operations

`timescale 1ns / 1ps

module mlp_controller (
    input  logic         clk,
    input  logic         rst_n,

    // Control interface
    input  logic         start,
    output logic         done,
    output logic         busy,

    // Configuration
    input  logic [15:0]  num_inputs,
    input  logic [15:0]  num_outputs,

    // Memory read control
    output logic [15:0]  input_rd_addr,
    output logic [15:0]  weight_rd_addr,
    output logic [7:0]   bias_rd_addr,

    // Memory write control
    output logic [15:0]  output_wr_addr,
    output logic         output_wr_en,

    // Datapath control
    output logic         mac_enable,
    output logic         mac_clear,
    output logic         activation_enable,
    output logic [1:0]   activation_type,

    // Datapath status
    input  logic         mac_valid,
    input  logic         result_valid,

    // Data flow control
    output logic         load_inputs_weights,  // Signal to load data into datapath
    output logic [2:0]   load_offset           // Which of 8 inputs to load
);

    // FSM states
    typedef enum logic [2:0] {
        IDLE           = 3'b000,
        INIT_NEURON    = 3'b001,
        LOAD_DATA      = 3'b010,
        COMPUTE        = 3'b011,
        ACTIVATE       = 3'b100,
        STORE_OUTPUT   = 3'b101,
        DONE_STATE     = 3'b110
    } state_t;

    state_t state, next_state;

    // Address and index registers
    logic [15:0] addr_in;
    logic [15:0] addr_wt;
    logic [15:0] addr_out;
    logic [15:0] input_idx;
    logic [15:0] neuron_idx;
    logic [15:0] weight_base_addr;
    logic [2:0]  mac_count;

    // FSM state register
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) state <= IDLE;
        else state <= next_state;
    end

    // FSM next state logic
    always_comb begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) next_state = INIT_NEURON;
            end

            INIT_NEURON: begin
                next_state = LOAD_DATA;
            end

            LOAD_DATA: begin
                next_state = COMPUTE;
            end

            COMPUTE: begin
                if (input_idx >= num_inputs) begin
                    // Wait for final MAC to complete
                    if (mac_valid) next_state = ACTIVATE;
                end else begin
                    next_state = LOAD_DATA;  // Load next batch
                end
            end

            ACTIVATE: begin
                if (result_valid) next_state = STORE_OUTPUT;
            end

            STORE_OUTPUT: begin
                if (neuron_idx + 1 >= num_outputs) begin
                    next_state = DONE_STATE;
                end else begin
                    next_state = INIT_NEURON;  // Next neuron
                end
            end

            DONE_STATE: begin
                if (!start) next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    // Control and datapath logic
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done <= 1'b0;
            busy <= 1'b0;
            addr_in <= 16'h0000;
            addr_wt <= 16'h0000;
            addr_out <= 16'h0000;
            input_idx <= 16'h0000;
            neuron_idx <= 16'h0000;
            weight_base_addr <= 16'h0000;
            mac_count <= 3'h0;
            mac_enable <= 1'b0;
            mac_clear <= 1'b0;
            activation_enable <= 1'b0;
            activation_type <= 2'b00;  // ReLU
            output_wr_en <= 1'b0;
            load_inputs_weights <= 1'b0;
            load_offset <= 3'h0;
        end else begin
            // Default values
            mac_enable <= 1'b0;
            mac_clear <= 1'b0;
            activation_enable <= 1'b0;
            output_wr_en <= 1'b0;
            load_inputs_weights <= 1'b0;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    busy <= 1'b0;
                    neuron_idx <= 16'h0000;
                    addr_out <= 16'h0000;
                    weight_base_addr <= 16'h0000;
                end

                INIT_NEURON: begin
                    busy <= 1'b1;
                    // Initialize for new neuron
                    addr_in <= 16'h0000;
                    addr_wt <= weight_base_addr;
                    input_idx <= 16'h0000;
                    mac_clear <= 1'b1;  // Clear accumulator
                    mac_count <= 3'h0;
                end

                LOAD_DATA: begin
                    // Prepare to load 8 inputs and 8 weights
                    load_inputs_weights <= 1'b1;
                    load_offset <= mac_count;
                end

                COMPUTE: begin
                    // Enable MAC for current batch
                    mac_enable <= 1'b1;

                    // Update addresses and indices
                    addr_in <= addr_in + 16'h0008;
                    addr_wt <= addr_wt + 16'h0008;
                    input_idx <= input_idx + 16'h0008;
                    mac_count <= mac_count + 1;
                end

                ACTIVATE: begin
                    // Trigger activation (ReLU)
                    activation_enable <= 1'b1;
                    activation_type <= 2'b00;  // ReLU
                end

                STORE_OUTPUT: begin
                    if (result_valid) begin
                        // Write result to output BRAM
                        output_wr_en <= 1'b1;
                        addr_out <= addr_out + 16'h0001;

                        // Move to next neuron
                        neuron_idx <= neuron_idx + 16'h0001;
                        weight_base_addr <= weight_base_addr + num_inputs;
                    end
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    busy <= 1'b0;
                end

                default: begin
                    done <= 1'b0;
                    busy <= 1'b0;
                end
            endcase
        end
    end

    // Output address assignments
    assign input_rd_addr = addr_in;
    assign weight_rd_addr = addr_wt;
    assign bias_rd_addr = neuron_idx[7:0];
    assign output_wr_addr = addr_out;

endmodule
