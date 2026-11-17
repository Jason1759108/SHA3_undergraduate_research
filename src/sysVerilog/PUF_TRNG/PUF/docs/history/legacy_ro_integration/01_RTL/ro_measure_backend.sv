// Hold counters in reset while changing the selected clocks. Only the two
// selected ROs are enabled. Selection remains fixed until a result is captured.
module ro_measure_backend #(
    parameter integer CANDIDATES=320,PAIR_W=$clog2(CANDIDATES),
    parameter integer SETTLE_CYCLES=4,WARM_CYCLES=5,WINDOW_CYCLES=100
)(
    input logic clk,rst_n,req,
    input logic[PAIR_W-1:0] pair_index,
    /* verilator tracing_off */
    input logic[2*CANDIDATES-1:0] ro_signals,
    output logic[2*CANDIDATES-1:0] ro_enable,
    /* verilator tracing_on */
    output logic ready,valid,
    output logic[15:0] count_a,count_b
);
    typedef enum logic[2:0]{IDLE,SETTLE,COUNTER_START,COUNTER_WAIT,DELIVER} backend_state_t;
    backend_state_t state;
    logic[PAIR_W-1:0] selected_pair;
    logic ro_a,ro_b,counter_rst_n,counter_ready,counter_valid,ro_fault;
    logic[15:0] measured_a,measured_b;
    integer timer;
    assign ready=state==IDLE;
    assign ro_a=ro_signals[2*integer'(selected_pair)];
    assign ro_b=ro_signals[2*integer'(selected_pair)+1];
    assign counter_rst_n=rst_n&&(state==COUNTER_START||state==COUNTER_WAIT||state==DELIVER);
    always_comb begin
        ro_enable='0;
        if(rst_n&&state!=IDLE)begin
            ro_enable[2*integer'(selected_pair)]=1;
            ro_enable[2*integer'(selected_pair)+1]=1;
        end
    end
    ro_frequency_counter #(.WARM_CYCLES(WARM_CYCLES),.WINDOW_CYCLES(WINDOW_CYCLES)) counter(
        .clk,.rst_n(counter_rst_n),.ro_a,.ro_b,.req(state==COUNTER_START),
        .ready(counter_ready),.valid(counter_valid),.count_a(measured_a),.count_b(measured_b));
    // synthesis translate_off
    initial if(SETTLE_CYCLES<1||WARM_CYCLES<3||WINDOW_CYCLES<1)
        $fatal(1,"Invalid RO measurement timing");
    // synthesis translate_on
    always_ff @(posedge clk or negedge rst_n)begin
        if(!rst_n)begin state<=IDLE;selected_pair<=0;timer<=0;valid<=0;count_a<=0;count_b<=0;ro_fault<=0;end
        else begin
            valid<=0;
            case(state)
                IDLE:if(req)begin selected_pair<=pair_index;timer<=0;ro_fault<=0;state<=SETTLE;end
                SETTLE:if(timer==SETTLE_CYCLES-1)state<=COUNTER_START;else timer<=timer+1;
                COUNTER_START:if(counter_ready)state<=COUNTER_WAIT;
                COUNTER_WAIT:if(counter_valid)begin
                    // A stopped oscillator must not become a strong PUF bit.
                    ro_fault<=(measured_a==0||measured_b==0);
                    count_a<=(measured_a==0||measured_b==0)?16'd0:measured_a;
                    count_b<=(measured_a==0||measured_b==0)?16'd0:measured_b;
                    valid<=1;state<=DELIVER;
                end
                DELIVER:state<=IDLE;
                default:state<=IDLE;
            endcase
        end
    end
endmodule
