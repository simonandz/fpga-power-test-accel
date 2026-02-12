// CNN Benchmark Testbench
// Runs N inferences and collects performance metrics
// Generates VCD switching activity for power analysis
//
// Comparable to MLP benchmark for power/performance comparison

`timescale 1ns / 1ps

module tb_cnn_benchmark;

    //==========================================================================
    // Parameters
    //==========================================================================
    parameter NUM_INFERENCES = 1000;
    parameter IMG_W          = 16;
    parameter IMG_H          = 16;
    parameter IMG_SIZE       = IMG_W * IMG_H;    // 256
    parameter KER_SIZE       = 3;
    parameter KER_DEPTH      = KER_SIZE * KER_SIZE;  // 9
    parameter STRIDE         = 1;
    parameter PAD            = 1;
    parameter POOL_EN        = 1;
    parameter CLK_PERIOD_NS  = 10;  // 100 MHz
    parameter MACS_PER_INFERENCE = KER_DEPTH * IMG_W * IMG_H;  // 9 * 16 * 16 = 2304

    //==========================================================================
    // Signals
    //==========================================================================
    logic        clk, rst_n;
    logic        start, done, busy;
    logic        pool_enable;

    // Host load interfaces
    logic [15:0] ifmap_addr;
    logic [7:0]  ifmap_data;
    logic        ifmap_we;
    logic [3:0]  kernel_addr;
    logic [7:0]  kernel_data;
    logic        kernel_we;
    logic [7:0]  bias_data;
    logic        bias_we;

    // Output interface
    logic [7:0]  output_data;
    logic        output_valid;
    logic [15:0] output_wr_addr;
    logic [7:0]  output_wr_data;
    logic        output_wr_en;

    // Performance counters
    logic        clear_counters;
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
    logic        target_reached;
    logic [2:0]  stage;
    logic [31:0] init_cycles;
    logic [31:0] load_cycles;
    logic [31:0] compute_cycles;
    logic [31:0] activate_cycles;
    logic [31:0] store_cycles;

    // Testbench variables
    int unsigned completed_inferences;
    real start_time, end_time, total_time_ns;

    //==========================================================================
    // Clock generation - 100 MHz (10ns period)
    //==========================================================================
    initial begin
        clk = 0;
        forever #(CLK_PERIOD_NS/2) clk = ~clk;
    end

    //==========================================================================
    // DUT - CNN Top
    //==========================================================================
    cnn_top #(
        .IMG_W(IMG_W),
        .IMG_H(IMG_H),
        .KER_SIZE(KER_SIZE),
        .STRIDE(STRIDE),
        .PAD(PAD),
        .POOL_EN(POOL_EN)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .done(done),
        .busy(busy),
        .pool_enable(pool_enable),
        .ifmap_addr(ifmap_addr),
        .ifmap_data(ifmap_data),
        .ifmap_we(ifmap_we),
        .kernel_addr(kernel_addr),
        .kernel_data(kernel_data),
        .kernel_we(kernel_we),
        .bias_data(bias_data),
        .bias_we(bias_we),
        .output_data(output_data),
        .output_valid(output_valid),
        .output_wr_addr(output_wr_addr),
        .output_wr_data(output_wr_data),
        .output_wr_en(output_wr_en),
        .stage(stage)
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
        .mem_read(ifmap_we || kernel_we || bias_we),
        .mem_write(output_wr_en),
        .stage(stage),
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
        .init_cycles(init_cycles),
        .load_cycles(load_cycles),
        .compute_cycles(compute_cycles),
        .activate_cycles(activate_cycles),
        .store_cycles(store_cycles),
        .target_reached(target_reached)
    );

    //==========================================================================
    // Tasks
    //==========================================================================

    task automatic load_ifmap_pixel(input int addr, input logic [7:0] data);
        @(posedge clk);
        ifmap_addr = addr[15:0];
        ifmap_data = data;
        ifmap_we   = 1'b1;
        @(posedge clk);
        ifmap_we = 1'b0;
    endtask

    task automatic load_kernel_weight(input int addr, input logic [7:0] data);
        @(posedge clk);
        kernel_addr = addr[3:0];
        kernel_data = data;
        kernel_we   = 1'b1;
        @(posedge clk);
        kernel_we = 1'b0;
    endtask

    task automatic load_bias_val(input logic [7:0] data);
        @(posedge clk);
        bias_data = data;
        bias_we   = 1'b1;
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

    task automatic load_random_ifmap();
        int i;
        for (i = 0; i < IMG_SIZE; i++) begin
            load_ifmap_pixel(i, $random & 8'hFF);
        end
    endtask

    task automatic load_random_kernel();
        int i;
        for (i = 0; i < KER_DEPTH; i++) begin
            load_kernel_weight(i, $random & 8'hFF);
        end
    endtask

    task automatic load_random_bias();
        load_bias_val($random & 8'hFF);
    endtask

    //==========================================================================
    // Main Test
    //==========================================================================
    initial begin
        int i;
        real avg_latency, throughput, macs_per_inference;
        real clock_freq_mhz, inferences_per_sec, gops;

        $display("");
        $display("================================================================");
        $display("CNN Benchmark - %0d Inferences", NUM_INFERENCES);
        $display("Configuration: %0dx%0d input, %0dx%0d kernel, stride=%0d, pad=%0d",
                 IMG_H, IMG_W, KER_SIZE, KER_SIZE, STRIDE, PAD);
        $display("MACs per inference: %0d (= %0d * %0d * %0d)",
                 MACS_PER_INFERENCE, KER_DEPTH, IMG_H, IMG_W);
        $display("Clock: %0d MHz", 1000/CLK_PERIOD_NS);
        $display("================================================================");
        $display("");

        // Initialize signals
        rst_n = 0;
        start = 0;
        clear_counters = 0;
        target_inferences = NUM_INFERENCES;
        pool_enable = 0;  // No pooling for benchmark (measure conv only)
        ifmap_addr = 0; ifmap_data = 0; ifmap_we = 0;
        kernel_addr = 0; kernel_data = 0; kernel_we = 0;
        bias_data = 0; bias_we = 0;
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

        // Load initial kernel and bias (keep same for all inferences)
        $display("[%0t] Loading kernel weights and bias...", $time);
        load_random_kernel();
        load_random_bias();

        // Record start time
        start_time = $realtime;
        $display("[%0t] Starting benchmark run...", $time);
        $display("");

        //======================================================================
        // Run N inferences with random inputs
        //======================================================================
        for (i = 0; i < NUM_INFERENCES; i++) begin
            // Load new random input feature map for each inference
            load_random_ifmap();

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

        // Stage utilization breakdown
        $display("--- Stage Utilization ---");
        $display("Init cycles:          %0d (%.1f%%)", init_cycles, 100.0 * real'(init_cycles) / real'(total_cycles));
        $display("Load cycles:          %0d (%.1f%%)", load_cycles, 100.0 * real'(load_cycles) / real'(total_cycles));
        $display("Compute cycles:       %0d (%.1f%%)", compute_cycles, 100.0 * real'(compute_cycles) / real'(total_cycles));
        $display("Activate cycles:      %0d (%.1f%%)", activate_cycles, 100.0 * real'(activate_cycles) / real'(total_cycles));
        $display("Store cycles:         %0d (%.1f%%)", store_cycles, 100.0 * real'(store_cycles) / real'(total_cycles));
        $display("Compute utilization:  %.1f%%", 100.0 * real'(compute_cycles) / real'(total_cycles));
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
        macs_per_inference = MACS_PER_INFERENCE;
        gops = (macs_per_inference * 2 * inferences_per_sec) / 1e9;  // MAC = 2 ops
        $display("--- Compute ---");
        $display("MACs per inference:   %.0f", macs_per_inference);
        $display("GOPS:                 %.4f", gops);
        $display("");

        // Memory bandwidth
        $display("--- Memory Bandwidth ---");
        $display("Bytes read/inference: %0d (ifmap=%0d, kernel=%0d, bias=1)",
                 IMG_SIZE + KER_DEPTH + 1, IMG_SIZE, KER_DEPTH);
        $display("Bytes written/infer:  %0d", IMG_SIZE);  // Full output map
        $display("Read BW @ 100MHz:     %.2f MB/s",
                 (IMG_SIZE + KER_DEPTH + 1) * inferences_per_sec / 1e6);
        $display("");

        // Simulation time
        $display("--- Simulation ---");
        $display("Simulated time:       %.2f us", total_time_ns / 1000);
        $display("");

        // CSV output for easy parsing (comparable to MLP benchmark)
        $display("================================================================");
        $display("CSV OUTPUT (copy for spreadsheet):");
        $display("================================================================");
        $display("metric,value");
        $display("accelerator,CNN");
        $display("img_size,%0dx%0d", IMG_H, IMG_W);
        $display("kernel_size,%0dx%0d", KER_SIZE, KER_SIZE);
        $display("inferences,%0d", inference_count);
        $display("total_cycles,%0d", total_cycles);
        $display("avg_latency_cycles,%.2f", avg_latency);
        $display("min_latency_cycles,%0d", min_latency);
        $display("max_latency_cycles,%0d", max_latency);
        $display("inferences_per_sec,%.0f", inferences_per_sec);
        $display("macs_per_inference,%.0f", macs_per_inference);
        $display("gops,%.4f", gops);
        $display("init_cycles,%0d", init_cycles);
        $display("load_cycles,%0d", load_cycles);
        $display("compute_cycles,%0d", compute_cycles);
        $display("activate_cycles,%0d", activate_cycles);
        $display("store_cycles,%0d", store_cycles);
        $display("compute_utilization_pct,%.1f", 100.0 * real'(compute_cycles) / real'(total_cycles));
        $display("================================================================");
        $display("");

        repeat(10) @(posedge clk);
        $finish;
    end

    //==========================================================================
    // Timeout
    //==========================================================================
    initial begin
        #500000000;  // 500ms timeout (CNN is slower than MLP per inference)
        $display("");
        $display("ERROR: Simulation timeout!");
        $display("");
        $finish;
    end

    //==========================================================================
    // VCD dump for SAIF generation
    //==========================================================================
    initial begin
        $dumpfile("cnn_benchmark.vcd");
        $dumpvars(0, dut);
    end

endmodule
