// Digital core testbench: PUF device + artificial count backend; no RO waveform/AXI.
`timescale 1ns/1ps
module TESTBED_PUF_CORE_COUNT;
    import puf_types::*;
    logic clk,rst_n,start,helper_in_valid,ready,busy,done,result_valid,result_ready;
    logic key_valid,helper_valid;
    puf_command_t command;
    puf_error_t error;
    puf_status_t status;
    logic[319:0] bitmap_in,flip_mask,unstable_mask;
    logic[79:0] helper_in,helper_out;
    logic[255:0] key_data;
    logic[15:0] corrected_count,ca,cb;
    logic[31:0] chip_seed;
    logic stall,drop_result,req,mready,mvalid;
    logic[8:0] pair_index;
    logic[7:0] phase;
    logic[255:0] command_text,error_text,status_text;
    assign command_text=puf_command_ascii(command);
    assign error_text=puf_error_ascii(error);
    assign status_text=puf_status_ascii(status);
    puf_device dut(.clk,.rst_n,.start,.command,.bitmap_in,.helper_in,.helper_in_valid,
        .ready,.busy,.done,.result_valid,.result_ready,.key_valid,.helper_valid,
        .key_data,.helper_out,.error,.status_code(status),.corrected_words(corrected_count),
        .measure_status(puf_types::PUF_OK),.measure_req(req),.measure_ready(mready),.measure_valid(mvalid),.pair_index,.count_a(ca),.count_b(cb));
    puf_count_model model(.clk,.rst_n,.req,.pair_index,.chip_seed,.flip_mask,.unstable_mask,
        .stall,.drop_result,.ready(mready),.valid(mvalid),.count_a(ca),.count_b(cb));
    PATTERN_PUF_CORE_COUNT u_PATTERN(.*);
    
    initial begin
`ifndef NO_DUMP
        $dumpfile("puf_core_count.vcd");
        $dumpvars(0, TESTBED_PUF_CORE_COUNT);
`endif
    end
endmodule
