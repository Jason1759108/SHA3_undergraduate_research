`timescale 1ns/1ps
// SIMULATION ONLY. Strong and deliberately weak candidate pairs, with bounded
// changing read noise. Persistent sign flips model errors that voting cannot fix.
module puf_count_model #(parameter integer CANDIDATES=320,PAIR_W=$clog2(CANDIDATES))(
    input logic clk,rst_n,req,
    input logic[PAIR_W-1:0] pair_index,
    input logic[31:0] chip_seed,
    input logic[CANDIDATES-1:0] flip_mask,unstable_mask,
    input logic stall,drop_result,
    output logic ready,valid,
    output logic[15:0] count_a,count_b
);
    logic pending;
    integer delay_q,noise_counter,gap,n;
    logic[31:0] h;
    function automatic logic[31:0] mix(input logic[31:0] value);
        logic[31:0] x;
        begin x=value;x=(x^(x>>16))*32'h7feb352d;
            x=(x^(x>>15))*32'h846ca68b;return x^(x>>16);end
    endfunction
    assign ready=!pending&&!stall;
    always @(posedge clk or negedge rst_n)begin
        if(!rst_n)begin pending<=0;delay_q<=0;valid<=0;count_a<=0;count_b<=0;noise_counter<=0;end
        else begin
            valid<=0;
            if(req&&ready)begin
                h=mix(chip_seed^(32'(pair_index)*32'h9e3779b9));
                gap=30+integer'((h>>1)%100);n=(noise_counter%5)-2;
                if(integer'(pair_index)%19==0||unstable_mask[pair_index])begin count_a<=1001;count_b<=1000;end
                else if(h[0]^flip_mask[pair_index])begin count_a<=16'(1000+gap+n);count_b<=16'(1000-n);end
                else begin count_a<=16'(1000+n);count_b<=16'(1000+gap-n);end
                noise_counter<=noise_counter+1;pending<=1;delay_q<=2;
            end else if(pending)begin
                if(delay_q==1)begin pending<=0;if(!drop_result)valid<=1;end
                else delay_q<=delay_q-1;
            end
        end
    end
endmodule
