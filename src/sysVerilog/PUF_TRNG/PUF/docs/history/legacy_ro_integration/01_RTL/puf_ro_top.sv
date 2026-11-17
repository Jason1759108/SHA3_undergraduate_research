// Integrated digital path. Real/model RO clocks enter through ro_signals.
module puf_ro_top #(
    parameter integer RAW_BITS=256,CANDIDATES=320,REPEATS=5,MIN_MARGIN=8,
    parameter integer SETTLE_CYCLES=4,WARM_CYCLES=5,WINDOW_CYCLES=100,
    parameter integer MEASURE_TIMEOUT=256
)(
    input logic clk,rst_n,start,
    input puf_types::puf_command_t command,
    input logic[CANDIDATES-1:0] bitmap_in,
    input logic[RAW_BITS/16*5-1:0] helper_in,
    input logic helper_in_valid,
    /* verilator tracing_off */
    input logic[2*CANDIDATES-1:0] ro_signals,
    output logic[2*CANDIDATES-1:0] ro_enable,
    /* verilator tracing_on */
    output logic ready,busy,done,result_valid,
    input logic result_ready,
    output logic key_valid,helper_valid,
    output logic[RAW_BITS-1:0] key_data,
    output logic[RAW_BITS/16*5-1:0] helper_out,
    output puf_types::puf_error_t error,
    output puf_types::puf_status_t status_code,
    output logic[15:0] corrected_words
);
    localparam integer PAIR_W=(CANDIDATES>1)?$clog2(CANDIDATES):1;
    logic req,mready,mvalid;
    logic[PAIR_W-1:0] pair_index;
    logic[15:0] count_a,count_b;
    puf_device #(.RAW_BITS(RAW_BITS),.CANDIDATES(CANDIDATES),.REPEATS(REPEATS),
        .MIN_MARGIN(MIN_MARGIN),.MEASURE_TIMEOUT(MEASURE_TIMEOUT)) core(
        .clk,.rst_n,.start,.command,.bitmap_in,.helper_in,.helper_in_valid,
        .ready,.busy,.done,.result_valid,.result_ready,.key_valid,.helper_valid,.key_data,.helper_out,
        .error,.status_code,.corrected_words,.measure_req(req),.measure_ready(mready),
        .measure_valid(mvalid),.pair_index,.count_a,.count_b);
    ro_measure_backend #(.CANDIDATES(CANDIDATES),.SETTLE_CYCLES(SETTLE_CYCLES),
        .WARM_CYCLES(WARM_CYCLES),.WINDOW_CYCLES(WINDOW_CYCLES)) backend(
        .clk,.rst_n,.req,.pair_index,.ro_signals,.ro_enable,.ready(mready),.valid(mvalid),.count_a,.count_b);
    // synthesis translate_off
    initial if(MEASURE_TIMEOUT<=SETTLE_CYCLES+WARM_CYCLES+WINDOW_CYCLES+8)
        $fatal(1,"MEASURE_TIMEOUT must exceed complete backend latency");
    // synthesis translate_on
endmodule
