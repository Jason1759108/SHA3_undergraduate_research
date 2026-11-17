`timescale 1ns/1ps
module PATTERN_PUF_WAVE(
    output logic clk,rst_n,start,
    output puf_types::puf_command_t command,
    output logic[319:0] bitmap_in,flip_mask,unstable_mask,
    output logic[639:0] stop_mask,
    output logic[79:0] helper_in,
    output logic helper_in_valid,result_ready,
    output logic[7:0] phase,
    input logic ready,busy,done,result_valid,key_valid,helper_valid,
    input logic[255:0] key_data,
    input logic[79:0] helper_out,
    input puf_types::puf_error_t error,
    input puf_types::puf_status_t status,
    input logic[15:0] corrected_count,
    input logic req,mready,mvalid,
    input logic[8:0] pair_index,
    input logic[15:0] ca,cb
);
    import puf_types::*;
    localparam logic[319:0] GOLD_MAP=320'h0000000000007bffff7fffeffffdffffbffff7fffeffffdffffbffff7fffeffffdffffbffff7fffe;
    localparam logic[79:0] GOLD_HELPER=80'hcdb0eab97fd937457469;
    localparam logic[255:0] GOLD_RAW=256'hecf3f6c8c4a547f9c5add81e165ea95dbb7361bc3fbcf456bb27a8b807d67dfc;
    localparam logic[319:0] ALT_MAP=320'hfffeffffdffffbffff7fffeffffdffffbffff7fffeffffdffffbffff7fffeffffdfc000000000000;
    localparam logic[79:0] ALT_HELPER=80'h7127e9937abd285626ae;
    localparam logic[255:0] ALT_RAW=256'h523ef3a9b2e3d9e7ed91894a8ff38b5bb03c2cbd52bb76e6c3787f79e8ad764f;
    logic[79:0] registered_helper;
    logic[319:0] active_map;
    integer requests=0,results=0,last_pair=-1,samples=0;
    integer fast_ps,slow_ps,expected_a,expected_b;
    logic[31:0] reference_h;
    logic reference_direction;
    function automatic logic[31:0] reference_mix(input logic[31:0] value);
        logic[31:0] x;
        begin x=value;x=(x^(x>>16))*32'h7feb352d;
            x=(x^(x>>15))*32'h846ca68b;return x^(x>>16);end
    endfunction
    always #5 clk=~clk;
    always @(posedge clk)begin
        if(!rst_n)begin requests<=0;results<=0;active_map<=0;last_pair<=-1;samples<=0;end
        else begin
            if(start&&ready)begin active_map<=bitmap_in;last_pair<=-1;samples<=0;end
            if(req&&mready)begin
                if(!active_map[pair_index])$fatal(1,"unselected pair requested");
                if(last_pair==integer'(pair_index))samples<=samples+1;
                else begin
                    if(last_pair>=0&&(samples!=5||integer'(pair_index)<=last_pair))$fatal(1,"pair ordering/repetition");
                    last_pair<=integer'(pair_index);samples<=1;
                end
                requests<=requests+1;
            end
            if(mvalid)begin
                results<=results+1;
                reference_h=reference_mix(32'h13579bdf^(32'(pair_index)*32'h9e3779b9));
                fast_ps=1500+integer'((reference_h>>1)%201);
                slow_ps=2500+integer'((reference_h>>9)%201);
                reference_direction=reference_h[0]^flip_mask[pair_index];
                expected_a=1000000/(2*(reference_direction?fast_ps:slow_ps));
                expected_b=(integer'(pair_index)%19==0||unstable_mask[pair_index]) ? expected_a :
                    1000000/(2*(reference_direction?slow_ps:fast_ps));
                if(stop_mask[2*integer'(pair_index)]||stop_mask[2*integer'(pair_index)+1])begin
                    if(ca!=0||cb!=0)$fatal(1,"stopped oscillator not rejected by backend");
                end else if(integer'(ca)<expected_a-2||integer'(ca)>expected_a+2||
                    integer'(cb)<expected_b-2||integer'(cb)>expected_b+2)
                    $fatal(1,"wave count disagrees with period/window a=%0d/%0d b=%0d/%0d",ca,expected_a,cb,expected_b);
            end
        end
    end
    function automatic integer candidate_for(input integer bit_index);
        integer seen;
        begin seen=0;candidate_for=-1;
            for(integer i=0;i<320;i++)if(GOLD_MAP[i])begin
                if(seen==bit_index)candidate_for=i;seen++;
            end
        end
    endfunction
    task automatic reset_all;
        @(negedge clk);rst_n=0;start=0;result_ready=0;
        repeat(5)@(negedge clk);rst_n=1;
        @(negedge clk);
        if(!ready||busy||result_valid||key_data!=0)$fatal(1,"reset failed");
    endtask
    task automatic consume;
        @(negedge clk);result_ready=1;
        @(negedge clk);result_ready=0;
        if(result_valid)$fatal(1,"result not consumed");
    endtask
    task automatic operation(input puf_command_t cmd,input logic[319:0] map,
        input logic[79:0] helper,input puf_status_t expected);
        integer old_req,old_result;
        old_req=requests;old_result=results;
        @(negedge clk);command=cmd;bitmap_in=map;helper_in=helper;helper_in_valid=(cmd==CERTIFICATION);start=1;
        @(negedge clk);start=0;
        while(!result_valid)@(negedge clk);
        if(!done||status!=expected||error!=(expected==PUF_OK?PUF_NO_ERROR:PUF_ERROR))
            $fatal(1,"wave phase %0d expected=%s got=%s",phase,expected.name(),status.name());
        if(expected==PUF_OK)begin
            if(!key_valid||helper_valid!=(cmd==REGISTRATION)||requests-old_req!=1280||results-old_result!=1280)
                $fatal(1,"wave result/measurement count contract");
        end else if(key_valid||helper_valid||key_data!=0||helper_out!=0)$fatal(1,"error leaked output");
        $display("[PASS] WAVE phase=%0d command=%s status=%s measurements=%0d",phase,puf_command_ascii(cmd),status.name(),results-old_result);
    endtask
    initial begin
        clk=0;rst_n=0;start=0;command=REGISTRATION;bitmap_in=0;helper_in=0;helper_in_valid=0;
        result_ready=0;flip_mask=0;unstable_mask=0;stop_mask=0;registered_helper=0;phase=1;
        reset_all();operation(REGISTRATION,GOLD_MAP,0,PUF_OK);
        if(key_data!==GOLD_RAW||helper_out!==GOLD_HELPER)$fatal(1,"wave registration mismatch got=%h",key_data);
        registered_helper=helper_out;
        repeat(4)begin @(negedge clk);
            if(done||!result_valid||ready||key_data!==GOLD_RAW||helper_out!==GOLD_HELPER)$fatal(1,"wave backpressure");
        end
        consume();phase=2;operation(CERTIFICATION,GOLD_MAP,registered_helper,PUF_OK);
        if(key_data!==GOLD_RAW||helper_out!=0)$fatal(1,"wave reconstruction");consume();
        phase=3;reset_all();operation(CERTIFICATION,GOLD_MAP,registered_helper,PUF_OK);
        if(key_data!==GOLD_RAW)$fatal(1,"wave reset recovery");consume();
        phase=4;for(integer i=0;i<256;i+=16)flip_mask[candidate_for(i)]=1;
        operation(CERTIFICATION,GOLD_MAP,registered_helper,PUF_OK);
        if(key_data!==GOLD_RAW||corrected_count!=16)$fatal(1,"wave 16 errors");consume();flip_mask=0;
        phase=5;flip_mask[candidate_for(0)]=1;flip_mask[candidate_for(1)]=1;
        operation(CERTIFICATION,GOLD_MAP,registered_helper,PUF_ECC_UNCORRECTABLE);consume();flip_mask=0;
        phase=6;unstable_mask[candidate_for(0)]=1;
        operation(REGISTRATION,GOLD_MAP,0,PUF_WEAK_PAIR);consume();unstable_mask=0;
        phase=7;stop_mask[2*candidate_for(0)]=1;
        operation(CERTIFICATION,GOLD_MAP,registered_helper,PUF_WEAK_PAIR);consume();stop_mask=0;
        phase=8;operation(REGISTRATION,ALT_MAP,0,PUF_OK);
        if(key_data!==ALT_RAW||helper_out!==ALT_HELPER)$fatal(1,"wave alternate bitmap");consume();
        phase=9;operation(CERTIFICATION,ALT_MAP,ALT_HELPER,PUF_OK);
        if(key_data!==ALT_RAW)$fatal(1,"wave alternate reconstruction");consume();
        phase=10;@(negedge clk);command=REGISTRATION;bitmap_in=GOLD_MAP;start=1;
        @(negedge clk);start=0;repeat(30)@(negedge clk);reset_all();
        operation(CERTIFICATION,GOLD_MAP,registered_helper,PUF_OK);
        if(key_data!==GOLD_RAW)$fatal(1,"wave reset during counting");consume();
        $display("[SUCCESS] complete RO waveform -> real counter -> PUF -> ECC regression");$finish;
    end
    initial begin #100000000;$fatal(1,"wave integration watchdog");end
endmodule
