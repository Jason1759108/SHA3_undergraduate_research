// Unit testbench for the SECDED sketch block only; no RO, counter or AXI.
`timescale 1ns/1ps
module TESTBED_PUF_ECC_SECDED;
    logic[15:0] raw,corrected,count;
    logic[4:0] helper,generated;
    logic bad;
    puf_sketch #(.RAW_BITS(16)) dut(.raw,.helper,.generated_helper(generated),
        .corrected,.uncorrectable(bad),.corrected_words(count));
    PATTERN_PUF_ECC_SECDED u_PATTERN(.raw,.helper,.corrected,.count,.generated,.bad);

    initial begin
`ifndef NO_DUMP
        $dumpfile("puf_ecc_secded.vcd");
        $dumpvars(0, TESTBED_PUF_ECC_SECDED);
`endif
    end
endmodule
