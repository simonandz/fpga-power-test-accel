// Performance Counters Module
// Collects metrics for power/performance analysis

`timescale 1ns / 1ps

module perf_counters #(
    parameter COUNTER_WIDTH = 32
)(
    input  logic clk,
    input  logic rst_n,

    // Control signals from accelerator
    input  logic start,          // Inference start pulse
    input  logic done,           // Inference complete pulse
    input  logic busy,           // Accelerator busy
    input  logic mac_valid,      // MAC operation occurring (for MAC counting)
    input  logic mem_read,       // Memory read occurring
    input  logic mem_write,      // Memory write occurring

    // Configuration
    input  logic clear_counters, // Reset all counters
    input  logic [COUNTER_WIDTH-1:0] target_inferences, // Stop after N inferences (0 = unlimited)

    // Output metrics
    output logic [COUNTER_WIDTH-1:0] total_cycles,       // Total cycles while busy
    output logic [COUNTER_WIDTH-1:0] inference_count,    // Number of completed inferences
    output logic [COUNTER_WIDTH-1:0] current_latency,    // Cycles for current/last inference
    output logic [COUNTER_WIDTH-1:0] min_latency,        // Minimum inference latency
    output logic [COUNTER_WIDTH-1:0] max_latency,        // Maximum inference latency
    output logic [COUNTER_WIDTH-1:0] total_macs,         // Total MAC operations
    output logic [COUNTER_WIDTH-1:0] total_mem_reads,    // Total memory reads
    output logic [COUNTER_WIDTH-1:0] total_mem_writes,   // Total memory writes
    output logic [COUNTER_WIDTH-1:0] idle_cycles,        // Cycles spent idle

    // Status
    output logic target_reached                          // Hit target inference count
);

    logic [COUNTER_WIDTH-1:0] cycle_counter;
    logic was_busy;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n || clear_counters) begin
            total_cycles      <= '0;
            inference_count   <= '0;
            current_latency   <= '0;
            min_latency       <= '1;  // Start at max value
            max_latency       <= '0;
            total_macs        <= '0;
            total_mem_reads   <= '0;
            total_mem_writes  <= '0;
            idle_cycles       <= '0;
            cycle_counter     <= '0;
            was_busy          <= 1'b0;
            target_reached    <= 1'b0;
        end else begin
            was_busy <= busy;

            // Count cycles during inference
            if (busy) begin
                cycle_counter <= cycle_counter + 1;
                total_cycles <= total_cycles + 1;
            end else begin
                idle_cycles <= idle_cycles + 1;
            end

            // Reset cycle counter on start
            if (start && !busy) begin
                cycle_counter <= '0;
            end

            // Capture latency on done
            if (done) begin
                current_latency <= cycle_counter + 1;
                inference_count <= inference_count + 1;

                // Update min/max
                if ((cycle_counter + 1) < min_latency)
                    min_latency <= cycle_counter + 1;
                if ((cycle_counter + 1) > max_latency)
                    max_latency <= cycle_counter + 1;

                // Check target
                if (target_inferences != 0 && (inference_count + 1) >= target_inferences)
                    target_reached <= 1'b1;
            end

            // Count MAC operations
            if (mac_valid)
                total_macs <= total_macs + 1;

            // Count memory accesses
            if (mem_read)
                total_mem_reads <= total_mem_reads + 1;
            if (mem_write)
                total_mem_writes <= total_mem_writes + 1;
        end
    end

endmodule
