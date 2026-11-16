`timescale 1ns/1ps
// Per-channel binary RCT and reference-symbol APT (SP800-90B 4.4).
// Default thresholds use a provisional monitoring assumption, NOT an entropy credit.
module entropy_health_monitor #(
    parameter integer CHANNELS=8,
    parameter integer RCT_C=41,
    parameter integer APT_WINDOW=1024,
    parameter integer APT_C=793
)(
    input wire clk,resetn,clear,sample_valid,
    input wire [CHANNELS-1:0] sample_data,
    output reg [CHANNELS-1:0] rct_fail_now,apt_fail_now,
    output reg [CHANNELS-1:0] rct_fault,apt_fault
);
    reg have_previous;
    reg [CHANNELS-1:0] previous,reference;
    reg [31:0] run_count[0:CHANNELS-1];
    reg [31:0] apt_count[0:CHANNELS-1];
    reg [31:0] apt_index;
    always @* begin
        rct_fail_now=0;apt_fail_now=0;
        if(resetn && !clear && sample_valid) begin
            for(integer k=0;k<CHANNELS;k=k+1) begin
                if(have_previous && sample_data[k]==previous[k] && run_count[k]>=RCT_C-1)
                    rct_fail_now[k]=1;
                if(apt_index!=0 && sample_data[k]==reference[k] && apt_count[k]>=APT_C-1)
                    apt_fail_now[k]=1;
            end
        end
    end
    always @(posedge clk) begin
        if(!resetn || clear) begin
            have_previous<=0;previous<=0;reference<=0;apt_index<=0;
            rct_fault<=0;apt_fault<=0;
            for(integer k=0;k<CHANNELS;k=k+1) begin run_count[k]<=0;apt_count[k]<=0;end
        end else if(sample_valid) begin
            have_previous<=1;previous<=sample_data;
            rct_fault<=rct_fault|rct_fail_now;apt_fault<=apt_fault|apt_fail_now;
            if(apt_index==APT_WINDOW-1) apt_index<=0;
            else apt_index<=apt_index+1;
            if(apt_index==0) reference<=sample_data;
            for(integer k=0;k<CHANNELS;k=k+1) begin
                if(have_previous && sample_data[k]==previous[k]) begin
                    if(run_count[k]<RCT_C) run_count[k]<=run_count[k]+1;
                end else run_count[k]<=1;
                if(apt_index==0) apt_count[k]<=1;
                else if(sample_data[k]==reference[k] && apt_count[k]<APT_C)
                    apt_count[k]<=apt_count[k]+1;
            end
        end
    end
endmodule
