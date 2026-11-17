// Physical RO inputs remain external. Registered Gray counters cross into clk.
// RO signals MUST be free-running and stable throughout WARM + WINDOW.
// Configure WINDOW so fewer than 2**COUNT_W edges occur per measurement.
module ro_frequency_counter #(
    parameter integer COUNT_W=16, WARM_CYCLES=5, WINDOW_CYCLES=100
)(
    input logic clk,rst_n,ro_a,ro_b,req,
    output logic ready,valid,
    output logic [COUNT_W-1:0] count_a,count_b
);
    // Async assertion, synchronous release in each oscillator clock domain.
    (* async_reg="true" *) logic[1:0] reset_a,reset_b;
    always_ff @(posedge ro_a or negedge rst_n)
        if(!rst_n)reset_a<=0;else reset_a<={reset_a[0],1'b1};
    always_ff @(posedge ro_b or negedge rst_n)
        if(!rst_n)reset_b<=0;else reset_b<={reset_b[0],1'b1};
    logic [COUNT_W-1:0] bin_a,bin_b,gray_a,gray_b;
    (* async_reg="true" *) logic [COUNT_W-1:0] a1,a2,b1,b2;
    logic [COUNT_W-1:0] start_a,start_b,now_a,now_b;
    typedef enum logic[1:0]{IDLE,WARM,MEASURE} state_t;
    state_t state;
    integer timer;
    function automatic logic[COUNT_W-1:0] decode(input logic[COUNT_W-1:0] g);
        logic[COUNT_W-1:0] v;
        begin v[COUNT_W-1]=g[COUNT_W-1];
            for(integer i=COUNT_W-2;i>=0;i--)v[i]=v[i+1]^g[i];return v;end
    endfunction
    always_ff @(posedge ro_a or negedge reset_a[1])
        if(!reset_a[1])begin bin_a<=0;gray_a<=0;end
        else begin bin_a<=bin_a+1'b1;gray_a<=(bin_a+1'b1)^((bin_a+1'b1)>>1);end
    always_ff @(posedge ro_b or negedge reset_b[1])
        if(!reset_b[1])begin bin_b<=0;gray_b<=0;end
        else begin bin_b<=bin_b+1'b1;gray_b<=(bin_b+1'b1)^((bin_b+1'b1)>>1);end
    always_ff @(posedge clk or negedge rst_n)
        if(!rst_n)begin a1<=0;a2<=0;b1<=0;b2<=0;end
        else begin a1<=gray_a;a2<=a1;b1<=gray_b;b2<=b1;end
    assign now_a=decode(a2);assign now_b=decode(b2);assign ready=state==IDLE;
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n)begin state<=IDLE;timer<=0;valid<=0;count_a<=0;count_b<=0;start_a<=0;start_b<=0;end
        else begin
            valid<=0;
            case(state)
                IDLE:if(req)begin timer<=0;state<=WARM;end
                WARM:if(timer==WARM_CYCLES-1)begin start_a<=now_a;start_b<=now_b;timer<=0;state<=MEASURE;end
                    else timer<=timer+1;
                MEASURE:if(timer==WINDOW_CYCLES-1)begin
                    count_a<=now_a-start_a;count_b<=now_b-start_b;valid<=1;state<=IDLE;
                end else timer<=timer+1;
                default:state<=IDLE;
            endcase
        end
    end
endmodule
