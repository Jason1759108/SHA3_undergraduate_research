`timescale 1ns/1ps

module TESTBED;
`ifdef FT_PATTERN_1600
    initial $fatal(1, "SECDED overlay requires baseline commit 0798e0b; incompatible with parity RTL");
`endif

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

    logic          ft_inject_valid;
    logic [4:0]    ft_inject_lane;
    logic [63:0]   ft_inject_mask;
    logic          ft_c_inject_valid;
    logic [2:0]    ft_c_inject_col;
    logic [63:0]   ft_c_inject_mask;
    logic          ft_d_inject_valid;
    logic [2:0]    ft_d_inject_col;
    logic [63:0]   ft_d_inject_mask;

`ifdef FT_DISABLED
    localparam bit FT_ENABLE = 1'b0;
`else
    localparam bit FT_ENABLE = 1'b1;
`endif
    sha3_ultra_low_power_top #(.FT_ENABLE(FT_ENABLE)) u_sha3_top (
        .clk              (clk),
        .rst_n            (rst_n),
        .in_valid         (in_valid),
        .msg_in           (msg_in),
        .msg_length       (msg_length),
        .in_last          (in_last),
        .in_ready         (in_ready),
        .out_data         (out_data),
        .out_valid        (out_valid),
        .hash_done        (hash_done),
        .ft_inject_valid  (ft_inject_valid),
        .ft_inject_lane   (ft_inject_lane),
        .ft_inject_mask   (ft_inject_mask),
        .ft_c_inject_valid(ft_c_inject_valid),
        .ft_c_inject_col(ft_c_inject_col),
        .ft_c_inject_mask(ft_c_inject_mask),
        .ft_d_inject_valid(ft_d_inject_valid),
        .ft_d_inject_col  (ft_d_inject_col),
        .ft_d_inject_mask (ft_d_inject_mask)
    );

`ifdef FT_PATTERN
    PATTERN_FT u_PATTERN (
        .clk              (clk),
        .rst_n            (rst_n),
        .in_valid         (in_valid),
        .msg_in           (msg_in),
        .msg_length       (msg_length),
        .in_last          (in_last),
        .in_ready         (in_ready),
        .out_data         (out_data),
        .out_valid        (out_valid),
        .hash_done        (hash_done),
        .ft_inject_valid  (ft_inject_valid),
        .ft_inject_lane   (ft_inject_lane),
        .ft_inject_mask   (ft_inject_mask),
        .ft_c_inject_valid(ft_c_inject_valid),
        .ft_c_inject_col(ft_c_inject_col),
        .ft_c_inject_mask(ft_c_inject_mask),
        .ft_d_inject_valid(ft_d_inject_valid),
        .ft_d_inject_col  (ft_d_inject_col),
        .ft_d_inject_mask (ft_d_inject_mask)
    );
`else
    assign ft_inject_valid   = 1'b0;
    assign ft_inject_lane    = 5'd0;
    assign ft_inject_mask    = 64'd0;
    assign ft_c_inject_valid = 1'b0;
    assign ft_c_inject_col = 3'd0;
    assign ft_c_inject_mask = 64'd0;
    assign ft_d_inject_valid = 1'b0;
    assign ft_d_inject_col   = 3'd0;
    assign ft_d_inject_mask  = 64'd0;

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
`endif

    initial begin
`ifndef NO_DUMP
        $dumpfile("sha3_sim.vcd");
        $dumpvars(0, TESTBED);
`endif
    end

endmodule
