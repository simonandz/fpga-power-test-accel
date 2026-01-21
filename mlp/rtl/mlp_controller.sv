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
    logic [3:0]  load_counter;  // Counter for sequential BRAM reads (0-9)
    logic        activation_triggered;  // Flag to track if activation was triggered

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
                // Need 9 cycles (counter 0-8):
                // Cycle 0: Set up addr 0, set load signal
                // Cycles 1-8: Store data[0-7] at offsets [0-7]
                // Exit when counter reaches 9 (after storing data[7])
                if (load_counter >= 9) begin
                    next_state = COMPUTE;
                end
            end

            COMPUTE: begin
                // Check if we'll have processed all inputs after this batch
                // input_idx will be incremented by 8 in the COMPUTE state action
                if (input_idx + 16'h0008 >= num_inputs) begin
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
            load_counter <= 4'h0;
            activation_triggered <= 1'b0;
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
                    // Set addresses to 0 (or weight_base for weights)
                    // These will be presented to BRAM on the FIRST cycle of LOAD_DATA
                    addr_in <= 16'h0000;
                    addr_wt <= weight_base_addr;
                    input_idx <= 16'h0000;
                    mac_clear <= 1'b1;  // Clear accumulator
                    mac_count <= 3'h0;
                    load_counter <= 4'h0;  // Reset load counter
                end

                LOAD_DATA: begin
                    // Sequential BRAM reads with proper latency handling
                    //
                    // Key timing relationships:
                    // - addr_in is registered, combinationally assigned to input_rd_addr
                    // - BRAM registered read: addr at START of cycle N → data at END of cycle N
                    // - mlp_top samples mem_input_rd_data at clock edge when load_inputs_weights=1
                    // - The sampled data is stored at load_offset index
                    //
                    // To store data[0] at offset 0:
                    // - Need BRAM to output data[0] when load=1 and offset=0 are sampled
                    // - BRAM outputs data[0] at END of cycle where addr=0 at START
                    // - load=1/offset=0 set at end of cycle N are sampled at end of cycle N+1
                    // - So need addr=0 at start of cycle N+1 = addr=0 set at end of cycle N
                    //
                    // Timeline (addr_in=0 set at end of INIT_NEURON):
                    // Cycle 0: addr=0, BRAM gets addr 0, set load=1/offset=0, DON'T inc addr
                    // Cycle 1: addr=0, BRAM outputs data[0], store data[0]@[0], set offset=1, inc to 1
                    // Cycle 2: addr=1, BRAM outputs data[1], store data[1]@[1], set offset=2, inc to 2
                    // ...
                    // Cycle 7: addr=6, BRAM outputs data[6], store data[6]@[6], set offset=7, inc to 7
                    // Cycle 8: addr=7, BRAM outputs data[7], store data[7]@[7], clear load

                    if (load_counter >= 0 && load_counter <= 7) begin
                        // Set load signal and offset for NEXT cycle's store
                        load_inputs_weights <= 1'b1;
                        load_offset <= load_counter[2:0];
                    end else begin
                        load_inputs_weights <= 1'b0;
                    end

                    // Increment address starting from cycle 0
                    // Timeline with BRAM 1-cycle latency:
                    //   Cycle 0: addr=0, BRAM fetches data[0], set load=1/offset=0, inc addr to 1
                    //   Cycle 1: addr=1, BRAM outputs data[0], store data[0]@[0], set offset=1, inc to 2
                    //   Cycle 2: addr=2, BRAM outputs data[1], store data[1]@[1], set offset=2, inc to 3
                    //   ...
                    //   Cycle 7: addr=7, BRAM outputs data[6], store data[6]@[6], set offset=7, inc to 8
                    //   Cycle 8: addr=8, BRAM outputs data[7], store data[7]@[7], clear load
                    if (load_counter <= 7) begin
                        addr_in <= addr_in + 16'h0001;
                        addr_wt <= addr_wt + 16'h0001;
                    end

                    load_counter <= load_counter + 1;
                end

                COMPUTE: begin
                    // Enable MAC for ONE cycle only (on entry to this state)
                    // mac_count tracks whether we've already triggered the MAC
                    if (mac_count == 0) begin
                        mac_enable <= 1'b1;
                        mac_count <= 3'h1;  // Mark that MAC has been triggered
                    end

                    // Update indices only on first cycle
                    if (mac_count == 0) begin
                        input_idx <= input_idx + 16'h0008;
                    end

                    // Reset load counter for next batch (if needed)
                    load_counter <= 4'h0;
                end

                ACTIVATE: begin
                    // Trigger activation (ReLU) - but only once!
                    if (!activation_triggered) begin
                        activation_enable <= 1'b1;
                        activation_type <= 2'b00;  // ReLU
                        activation_triggered <= 1'b1;
                    end
                end

                STORE_OUTPUT: begin
                    // Write result to output BRAM (result_valid should be high when we enter this state)
                    output_wr_en <= 1'b1;

                    // Move to next neuron (increment AFTER using current values)
                    neuron_idx <= neuron_idx + 16'h0001;
                    weight_base_addr <= weight_base_addr + num_inputs;
                    addr_out <= addr_out + 16'h0001;  // Increment for next output

                    // Clear activation flag for next neuron
                    activation_triggered <= 1'b0;
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
