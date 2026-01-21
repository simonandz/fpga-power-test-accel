// MLP Benchmark Testbench
// Runs N inferences and collects performance metrics
// Generates SAIF-compatible switching activity for power analysis

`timescale 1ns / 1ps

module tb_mlp_benchmark;

    //==========================================================================
    // Parameters
    //==========================================================================
    parameter NUM_INFERENCES = 1000;
    parameter NUM_INPUTS = 8;
    parameter NUM_OUTPUTS = 4;
    parameter CLK_PERIOD_NS = 10;  // 100 MHz
    parameter RANDOM_SEED = 12345;

    //==========================================================================
    // Signals
    //==========================================================================
    logic clk, rst_n;
    logic start, done, busy;
    logic [15:0] num_inputs, num_outputs;
    logic [15:0] input_addr, weight_addr, bias_addr;
    logic [7:0] input_data, weight_data, bias_data;
    logic input_we, weight_we, bias_we;
    logic [7:0] output_data;
    logic output_valid;
    logic [15:0] output_wr_addr;
    logic [7:0]  output_wr_data;
    logic        output_wr_en;

    // Performance counters
    logic clear_counters;
    logic [31:0] target_inferences;
    logic [31:0] total_cycles;
    logic [31:0] inference_count;
    logic [31:0] current_latency;
    logic [31:0] min_latency;
    logic [31:0] max_latency;
    logic [31:0] total_macs;
    logic [31:0] total_mem_reads;
    logic [31:0] total_mem_writes;
    logic [31:0] idle_cycles;
    logic target_reached;

    // Testbench variables
    int unsigned completed_inferences;
    real start_time, end_time, total_time_ns;
    logic [7:0] test_inputs[NUM_INPUTS];
    logic [7:0] test_weights[NUM_OUTPUTS * NUM_INPUTS];
    logic [7:0] test_biases[NUM_OUTPUTS];

    //==========================================================================
    // Clock generation
    //==========================================================================
    initial begin
        clk = 0;
        forever #(CLK_PERIOD_NS/2) clk = ~clk;
    end

    //==========================================================================
    // DUT - MLP Top
    //==========================================================================
    mlp_top dut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .done(done),
        .busy(busy),
        .num_inputs(num_inputs),
        .num_outputs(num_outputs),
        .input_addr(input_addr),
        .input_data(input_data),
        .input_we(input_we),
        .weight_addr(weight_addr),
        .weight_data(weight_data),
        .weight_we(weight_we),
        .bias_addr(bias_addr),
        .bias_data(bias_data),
        .bias_we(bias_we),
        .output_data(output_data),
        .output_valid(output_valid),
        .output_wr_addr(output_wr_addr),
        .output_wr_data(output_wr_data),
        .output_wr_en(output_wr_en)
    );

    //==========================================================================
    // Performance Counters
    //==========================================================================
    perf_counters #(
        .COUNTER_WIDTH(32)
    ) perf (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .done(done),
        .busy(busy),
        .mac_valid(output_valid),  // Approximate: count output valids as MAC batches
        .mem_read(input_we || weight_we || bias_we),
        .mem_write(output_wr_en),
        .clear_counters(clear_counters),
        .target_inferences(target_inferences),
        .total_cycles(total_cycles),
        .inference_count(inference_count),
        .current_latency(current_latency),
        .min_latency(min_latency),
        .max_latency(max_latency),
        .total_macs(total_macs),
        .total_mem_reads(total_mem_reads),
        .total_mem_writes(total_mem_writes),
        .idle_cycles(idle_cycles),
        .target_reached(target_reached)
    );

    //==========================================================================
    // Tasks
    //==========================================================================

    task automatic load_input(input int addr, input logic [7:0] data);
        @(posedge clk);
        input_addr = addr;
        input_data = data;
        input_we = 1'b1;
        @(posedge clk);
        input_we = 1'b0;
    endtask

    task automatic load_weight(input int addr, input logic [7:0] data);
        @(posedge clk);
        weight_addr = addr;
        weight_data = data;
        weight_we = 1'b1;
        @(posedge clk);
        weight_we = 1'b0;
    endtask

    task automatic load_bias(input int addr, input logic [7:0] data);
        @(posedge clk);
        bias_addr = addr;
        bias_data = data;
        bias_we = 1'b1;
        @(posedge clk);
        bias_we = 1'b0;
    endtask

    task automatic run_single_inference();
        @(posedge clk);
        start = 1'b1;
        @(posedge clk);
        start = 1'b0;
        wait(done);
        @(posedge clk);
    endtask

    task automatic load_random_inputs();
        int i;
        for (i = 0; i < NUM_INPUTS; i++) begin
            test_inputs[i] = $urandom_range(0, 255);
            load_input(i, test_inputs[i]);
        end
    endtask

    task automatic load_random_weights();
        int i;
        for (i = 0; i < NUM_OUTPUTS * NUM_INPUTS; i++) begin
            test_weights[i] = $urandom_range(0, 255);
            load_weight(i, test_weights[i]);
        end
    endtask

    task automatic load_random_biases();
        int i;
        for (i = 0; i < NUM_OUTPUTS; i++) begin
            test_biases[i] = $urandom_range(0, 255);
            load_bias(i, test_biases[i]);
        end
    endtask

    //==========================================================================
    // Main Test
    //==========================================================================
    initial begin
        int i;
        real avg_latency, throughput, macs_per_inference;
        real clock_freq_mhz, inferences_per_sec, gops, energy_estimate;

        // Initialize random seed
        $urandom(RANDOM_SEED);

        $display("");
        $display("================================================================");
        $display("MLP Benchmark - %0d Inferences", NUM_INFERENCES);
        $display("Configuration: %0d inputs x %0d outputs", NUM_INPUTS, NUM_OUTPUTS);
        $display("Clock: %0d MHz", 1000/CLK_PERIOD_NS);
        $display("================================================================");
        $display("");

        // Initialize signals
        rst_n = 0;
        start = 0;
        clear_counters = 0;
        target_inferences = NUM_INFERENCES;
        num_inputs = NUM_INPUTS;
        num_outputs = NUM_OUTPUTS;
        input_addr = 0; input_data = 0; input_we = 0;
        weight_addr = 0; weight_data = 0; weight_we = 0;
        bias_addr = 0; bias_data = 0; bias_we = 0;
        completed_inferences = 0;

        // Reset sequence
        repeat(10) @(posedge clk);
        rst_n = 1;
        repeat(5) @(posedge clk);

        // Clear counters
        clear_counters = 1;
        @(posedge clk);
        clear_counters = 0;
        @(posedge clk);

        // Load initial weights and biases (keep same for all inferences)
        $display("[%0t] Loading weights and biases...", $time);
        load_random_weights();
        load_random_biases();

        // Record start time
        start_time = $realtime;
        $display("[%0t] Starting benchmark run...", $time);
        $display("");

        //======================================================================
        // Run N inferences with random inputs
        //======================================================================
        for (i = 0; i < NUM_INFERENCES; i++) begin
            // Load new random inputs for each inference
            load_random_inputs();

            // Run inference
            run_single_inference();
            completed_inferences++;

            // Progress update every 100 inferences
            if ((i+1) % 100 == 0) begin
                $display("[%0t] Completed %0d / %0d inferences (latency: %0d cycles)",
                         $time, i+1, NUM_INFERENCES, current_latency);
            end
        end

        // Record end time
        end_time = $realtime;
        total_time_ns = end_time - start_time;

        //======================================================================
        // Calculate and display metrics
        //======================================================================
        $display("");
        $display("================================================================");
        $display("BENCHMARK RESULTS");
        $display("================================================================");
        $display("");

        // Basic counts
        $display("--- Raw Counts ---");
        $display("Total inferences:     %0d", inference_count);
        $display("Total busy cycles:    %0d", total_cycles);
        $display("Total idle cycles:    %0d", idle_cycles);
        $display("Total memory reads:   %0d", total_mem_reads);
        $display("Total memory writes:  %0d", total_mem_writes);
        $display("");

        // Latency metrics
        $display("--- Latency (cycles) ---");
        $display("Last inference:       %0d", current_latency);
        $display("Minimum:              %0d", min_latency);
        $display("Maximum:              %0d", max_latency);
        avg_latency = real'(total_cycles) / real'(inference_count);
        $display("Average:              %.2f", avg_latency);
        $display("");

        // Throughput metrics
        clock_freq_mhz = 1000.0 / CLK_PERIOD_NS;
        inferences_per_sec = (clock_freq_mhz * 1e6) / avg_latency;
        $display("--- Throughput ---");
        $display("Clock frequency:      %.0f MHz", clock_freq_mhz);
        $display("Avg cycles/inference: %.2f", avg_latency);
        $display("Latency @ 100MHz:     %.2f us", avg_latency * 0.01);
        $display("Inferences/second:    %.0f", inferences_per_sec);
        $display("");

        // Compute metrics
        macs_per_inference = NUM_INPUTS * NUM_OUTPUTS;  // For single layer
        gops = (macs_per_inference * 2 * inferences_per_sec) / 1e9;  // MAC = 2 ops
        $display("--- Compute ---");
        $display("MACs per inference:   %.0f", macs_per_inference);
        $display("GOPS:                 %.4f", gops);
        $display("");

        // Memory bandwidth
        $display("--- Memory Bandwidth ---");
        $display("Bytes read/inference: %0d", NUM_INPUTS + NUM_OUTPUTS*NUM_INPUTS + NUM_OUTPUTS);
        $display("Bytes written/infer:  %0d", NUM_OUTPUTS);
        $display("Read BW @ 100MHz:     %.2f MB/s",
                 (NUM_INPUTS + NUM_OUTPUTS*NUM_INPUTS + NUM_OUTPUTS) * inferences_per_sec / 1e6);
        $display("");

        // Simulation time
        $display("--- Simulation ---");
        $display("Simulated time:       %.2f us", total_time_ns / 1000);
        $display("");

        // CSV output for easy parsing
        $display("================================================================");
        $display("CSV OUTPUT (copy for spreadsheet):");
        $display("================================================================");
        $display("metric,value");
        $display("inferences,%0d", inference_count);
        $display("total_cycles,%0d", total_cycles);
        $display("avg_latency_cycles,%.2f", avg_latency);
        $display("min_latency_cycles,%0d", min_latency);
        $display("max_latency_cycles,%0d", max_latency);
        $display("inferences_per_sec,%.0f", inferences_per_sec);
        $display("macs_per_inference,%.0f", macs_per_inference);
        $display("gops,%.4f", gops);
        $display("================================================================");
        $display("");

        repeat(10) @(posedge clk);
        $finish;
    end

    //==========================================================================
    // Timeout
    //==========================================================================
    initial begin
        #100000000;  // 100ms timeout
        $display("");
        $display("ERROR: Simulation timeout!");
        $display("");
        $finish;
    end

    //==========================================================================
    // VCD dump for SAIF generation
    //==========================================================================
    initial begin
        $dumpfile("mlp_benchmark.vcd");
        $dumpvars(0, tb_mlp_benchmark);
    end

endmodule
