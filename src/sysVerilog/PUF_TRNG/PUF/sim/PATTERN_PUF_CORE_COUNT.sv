// Stimulus/checker for bitmap/helper, voting, backend handshake/timeout and ECC limits.
`timescale 1ns/1ps
// Self-contained test stimulus and known answers; no generated include files.
module PATTERN_PUF_CORE_COUNT(
    output logic clk,rst_n,start,
    output puf_types::puf_command_t command,
    output logic[319:0] bitmap_in,flip_mask,unstable_mask,
    output logic[79:0] helper_in,
    output logic helper_in_valid,result_ready,
    output logic[31:0] chip_seed,
    output logic stall,drop_result,
    output logic[7:0] phase,
    input logic ready,busy,done,result_valid,key_valid,helper_valid,
    input logic[255:0] key_data,
    input logic[79:0] helper_out,
    input puf_types::puf_error_t error,
    input puf_types::puf_status_t status,
    input logic[15:0] corrected_count,
    input logic req,mready,
    input logic[8:0] pair_index
);
    import puf_types::*;
    // GOLD/ALT constants are inserted here and cross-checked independently.
    localparam logic [319:0] GOLD_MAP = 320'h0000000000007bffff7fffeffffdffffbffff7fffeffffdffffbffff7fffeffffdffffbffff7fffe;
    localparam logic [79:0] GOLD_HELPER = 80'hcdb0eab97fd937457469;
    localparam logic [255:0] GOLD_RAW = 256'hecf3f6c8c4a547f9c5add81e165ea95dbb7361bc3fbcf456bb27a8b807d67dfc;
    localparam logic [319:0] ALT_MAP = 320'hfffeffffdffffbffff7fffeffffdffffbffff7fffeffffdffffbffff7fffeffffdfc000000000000;
    localparam logic [79:0] ALT_HELPER = 80'h7127e9937abd285626ae;
    localparam logic [255:0] ALT_RAW = 256'h523ef3a9b2e3d9e7ed91894a8ff38b5bb03c2cbd52bb76e6c3787f79e8ad764f;
    logic[79:0] registered_helper;
    logic[319:0] active_map;
    integer request_count=0,last_pair=-1,pair_samples=0;
    always #5 clk=~clk;
    always @(posedge clk)begin
        if(!rst_n)begin request_count<=0;active_map<=0;last_pair<=-1;pair_samples<=0;end
        else if(start&&ready)begin active_map<=bitmap_in;last_pair<=-1;pair_samples<=0;end
        else if(req&&mready)begin
            if(integer'(pair_index)>=320||!active_map[pair_index])$fatal(1,"unselected pair measured");
            if(last_pair==integer'(pair_index))pair_samples<=pair_samples+1;
            else begin
                if(last_pair>=0&&(pair_samples!=5||integer'(pair_index)<=last_pair))$fatal(1,"pair order/repeat count");
                last_pair<=integer'(pair_index);pair_samples<=1;
            end
            request_count<=request_count+1;
        end
    end
    function automatic integer candidate_for(input integer raw_index);
        integer seen;
        begin seen=0;candidate_for=-1;
            for(integer i=0;i<320;i++)if(GOLD_MAP[i])begin
                if(seen==raw_index)candidate_for=i;seen++;
            end
        end
    endfunction
    task automatic reset_all;
        @(negedge clk);rst_n=0;start=0;result_ready=0;
        repeat(4)@(negedge clk);rst_n=1;
        @(negedge clk);
        if(!ready||busy||result_valid||key_valid||helper_valid||key_data!=0||helper_out!=0)
            $fatal(1,"reset contract failed");
    endtask
    task automatic take_result;
        @(negedge clk);result_ready=1;
        @(negedge clk);result_ready=0;
        if(result_valid||key_valid||helper_valid)$fatal(1,"result not consumed");
    endtask
    task automatic operation(input puf_command_t cmd,input logic[319:0] map,
        input logic[79:0] helper,input logic hvalid,input puf_status_t expected,
        input logic mutate_inputs=0);
        integer calls_before;
        calls_before=request_count;
        if(!ready)$fatal(1,"operation issued while not ready");
        @(negedge clk);command=cmd;bitmap_in=map;helper_in=helper;helper_in_valid=hvalid;start=1;
        @(negedge clk);start=0;
        if(mutate_inputs)begin
            repeat(10)@(negedge clk);
            command=puf_command_t'(2'd3);bitmap_in=0;helper_in='1;helper_in_valid=0;start=1;
            @(negedge clk);start=0;
        end
        while(!result_valid)@(negedge clk);
        if(!done||status!=expected||error!=(expected==PUF_OK?PUF_NO_ERROR:PUF_ERROR))
            $fatal(1,"expected %s got %s error=%s",expected.name(),status.name(),error.name());
        if(expected==PUF_OK)begin
            if(!key_valid||helper_valid!=(cmd==REGISTRATION)||request_count-calls_before!=1280)
                $fatal(1,"success output/request-count contract");
            if(cmd==CERTIFICATION&&helper_out!=0)$fatal(1,"certification exported helper");
        end else if(key_valid||helper_valid||key_data!=0||helper_out!=0)
            $fatal(1,"failed operation exported data");
        if((expected==PUF_BAD_BITMAP||expected==PUF_BAD_COMMAND||expected==PUF_MISSING_HELPER)&&request_count!=calls_before)
            $fatal(1,"invalid input triggered a measurement");
        $display("[PASS] phase=%0d command=%s status=%s corrected=%0d requests=%0d",phase,puf_command_ascii(cmd),status.name(),corrected_count,request_count-calls_before);
    endtask
    initial begin
        clk=0;rst_n=0;start=0;command=REGISTRATION;bitmap_in=0;helper_in=0;helper_in_valid=0;
        result_ready=0;chip_seed=32'h13579bdf;flip_mask=0;unstable_mask=0;stall=0;drop_result=0;phase=1;
        registered_helper=0;reset_all();
        operation(REGISTRATION,GOLD_MAP,80'hffffffffffffffffffff,0,PUF_OK,1);
        if(key_data!==GOLD_RAW||helper_out!==GOLD_HELPER)$fatal(1,"registration golden mismatch");
        registered_helper=helper_out;
        // Hold result for a future SHA3 adapter and reject starts during hold.
        repeat(4)begin
            @(negedge clk);start=1;bitmap_in=0;
            if(!result_valid||ready||busy||done||key_data!==GOLD_RAW||helper_out!==GOLD_HELPER||!helper_valid)
                $fatal(1,"backpressure/data retention failed");
        end
        start=0;take_result();
        phase=2;operation(CERTIFICATION,GOLD_MAP,registered_helper,1,PUF_OK);
        if(key_data!==GOLD_RAW||corrected_count!=0)$fatal(1,"clean reconstruction");take_result();
        phase=3;reset_all();operation(CERTIFICATION,GOLD_MAP,registered_helper,1,PUF_OK);
        if(key_data!==GOLD_RAW)$fatal(1,"stateless reconstruction after reset");take_result();
        phase=4;for(integer i=0;i<256;i+=16)flip_mask[candidate_for(i)]=1;
        operation(CERTIFICATION,GOLD_MAP,registered_helper,1,PUF_OK);
        if(key_data!==GOLD_RAW||corrected_count!=16)$fatal(1,"16 distributed errors");take_result();flip_mask=0;
        phase=5;flip_mask[candidate_for(0)]=1;flip_mask[candidate_for(1)]=1;
        operation(CERTIFICATION,GOLD_MAP,registered_helper,1,PUF_ECC_UNCORRECTABLE);take_result();
        phase=6;flip_mask[candidate_for(2)]=1;
        operation(CERTIFICATION,GOLD_MAP,registered_helper,1,PUF_OK);
        if(key_data!==(GOLD_RAW^256'h8007))$fatal(1,"triple-error limit fixture changed");
        $display("[LIMIT] SECDED three-error miscorrection remains possible; no key authentication");take_result();flip_mask=0;
        phase=7;unstable_mask[candidate_for(0)]=1;
        operation(REGISTRATION,GOLD_MAP,0,0,PUF_WEAK_PAIR);take_result();
        operation(CERTIFICATION,GOLD_MAP,registered_helper,1,PUF_WEAK_PAIR);take_result();unstable_mask=0;
        phase=8;operation(REGISTRATION,0,0,0,PUF_BAD_BITMAP);take_result();
        operation(CERTIFICATION,GOLD_MAP^320'd1,registered_helper,1,PUF_BAD_BITMAP);take_result();
        operation(REGISTRATION,GOLD_MAP^(320'd1<<candidate_for(0)),0,0,PUF_BAD_BITMAP);take_result();
        phase=9;operation(CERTIFICATION,GOLD_MAP,registered_helper,0,PUF_MISSING_HELPER);take_result();
        operation(puf_command_t'(2'd2),GOLD_MAP,0,0,PUF_BAD_COMMAND);take_result();
        operation(puf_command_t'(2'd3),GOLD_MAP,0,0,PUF_BAD_COMMAND);take_result();
        phase=10;operation(CERTIFICATION,GOLD_MAP,registered_helper^80'd1,1,PUF_ECC_UNCORRECTABLE);take_result();
        // A zero-valued helper is present when its valid flag is 1; not "missing".
        operation(CERTIFICATION,GOLD_MAP,0,1,PUF_ECC_UNCORRECTABLE);take_result();
        phase=11;operation(REGISTRATION,ALT_MAP,0,0,PUF_OK);
        if(key_data!==ALT_RAW||helper_out!==ALT_HELPER)$fatal(1,"alternate external bitmap");take_result();
        operation(CERTIFICATION,ALT_MAP,ALT_HELPER,1,PUF_OK);
        if(key_data!==ALT_RAW)$fatal(1,"alternate reconstruction");take_result();
        phase=12;stall=1;operation(REGISTRATION,GOLD_MAP,0,0,PUF_MEASURE_TIMEOUT);take_result();
        if(ready||busy)$fatal(1,"timeout should lock until shared reset");stall=0;reset_all();
        phase=13;drop_result=1;operation(CERTIFICATION,GOLD_MAP,registered_helper,1,PUF_MEASURE_TIMEOUT);take_result();
        if(ready||busy)$fatal(1,"missing-result timeout should lock");drop_result=0;reset_all();
        phase=14;@(negedge clk);command=REGISTRATION;bitmap_in=GOLD_MAP;start=1;
        @(negedge clk);start=0;repeat(30)@(negedge clk);reset_all();
        operation(CERTIFICATION,GOLD_MAP,registered_helper,1,PUF_OK);
        if(key_data!==GOLD_RAW)$fatal(1,"reset during acquisition");take_result();
        $display("[SUCCESS] simplified PUF external bitmap/helper, two commands, enum and adapter-handshake regression");$finish;
    end
    initial begin #10000000;$fatal(1,"Pattern watchdog");end
endmodule
