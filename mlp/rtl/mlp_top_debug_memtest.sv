// MLP Top with Debug Cores (VIO + ILA) and Memory Initialization
// Complete self-contained test module - no external dependencies!
//
// Features:
// - VIO: Control inputs (start, num_inputs, num_outputs, mem_init_trigger)
// - ILA: Capture outputs (done, busy, output_data, output_valid, state signals)
// - Memory Init: FSM to load test patterns into BRAMs at startup or on demand
//
// Test Data:
// - Inputs: [1, 2, 3, 4, 5, 6, 7, 8] (8 values)
// - Weights: All 1s (8x4 = 32 weights for 4 output neurons)
// - Biases: All 0s (4 biases)
// - Expected output per neuron: 1+2+3+4+5+6+7+8 = 36 (0x24)

`timescale 1ns / 1ps

module mlp_top_debug_memtest (
    input  logic clk,
    input  logic rst_n
);

    //==========================================================================
    // Parameters
    //==========================================================================
    localparam NUM_TEST_INPUTS  = 8;
    localparam NUM_TEST_OUTPUTS = 4;
    localparam NUM_TEST_WEIGHTS = NUM_TEST_INPUTS * NUM_TEST_OUTPUTS;  // 32

    //==========================================================================
    // VIO/ILA Signals
    //==========================================================================

    // VIO-controlled signals
    logic         vio_start;
    logic [15:0]  vio_num_inputs;
    logic [15:0]  vio_num_outputs;
    logic         vio_mem_init;       // Trigger memory initialization

    // MLP status signals (monitored by ILA)
    logic         done;
    logic         busy;
    logic [7:0]   output_data;
    logic         output_valid;

    // Memory init state (monitored by ILA)
    logic [2:0]   mem_init_state;
    logic         mem_init_done;

    //==========================================================================
    // Memory Interface Signals
    //==========================================================================

    logic [15:0] input_addr;
    logic [7:0]  input_data;
    logic        input_we;
    logic [15:0] weight_addr;
    logic [7:0]  weight_data;
    logic        weight_we;
    logic [15:0] bias_addr;
    logic [7:0]  bias_data;
    logic        bias_we;

    // Output BRAM write signals (for ILA observation)
    logic [15:0] output_wr_addr;
    logic [7:0]  output_wr_data;
    logic        output_wr_en;

    //==========================================================================
    // Memory Initialization FSM
    //==========================================================================

    typedef enum logic [2:0] {
        MEM_IDLE        = 3'd0,
        MEM_INIT_INPUT  = 3'd1,
        MEM_INIT_WEIGHT = 3'd2,
        MEM_INIT_BIAS   = 3'd3,
        MEM_DONE        = 3'd4
    } mem_state_t;

    mem_state_t mem_state, mem_state_next;
    logic [15:0] mem_addr_cnt;
    logic        mem_init_start;
    logic        mem_init_start_r;  // Edge detection

    // Test pattern ROM - embedded test data
    // Inputs: [1, 2, 3, 4, 5, 6, 7, 8]
    logic [7:0] test_inputs [0:7];
    assign test_inputs[0] = 8'h01;
    assign test_inputs[1] = 8'h02;
    assign test_inputs[2] = 8'h03;
    assign test_inputs[3] = 8'h04;
    assign test_inputs[4] = 8'h05;
    assign test_inputs[5] = 8'h06;
    assign test_inputs[6] = 8'h07;
    assign test_inputs[7] = 8'h08;

    // Weights: All 1s (32 values for 8 inputs x 4 outputs)
    logic [7:0] test_weights [0:31];
    generate
        for (genvar i = 0; i < 32; i++) begin : gen_weights
            assign test_weights[i] = 8'h01;
        end
    endgenerate

    // Biases: All 0s (4 values)
    logic [7:0] test_biases [0:3];
    assign test_biases[0] = 8'h00;
    assign test_biases[1] = 8'h00;
    assign test_biases[2] = 8'h00;
    assign test_biases[3] = 8'h00;

    // Edge detection for mem_init trigger
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mem_init_start_r <= 1'b0;
        end else begin
            mem_init_start_r <= vio_mem_init;
        end
    end
    assign mem_init_start = vio_mem_init && !mem_init_start_r;

    // Memory init FSM - state register
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mem_state <= MEM_INIT_INPUT;  // Auto-init on reset
            mem_addr_cnt <= 16'd0;
        end else begin
            mem_state <= mem_state_next;

            case (mem_state)
                MEM_IDLE: begin
                    if (mem_init_start) begin
                        mem_addr_cnt <= 16'd0;
                    end
                end
                MEM_INIT_INPUT: begin
                    if (mem_addr_cnt < NUM_TEST_INPUTS - 1) begin
                        mem_addr_cnt <= mem_addr_cnt + 1;
                    end else begin
                        mem_addr_cnt <= 16'd0;
                    end
                end
                MEM_INIT_WEIGHT: begin
                    if (mem_addr_cnt < NUM_TEST_WEIGHTS - 1) begin
                        mem_addr_cnt <= mem_addr_cnt + 1;
                    end else begin
                        mem_addr_cnt <= 16'd0;
                    end
                end
                MEM_INIT_BIAS: begin
                    if (mem_addr_cnt < NUM_TEST_OUTPUTS - 1) begin
                        mem_addr_cnt <= mem_addr_cnt + 1;
                    end else begin
                        mem_addr_cnt <= 16'd0;
                    end
                end
                default: begin
                    mem_addr_cnt <= 16'd0;
                end
            endcase
        end
    end

    // Memory init FSM - next state logic
    always_comb begin
        mem_state_next = mem_state;

        case (mem_state)
            MEM_IDLE: begin
                if (mem_init_start) begin
                    mem_state_next = MEM_INIT_INPUT;
                end
            end
            MEM_INIT_INPUT: begin
                if (mem_addr_cnt >= NUM_TEST_INPUTS - 1) begin
                    mem_state_next = MEM_INIT_WEIGHT;
                end
            end
            MEM_INIT_WEIGHT: begin
                if (mem_addr_cnt >= NUM_TEST_WEIGHTS - 1) begin
                    mem_state_next = MEM_INIT_BIAS;
                end
            end
            MEM_INIT_BIAS: begin
                if (mem_addr_cnt >= NUM_TEST_OUTPUTS - 1) begin
                    mem_state_next = MEM_DONE;
                end
            end
            MEM_DONE: begin
                mem_state_next = MEM_IDLE;
            end
            default: begin
                mem_state_next = MEM_IDLE;
            end
        endcase
    end

    // Memory init FSM - output logic
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
        mem_init_done = 1'b0;
        mem_init_state = mem_state;

        case (mem_state)
            MEM_INIT_INPUT: begin
                input_addr = mem_addr_cnt;
                input_data = test_inputs[mem_addr_cnt[2:0]];
                input_we   = 1'b1;
            end
            MEM_INIT_WEIGHT: begin
                weight_addr = mem_addr_cnt;
                weight_data = test_weights[mem_addr_cnt[4:0]];
                weight_we   = 1'b1;
            end
            MEM_INIT_BIAS: begin
                bias_addr = mem_addr_cnt;
                bias_data = test_biases[mem_addr_cnt[1:0]];
                bias_we   = 1'b1;
            end
            MEM_DONE: begin
                mem_init_done = 1'b1;
            end
            MEM_IDLE: begin
                mem_init_done = 1'b1;  // Ready to run
            end
            default: ;
        endcase
    end

    //==========================================================================
    // Start Signal Logic
    //==========================================================================

    // Synchronize VIO start signal (JTAG clock domain crossing)
    logic vio_start_sync1, vio_start_sync2;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            vio_start_sync1 <= 1'b0;
            vio_start_sync2 <= 1'b0;
        end else begin
            vio_start_sync1 <= vio_start;
            vio_start_sync2 <= vio_start_sync1;
        end
    end

    // Latch to prevent re-triggering while VIO start is held high
    // Set when we trigger, cleared only when VIO start goes back to 0
    logic start_triggered;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            start_triggered <= 1'b0;
        end else begin
            if (!vio_start_sync2) begin
                // Clear latch when start goes low - ready for next trigger
                start_triggered <= 1'b0;
            end else if (start_masked) begin
                // Set latch when we actually trigger
                start_triggered <= 1'b1;
            end
        end
    end

    // Only allow start when:
    // - VIO start is high (synchronized)
    // - Memory init is complete
    // - Not already busy
    // - Haven't already triggered on this button press
    logic start_masked;
    assign start_masked = vio_start_sync2 && mem_init_done && !busy && !start_triggered;

    //==========================================================================
    // VIO Core
    //==========================================================================

    vio_0 vio_inst (
        .clk(clk),

        // Outputs (VIO controls these)
        .probe_out0(vio_start),           // 1-bit: start signal
        .probe_out1(vio_num_inputs),      // 16-bit: number of inputs
        .probe_out2(vio_num_outputs),     // 16-bit: number of outputs
        .probe_out3(vio_mem_init)         // 1-bit: trigger memory init
    );

    //==========================================================================
    // ILA Core
    //==========================================================================

    ila_0 ila_inst (
        .clk(clk),

        // Probes (ILA captures these)
        .probe0(done),                    // 1-bit: computation done
        .probe1(busy),                    // 1-bit: computation busy
        .probe2(output_data),             // 8-bit: output data
        .probe3(output_valid),            // 1-bit: output valid
        .probe4(start_masked),            // 1-bit: actual start signal
        .probe5(mem_init_state),          // 3-bit: memory init state
        .probe6(mem_init_done),           // 1-bit: memory init complete
        .probe7(output_wr_en),            // 1-bit: BRAM write enable
        .probe8(output_wr_addr),          // 16-bit: BRAM write address
        .probe9(output_wr_data)           // 8-bit: BRAM write data
    );

    //==========================================================================
    // MLP Accelerator Instance
    //==========================================================================

    mlp_top mlp_inst (
        .clk(clk),
        .rst_n(rst_n),

        // Control
        .start(start_masked),
        .done(done),
        .busy(busy),

        // Configuration - use VIO values or defaults
        .num_inputs(vio_num_inputs == 16'd0 ? NUM_TEST_INPUTS : vio_num_inputs),
        .num_outputs(vio_num_outputs == 16'd0 ? NUM_TEST_OUTPUTS : vio_num_outputs),

        // Memory interfaces (active during init, idle otherwise)
        .input_addr(input_addr),
        .input_data(input_data),
        .input_we(input_we),
        .weight_addr(weight_addr),
        .weight_data(weight_data),
        .weight_we(weight_we),
        .bias_addr(bias_addr),
        .bias_data(bias_data),
        .bias_we(bias_we),

        // Output
        .output_data(output_data),
        .output_valid(output_valid),

        // Debug: Output BRAM write signals
        .output_wr_addr(output_wr_addr),
        .output_wr_data(output_wr_data),
        .output_wr_en(output_wr_en)
    );

endmodule
