// MLP Accelerator - Refactored with Shared Modules
// Fully-connected layer compute: y = activation(W·x + b)
// Format: Signed INT8/INT16 throughout
// - INT8 inputs/weights/bias: -128 to +127
// - INT16 accumulator: -32768 to +32767
// - INT8 outputs after activation: -128 to +127
// Uses shared MAC array and activation modules

`timescale 1ns / 1ps

module mlp_core_refactored (
    // Clock and reset
    input  logic         clk,
    input  logic         rst_n,

    // Control interface
    input  logic         start,
    output logic         done,

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

    // FSM states
    typedef enum logic [2:0] {
        IDLE           = 3'b000,
        LOAD_INPUT     = 3'b001,
        COMPUTE        = 3'b010,
        ACTIVATE       = 3'b011,
        STORE_OUTPUT   = 3'b100,
        DONE_STATE     = 3'b101
    } state_t;

    state_t state, next_state;

    // BRAMs
    logic [7:0]  input_bram[0:4095];
    logic [7:0]  weight_bram[0:16383];
    logic [7:0]  bias_bram[0:255];
    logic [7:0]  output_bram[0:4095];

    // MAC Array signals
    logic [7:0]  mac_data_in[0:7];
    logic [7:0]  mac_weight_in[0:7];
    logic signed [15:0] mac_out[0:7];
    logic signed [15:0] mac_partial_sum;
    logic        mac_enable;
    logic        mac_clear_acc;
    logic        mac_valid;

    // Activation unit signals
    logic [1:0]  activation_type;
    logic        activation_enable;
    logic signed [15:0] activation_in;
    logic [7:0]  activation_out;
    logic        activation_valid;

    // Address counters and control
    logic [15:0] addr_in;
    logic [15:0] addr_wt;
    logic [15:0] addr_out;
    logic [15:0] input_idx;
    logic [15:0] neuron_idx;
    logic [15:0] weight_base_addr;
    logic [2:0]  compute_cycle;
    logic signed [15:0] acc_reg;
    logic signed [7:0]  bias_reg;

    // MAC Array instance
    mac_array_8x mac_array_inst (
        .clk(clk),
        .rst_n(rst_n),
        .enable(mac_enable),
        .clear_acc(mac_clear_acc),
        .data_in(mac_data_in),
        .weight_in(mac_weight_in),
        .mac_out(mac_out),
        .partial_sum(mac_partial_sum),
        .valid(mac_valid)
    );

    // Activation Unit instance (ReLU)
    activation_unit activation_inst (
        .clk(clk),
        .rst_n(rst_n),
        .activation_type(activation_type),
        .enable(activation_enable),
        .data_in(activation_in),
        .data_out(activation_out),
        .valid(activation_valid)
    );

    // Host write interface for BRAMs
    always_ff @(posedge clk) begin
        if (input_we) input_bram[input_addr[11:0]] <= input_data;
        if (weight_we) weight_bram[weight_addr[13:0]] <= weight_data;
        if (bias_we) bias_bram[bias_addr[7:0]] <= bias_data;
    end

    // FSM state register
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) state <= IDLE;
        else state <= next_state;
    end

    // FSM next state logic
    always_comb begin
        next_state = state;
        case (state)
            IDLE: if (start) next_state = LOAD_INPUT;

            LOAD_INPUT: next_state = COMPUTE;

            COMPUTE: begin
                if (neuron_idx >= num_outputs) next_state = DONE_STATE;
                else if (input_idx > num_inputs && compute_cycle == 3'h0) next_state = ACTIVATE;
            end

            ACTIVATE: if (activation_valid) next_state = STORE_OUTPUT;

            STORE_OUTPUT: next_state = COMPUTE;

            DONE_STATE: if (!start) next_state = IDLE;

            default: next_state = IDLE;
        endcase
    end

    // Main computation logic
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            addr_in <= 16'h0000;
            addr_wt <= 16'h0000;
            addr_out <= 16'h0000;
            input_idx <= 16'h0000;
            neuron_idx <= 16'h0000;
            weight_base_addr <= 16'h0000;
            compute_cycle <= 3'h0;
            acc_reg <= 16'h0000;
            bias_reg <= 8'h00;
            done <= 1'b0;
            output_valid <= 1'b0;
            output_data <= 8'h00;
            mac_enable <= 1'b0;
            mac_clear_acc <= 1'b0;
            activation_enable <= 1'b0;
            activation_type <= 2'b00;  // ReLU
            activation_in <= 16'h0000;
            for (int i = 0; i < 8; i++) begin
                mac_data_in[i] <= 8'h00;
                mac_weight_in[i] <= 8'h00;
            end
        end else begin
            // Default values
            mac_enable <= 1'b0;
            mac_clear_acc <= 1'b0;
            activation_enable <= 1'b0;
            output_valid <= 1'b0;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    neuron_idx <= 16'h0000;
                    addr_out <= 16'h0000;
                    if (start) begin
                        addr_in <= 16'h0000;
                        weight_base_addr <= 16'h0000;
                    end
                end

                LOAD_INPUT: begin
                    input_idx <= 16'h0000;
                    acc_reg <= 16'h0000;
                end

                COMPUTE: begin
                    if (neuron_idx < num_outputs) begin
                        if (input_idx == 16'h0000) begin
                            // Start new neuron
                            acc_reg <= 16'h0000;
                            addr_wt <= weight_base_addr;
                            addr_in <= 16'h0000;
                            input_idx <= 16'h0008;
                            compute_cycle <= 3'h0;
                            bias_reg <= $signed(bias_bram[neuron_idx[7:0]]);
                            mac_clear_acc <= 1'b1;
                        end else if (input_idx <= num_inputs) begin
                            // Load data into MAC array
                            for (int i = 0; i < 8; i++) begin
                                if ((input_idx - 8 + i) < num_inputs) begin
                                    mac_data_in[i] <= input_bram[addr_in + i];
                                    mac_weight_in[i] <= weight_bram[addr_wt + i];
                                end else begin
                                    mac_data_in[i] <= 8'h00;
                                    mac_weight_in[i] <= 8'h00;
                                end
                            end

                            // Enable MAC
                            mac_enable <= 1'b1;

                            // Update addresses
                            addr_in <= addr_in + 16'h0008;
                            addr_wt <= addr_wt + 16'h0008;
                            input_idx <= input_idx + 16'h0008;
                        end

                        // Accumulate MAC results
                        if (mac_valid) begin
                            acc_reg <= acc_reg + mac_partial_sum;
                        end
                    end
                end

                ACTIVATE: begin
                    // Add bias and activate (simple INT16 addition)
                    activation_in <= acc_reg + $signed(bias_reg);
                    activation_type <= 2'b00;  // ReLU
                    activation_enable <= 1'b1;
                end

                STORE_OUTPUT: begin
                    if (activation_valid) begin
                        output_bram[addr_out] <= activation_out;
                        output_data <= activation_out;
                        output_valid <= 1'b1;
                        addr_out <= addr_out + 16'h0001;

                        // Move to next neuron
                        neuron_idx <= neuron_idx + 16'h0001;
                        input_idx <= 16'h0000;
                        weight_base_addr <= weight_base_addr + num_inputs;
                    end
                end

                DONE_STATE: begin
                    done <= 1'b1;
                end

                default: done <= 1'b0;
            endcase
        end
    end

endmodule
