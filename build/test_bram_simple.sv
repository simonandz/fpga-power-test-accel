`timescale 1ns/1ps

module test_bram_simple;
    logic clk = 0;
    logic en, we;
    logic [10:0] addr;
    logic [7:0] din, dout;

    always #5 clk = ~clk;

    bram_bank #(.DATA_WIDTH(8), .ADDR_WIDTH(11), .DEPTH(2048)) dut (
        .clk(clk), .en(en), .we(we), .addr(addr), .din(din), .dout(dout)
    );

    initial begin
        $display("Testing BRAM");
        en = 0; we = 0; addr = 0; din = 0;
        #20;

        // Write 0xAA to address 0x10
        @(posedge clk);
        en = 1;
        we = 1;
        addr = 11'h010;
        din = 8'hAA;
        $display("[%0t] Writing 0x%h to addr 0x%h", $time, din, addr);

        @(posedge clk);
        we = 0;
        en = 0;

        #20;

        // Read from address 0x10
        @(posedge clk);
        en = 1;
        we = 0;
        addr = 11'h010;
        $display("[%0t] Reading from addr 0x%h", $time, addr);

        @(posedge clk);
        en = 0;
        #1;
        $display("[%0t] Read data = 0x%h (expected 0xAA)", $time, dout);

        if (dout == 8'hAA)
            $display("PASS!");
        else
            $display("FAIL!");

        $finish;
    end
endmodule
