`timescale 1ns/1ps

module TESTBED;

    logic          clk;
    logic          rst_n;
    logic          in_valid;
    logic [1087:0] msg_in;
    logic          in_last;
    logic [7:0]    msg_length;
    logic          in_ready;
    logic [31:0]   out_data;
    logic          out_valid;
    logic          hash_done;

    sha3_ultra_low_power_top u_sha3_top (
        .clk        (clk),
        .rst_n      (rst_n),
        .in_valid   (in_valid),
        .msg_in     (msg_in),
        .msg_length (msg_length),
        .in_last    (in_last),
        .in_ready   (in_ready),
        .out_data   (out_data),
        .out_valid  (out_valid),
        .hash_done  (hash_done)
    );

    PATTERN u_PATTERN (
        .clk        (clk),
        .rst_n      (rst_n),
        .in_valid   (in_valid),
        .msg_in     (msg_in),
        .msg_length (msg_length),
        .in_last    (in_last),
        .in_ready   (in_ready),
        .out_data   (out_data),
        .out_valid  (out_valid),
        .hash_done  (hash_done)
    );

    initial begin
        $dumpfile("sha3_sim.vcd");
        $dumpvars(0, TESTBED);
    end

endmodule