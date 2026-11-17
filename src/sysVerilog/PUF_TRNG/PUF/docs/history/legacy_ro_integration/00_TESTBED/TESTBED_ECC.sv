`timescale 1ns/1ps
module TESTBED_ECC;
    logic[15:0] raw,corrected,count;
    logic[4:0] helper,generated;
    logic bad;
    puf_sketch #(.RAW_BITS(16)) dut(.raw,.helper,.generated_helper(generated),
        .corrected,.uncorrectable(bad),.corrected_words(count));
    PATTERN_ECC u_PATTERN(.raw,.helper,.corrected,.count,.generated,.bad);

    initial begin
`ifndef NO_DUMP
        $dumpfile("ecc_sim.vcd");
        $dumpvars(0, TESTBED_ECC);
`endif
    end
endmodule
