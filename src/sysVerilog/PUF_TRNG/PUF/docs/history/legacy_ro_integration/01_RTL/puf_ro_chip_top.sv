// PHYSICAL TEMPLATE ONLY: not in RTL simulation manifests.
module puf_ro_chip_top #(
    parameter integer RAW_BITS=256,CANDIDATES=320,REPEATS=5,MIN_MARGIN=8,
    parameter integer SETTLE_CYCLES=4,WARM_CYCLES=5,WINDOW_CYCLES=100,
    parameter integer MEASURE_TIMEOUT=256,RO_STAGES=5
)(
    input logic clk,rst_n,start,
    input puf_types::puf_command_t command,
    input logic[CANDIDATES-1:0] bitmap_in,
    input logic[RAW_BITS/16*5-1:0] helper_in,
    input logic helper_in_valid,
    output logic ready,busy,done,result_valid,
    input logic result_ready,
    output logic key_valid,helper_valid,
    output logic[RAW_BITS-1:0] key_data,
    output logic[RAW_BITS/16*5-1:0] helper_out,
    output puf_types::puf_error_t error,
    output puf_types::puf_status_t status_code,
    output logic[15:0] corrected_words
);
    wire[2*CANDIDATES-1:0] ro_signals;
    logic[2*CANDIDATES-1:0] ro_enable;
    ro_array #(.CANDIDATES(CANDIDATES),.STAGES(RO_STAGES)) bank(.enable(ro_enable),.ro(ro_signals));
    puf_ro_top #(.RAW_BITS(RAW_BITS),.CANDIDATES(CANDIDATES),.REPEATS(REPEATS),.MIN_MARGIN(MIN_MARGIN),
        .SETTLE_CYCLES(SETTLE_CYCLES),.WARM_CYCLES(WARM_CYCLES),.WINDOW_CYCLES(WINDOW_CYCLES),
        .MEASURE_TIMEOUT(MEASURE_TIMEOUT)) digital(.*);
endmodule
