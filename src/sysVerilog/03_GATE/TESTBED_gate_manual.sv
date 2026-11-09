`timescale 1ns/1ps
module TESTBED;
    wire          clk, rst_n, in_valid, in_last, in_ready, out_valid, hash_done;
    wire [1087:0] msg_in;
    wire [7:0]    msg_length;
    wire [31:0]   out_data;

    // The original parity synthesis (FT_ENABLE=1) names its netlist top this way.
    sha3_ultra_low_power_top_FT_ENABLE1 dut (
        .clk(clk), .rst_n(rst_n), .in_valid(in_valid),
        .msg_in(msg_in), .msg_length(msg_length), .in_last(in_last),
        .in_ready(in_ready), .out_data(out_data),
        .out_valid(out_valid), .hash_done(hash_done),
        .ft_inject_valid(1'b0), .ft_inject_lane(5'd0),
        .ft_inject_mask(64'd0), .ft_c_inject_valid(1'b0),
        .ft_c_inject_col(3'd0), .ft_c_inject_mask(64'd0),
        .ft_d_inject_valid(1'b0), .ft_d_inject_col(3'd0),
        .ft_d_inject_mask(64'd0)
    );

    PATTERN u_PATTERN (
        .clk(clk), .rst_n(rst_n), .in_valid(in_valid),
        .msg_in(msg_in), .msg_length(msg_length), .in_last(in_last),
        .in_ready(in_ready), .out_data(out_data),
        .out_valid(out_valid), .hash_done(hash_done)
    );

    initial begin #10000000; $fatal(1, "[FAIL] gate watchdog"); end
endmodule
