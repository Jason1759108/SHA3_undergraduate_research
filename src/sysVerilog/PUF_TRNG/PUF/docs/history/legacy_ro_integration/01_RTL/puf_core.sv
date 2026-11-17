// Selected-pair acquisition only. No oscillator, storage, key derivation or auth.
module puf_core #(
    parameter integer RAW_BITS=256,CANDIDATES=320,REPEATS=5,COUNT_W=16,
    parameter integer MIN_MARGIN=8,TIMEOUT_CYCLES=256,
    parameter integer PAIR_W=(CANDIDATES>1)?$clog2(CANDIDATES):1
)(
    input logic clk,rst_n,start,
    input logic[CANDIDATES-1:0] bitmap_in,
    output logic ready,busy,done,
    output puf_types::puf_status_t status_code,
    output logic[RAW_BITS-1:0] response,
    output logic measure_req,
    input logic measure_ready,measure_valid,
    output logic[PAIR_W-1:0] pair_index,
    input logic[COUNT_W-1:0] count_a,count_b
);
    import puf_types::*;
    typedef enum logic[2:0]{IDLE,SEEK,ISSUE,WAIT_RESULT,LOCKED} core_state_t;
    core_state_t state;
    logic[CANDIDATES-1:0] bitmap_q;
    integer cursor,selected,sample_index,ones,timer;
    logic pair_weak,sample_weak;
    logic[COUNT_W-1:0] gap;
    assign ready=state==IDLE;
    assign busy=state!=IDLE&&state!=LOCKED;
    assign measure_req=state==ISSUE;
    assign pair_index=PAIR_W'(cursor);
    assign gap=count_a>=count_b ? count_a-count_b : count_b-count_a;
    generate
        if(MIN_MARGIN==0)assign sample_weak=count_a==count_b;
        else assign sample_weak=(count_a==count_b)||(gap<COUNT_W'(MIN_MARGIN));
    endgenerate
    // synthesis translate_off
    initial if(RAW_BITS<1||CANDIDATES<RAW_BITS||REPEATS<1||REPEATS%2==0||
        MIN_MARGIN<0||TIMEOUT_CYCLES<1||COUNT_W<1)
        $fatal(1,"Invalid PUF core parameters");
    initial if(COUNT_W<32&&64'(MIN_MARGIN)>=(64'd1<<COUNT_W))
        $fatal(1,"MIN_MARGIN must fit COUNT_W");
    // synthesis translate_on
    always_ff @(posedge clk or negedge rst_n)begin
        if(!rst_n)begin
            state<=IDLE;bitmap_q<=0;cursor<=0;selected<=0;sample_index<=0;ones<=0;
            timer<=0;pair_weak<=0;response<=0;done<=0;status_code<=PUF_OK;
        end else begin
            done<=0;
            case(state)
                IDLE:if(start)begin
                    response<=0;cursor<=0;selected<=0;sample_index<=0;ones<=0;
                    timer<=0;pair_weak<=0;status_code<=PUF_OK;bitmap_q<=bitmap_in;
                    if($countones(bitmap_in)!=RAW_BITS)begin done<=1;status_code<=PUF_BAD_BITMAP;end
                    else state<=SEEK;
                end
                SEEK:if(bitmap_q[cursor])state<=ISSUE;
                    else if(cursor==CANDIDATES-1)begin
                        response<=0;done<=1;status_code<=PUF_BAD_BITMAP;state<=IDLE;
                    end else cursor<=cursor+1;
                ISSUE:if(measure_ready)begin timer<=0;state<=WAIT_RESULT;end
                    else if(timer==TIMEOUT_CYCLES-1)begin
                        response<=0;done<=1;status_code<=PUF_MEASURE_TIMEOUT;state<=LOCKED;
                    end else timer<=timer+1;
                WAIT_RESULT:if(measure_valid)begin
                    timer<=0;
                    if(sample_index==REPEATS-1)begin
                        sample_index<=0;ones<=0;pair_weak<=0;
                        if(pair_weak||sample_weak)begin
                            response<=0;done<=1;status_code<=PUF_WEAK_PAIR;state<=IDLE;
                        end else begin
                            response[selected]<=(ones+((count_a>count_b)?1:0)>REPEATS/2);
                            if(selected==RAW_BITS-1)begin done<=1;state<=IDLE;end
                            else begin selected<=selected+1;cursor<=cursor+1;state<=SEEK;end
                        end
                    end else begin
                        sample_index<=sample_index+1;ones<=ones+((count_a>count_b)?1:0);
                        pair_weak<=pair_weak||sample_weak;state<=ISSUE;
                    end
                end else if(timer==TIMEOUT_CYCLES-1)begin
                    response<=0;done<=1;status_code<=PUF_MEASURE_TIMEOUT;state<=LOCKED;
                end else timer<=timer+1;
                LOCKED:state<=LOCKED; // reset core AND backend before another read
                default:state<=LOCKED;
            endcase
        end
    end
endmodule
