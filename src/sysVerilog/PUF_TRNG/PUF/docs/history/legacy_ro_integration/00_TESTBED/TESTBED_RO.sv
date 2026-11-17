`timescale 1ns/1ps
module TESTBED_RO;
    logic clk,rst_n,enable_a,enable_b,req;
    logic a,b,ready,valid;logic[7:0] ca,cb;
    ro_wave_model #(.HALF_PERIOD_PS(2000)) ra(.enable(enable_a),.ro(a));
    ro_wave_model #(.HALF_PERIOD_PS(2500)) rb(.enable(enable_b),.ro(b));
    ro_frequency_counter #(.COUNT_W(8)) dut(.clk,.rst_n,.ro_a(a),.ro_b(b),.req,.ready,.valid,.count_a(ca),.count_b(cb));
    PATTERN_RO u_PATTERN(.clk,.rst_n,.enable_a,.enable_b,.req,.ready,.valid,.ca,.cb);

    initial begin
`ifndef NO_DUMP
        $dumpfile("ro_sim.vcd");
        $dumpvars(0, TESTBED_RO);
`endif
    end
endmodule
