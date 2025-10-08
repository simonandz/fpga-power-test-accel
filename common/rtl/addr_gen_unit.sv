`timescale 1ns / 1ps

//==============================================================================
// Module: addr_gen_unit
// Description: Configurable address generation unit supporting multiple access patterns
//              - Sequential: Linear addressing for MLP
//              - Sliding 2D: 2D convolution window for CNN
//              - Circular: Circular buffer for RNN sequences
//==============================================================================

import accel_pkg::*;

module addr_gen_unit (
    input  logic                        clk,
    input  logic                        rst_n,

    // Control interface
    input  logic                        start,
    input  access_pattern_e             pattern,
    input  logic [ADDR_WIDTH-1:0]       base_addr,
    input  logic [15:0]                 length,        // Transfer length
    output logic                        done,

    // Configuration (pattern-specific)
    input  logic [7:0]                  stride,        // For 2D sliding window
    input  logic [7:0]                  width,         // Image width for CNN
    input  logic [7:0]                  height,        // Image height for CNN
    input  logic [7:0]                  kernel_size,   // Kernel size (3 for 3x3)

    // Address output
    output logic [ADDR_WIDTH-1:0]       addr,
    output logic                        addr_valid,
    input  logic                        addr_ready
);

    //--------------------------------------------------------------------------
    // Internal Registers
    //--------------------------------------------------------------------------
    logic [ADDR_WIDTH-1:0]  current_addr;
    logic [15:0]            counter;
    logic                   active;

    // 2D sliding window state
    logic [7:0]             row_idx;
    logic [7:0]             col_idx;
    logic [7:0]             kernel_row;
    logic [7:0]             kernel_col;

    // Circular buffer state
    logic [ADDR_WIDTH-1:0]  buffer_size;
    logic [ADDR_WIDTH-1:0]  wrap_addr;

    //--------------------------------------------------------------------------
    // Main FSM
    //--------------------------------------------------------------------------
    typedef enum logic [1:0] {
        AGU_IDLE,
        AGU_ACTIVE,
        AGU_DONE
    } agu_state_e;

    agu_state_e state_q, state_d;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            state_q <= AGU_IDLE;
        else
            state_q <= state_d;
    end

    always_comb begin
        state_d = state_q;
        case (state_q)
            AGU_IDLE: begin
                if (start)
                    state_d = AGU_ACTIVE;
            end

            AGU_ACTIVE: begin
                if (counter >= length && addr_ready)
                    state_d = AGU_DONE;
            end

            AGU_DONE: begin
                if (!start)
                    state_d = AGU_IDLE;
            end
        endcase
    end

    assign active = (state_q == AGU_ACTIVE);
    assign done   = (state_q == AGU_DONE);

    //--------------------------------------------------------------------------
    // Address Generation Logic
    //--------------------------------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_addr <= '0;
            counter      <= '0;
            row_idx      <= '0;
            col_idx      <= '0;
            kernel_row   <= '0;
            kernel_col   <= '0;
            buffer_size  <= '0;
            wrap_addr    <= '0;
        end else begin
            case (state_q)
                AGU_IDLE: begin
                    if (start) begin
                        current_addr <= base_addr;
                        counter      <= '0;
                        row_idx      <= '0;
                        col_idx      <= '0;
                        kernel_row   <= '0;
                        kernel_col   <= '0;
                        buffer_size  <= length;
                        wrap_addr    <= base_addr + length;
                    end
                end

                AGU_ACTIVE: begin
                    if (addr_ready && counter < length) begin
                        counter <= counter + 1;

                        case (pattern)
                            //--------------------------------------------------
                            // Sequential Access (MLP)
                            //--------------------------------------------------
                            ACCESS_SEQUENTIAL: begin
                                current_addr <= current_addr + 1;
                            end

                            //--------------------------------------------------
                            // 2D Sliding Window (CNN)
                            //--------------------------------------------------
                            ACCESS_SLIDING_2D: begin
                                // Generate addresses for kernel window
                                // Address = base + (row_idx + kernel_row) * width + (col_idx + kernel_col)

                                // Increment kernel position
                                if (kernel_col < kernel_size - 1) begin
                                    kernel_col <= kernel_col + 1;
                                end else begin
                                    kernel_col <= '0;
                                    if (kernel_row < kernel_size - 1) begin
                                        kernel_row <= kernel_row + 1;
                                    end else begin
                                        kernel_row <= '0;
                                        // Move to next output position
                                        if (col_idx + stride < width) begin
                                            col_idx <= col_idx + stride;
                                        end else begin
                                            col_idx <= '0;
                                            row_idx <= row_idx + stride;
                                        end
                                    end
                                end

                                // Calculate address
                                current_addr <= base_addr +
                                              (row_idx + kernel_row) * width +
                                              (col_idx + kernel_col);
                            end

                            //--------------------------------------------------
                            // Circular Buffer (RNN)
                            //--------------------------------------------------
                            ACCESS_CIRCULAR: begin
                                current_addr <= current_addr + 1;
                                // Wrap around at buffer boundary
                                if (current_addr + 1 >= wrap_addr) begin
                                    current_addr <= base_addr;
                                end
                            end

                            default: begin
                                current_addr <= current_addr + 1;
                            end
                        endcase
                    end
                end

                AGU_DONE: begin
                    // Hold values
                end
            endcase
        end
    end

    //--------------------------------------------------------------------------
    // Output Assignment
    //--------------------------------------------------------------------------
    assign addr       = current_addr;
    assign addr_valid = active && (counter < length);

    //--------------------------------------------------------------------------
    // Assertions
    //--------------------------------------------------------------------------
    `ifdef SIMULATION
    always_ff @(posedge clk) begin
        if (rst_n && active) begin
            // Check for valid configuration
            case (pattern)
                ACCESS_SLIDING_2D: begin
                    assert (kernel_size > 0 && kernel_size <= width && kernel_size <= height)
                        else $error("Invalid kernel size configuration");
                    assert (stride > 0)
                        else $error("Stride must be > 0");
                end

                ACCESS_CIRCULAR: begin
                    assert (length > 0)
                        else $error("Buffer size must be > 0");
                end
            endcase
        end
    end
    `endif

endmodule
