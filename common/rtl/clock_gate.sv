`timescale 1ns / 1ps

//==============================================================================
// Module: clock_gate
// Description: Safe clock gating cell for power optimization
//              Gates clock when enable is low to save dynamic power
//              Uses latch-based implementation to avoid glitches
//==============================================================================

module clock_gate (
    input  logic clk,
    input  logic enable,
    input  logic test_enable,  // For scan testing
    output logic gated_clk
);

    logic enable_latched;

    // Latch enable on negative edge to avoid glitches
    always_latch begin
        if (!clk)
            enable_latched <= enable | test_enable;
    end

    // Gate the clock
    assign gated_clk = clk & enable_latched;

endmodule
