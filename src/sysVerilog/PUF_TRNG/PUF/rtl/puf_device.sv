// Stateless transactions: caller supplies bitmap/helper for EACH request.
// result_valid/result_ready hold the entire result packet for a future adapter.
module puf_device #(
    parameter integer RAW_BITS=256,CANDIDATES=320,REPEATS=5,
    parameter integer MIN_MARGIN=8,MEASURE_TIMEOUT=256,
    parameter integer PAIR_W=(CANDIDATES>1)?$clog2(CANDIDATES):1
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
    output logic[15:0] corrected_words,
    output logic measure_req,
    input logic measure_ready,measure_valid,
    input puf_types::puf_status_t measure_status,
    output logic[PAIR_W-1:0] pair_index,
    input logic[15:0] count_a,count_b
);
    import puf_types::*;
    typedef enum logic[2:0]{IDLE,CHECK_BITMAP,ACQUIRE_START,ACQUIRE_WAIT,RECONSTRUCT,RESULT,LOCKED} device_state_t;
    device_state_t state;
    puf_command_t command_q;
    localparam integer BITMAP_COUNT_W=$clog2(CANDIDATES+1);
    logic [PAIR_W-1:0] bitmap_cursor;
    logic [BITMAP_COUNT_W-1:0] bitmap_count;
    logic helper_present;
    logic[CANDIDATES-1:0] bitmap_q;
    wire [BITMAP_COUNT_W-1:0] bitmap_count_next=bitmap_count+BITMAP_COUNT_W'(bitmap_q[bitmap_cursor]);
    logic[RAW_BITS/16*5-1:0] helper_q,generated_helper;
    logic[RAW_BITS-1:0] raw,corrected;
    logic core_ready,core_busy,core_done,ecc_bad,lock_after_result;
    logic[15:0] ecc_count;
    puf_status_t core_status;
    assign ready=state==IDLE;
    assign busy=state==CHECK_BITMAP||state==ACQUIRE_START||state==ACQUIRE_WAIT||state==RECONSTRUCT;
    assign result_valid=state==RESULT;
    assign key_valid=result_valid&&(error==PUF_NO_ERROR);
    assign helper_valid=key_valid&&(command_q==REGISTRATION);
    puf_core #(.RAW_BITS(RAW_BITS),.CANDIDATES(CANDIDATES),.REPEATS(REPEATS),
        .MIN_MARGIN(MIN_MARGIN),.TIMEOUT_CYCLES(MEASURE_TIMEOUT)) sampler(
        .clk,.rst_n,.start(state==ACQUIRE_START),.bitmap_in(bitmap_q),
        .ready(core_ready),.busy(core_busy),.done(core_done),.status_code(core_status),
        .response(raw),.measure_req,.measure_ready,.measure_valid,.measure_status,.pair_index,.count_a,.count_b);
    puf_sketch #(.RAW_BITS(RAW_BITS)) sketch(.raw,.helper(helper_q),
        .generated_helper,.corrected,.uncorrectable(ecc_bad),.corrected_words(ecc_count));
    // synthesis translate_off
    initial if(RAW_BITS<16||RAW_BITS%16!=0||CANDIDATES<RAW_BITS)
        $fatal(1,"RAW_BITS must be a positive multiple of 16, <= CANDIDATES");
    // synthesis translate_on
    always_ff @(posedge clk or negedge rst_n)begin
        if(!rst_n)begin
            state<=IDLE;command_q<=REGISTRATION;bitmap_q<=0;helper_q<=0;
            bitmap_cursor<=0;bitmap_count<=0;helper_present<=0;
            key_data<=0;helper_out<=0;error<=PUF_NO_ERROR;status_code<=PUF_OK;
            corrected_words<=0;lock_after_result<=0;done<=0;
        end else begin
            done<=0;
            case(state)
                IDLE:if(start)begin
                    command_q<=command;bitmap_q<=bitmap_in;helper_q<=helper_in;
                    helper_present<=helper_in_valid;bitmap_cursor<=0;bitmap_count<=0;
                    key_data<=0;helper_out<=0;corrected_words<=0;lock_after_result<=0;
                    error<=PUF_NO_ERROR;status_code<=PUF_OK;
                    if(command!=REGISTRATION&&command!=CERTIFICATION)begin
                        error<=PUF_ERROR;status_code<=PUF_BAD_COMMAND;done<=1;state<=RESULT;
                    end else state<=CHECK_BITMAP;
                end
                CHECK_BITMAP:begin
                    bitmap_count<=bitmap_count_next;
                    if(bitmap_cursor==PAIR_W'(CANDIDATES-1))begin
                        if(bitmap_count_next!=BITMAP_COUNT_W'(RAW_BITS))begin
                            error<=PUF_ERROR;status_code<=PUF_BAD_BITMAP;done<=1;state<=RESULT;
                        end else if(command_q==CERTIFICATION&&!helper_present)begin
                            error<=PUF_ERROR;status_code<=PUF_MISSING_HELPER;done<=1;state<=RESULT;
                        end else state<=ACQUIRE_START;
                    end else bitmap_cursor<=bitmap_cursor+1'b1;
                end
                ACQUIRE_START:if(core_ready)state<=ACQUIRE_WAIT;
                ACQUIRE_WAIT:if(core_done)begin
                    if(core_status!=PUF_OK)begin
                        error<=PUF_ERROR;status_code<=core_status;done<=1;state<=RESULT;
                        lock_after_result<=(core_status==PUF_MEASURE_TIMEOUT);
                    end else state<=RECONSTRUCT;
                end
                RECONSTRUCT:begin
                    done<=1;state<=RESULT;
                    if(command_q==REGISTRATION)begin key_data<=raw;helper_out<=generated_helper;end
                    else if(ecc_bad)begin error<=PUF_ERROR;status_code<=PUF_ECC_UNCORRECTABLE;end
                    else begin key_data<=corrected;corrected_words<=ecc_count;end
                end
                RESULT:if(result_ready)state<=lock_after_result ? LOCKED : IDLE;
                LOCKED:state<=LOCKED;
                default:state<=LOCKED;
            endcase
        end
    end
endmodule
