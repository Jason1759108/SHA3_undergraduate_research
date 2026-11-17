// Stimulus/checker for the AXI + RO-wave integration regression; includes raw diagnostics and faults.
`timescale 1ns/1ps
module PATTERN_PUF_AXI_RO(
    output logic clk,reset_n,
    output logic [11:0] awaddr,araddr,
    output logic awvalid,wvalid,bready,arvalid,rready,
    output logic [31:0] wdata,
    output logic [3:0] wstrb,
    input wire awready,wready,bvalid,arready,rvalid,
    input wire [1:0] bresp,rresp,
    input wire [31:0] rdata,
    input wire [639:0] enable,
    output logic [639:0] stop_mask,fast_mask,
    output logic [319:0] flip_mask,tie_mask
);
    integer phase;
    logic [31:0] value,seq_before,flags;
    logic [319:0] bitmap;
    logic [255:0] gold_key,got_key;
    logic [79:0] gold_helper,got_helper;
    initial begin clk=0;forever #5 clk=!clk;end
    initial begin #100000000;$fatal(1,"PUF256 test timeout");end
    function automatic bit expected_bit(input integer p);
        return ((p*13+7)%11)<6;
    endfunction
    function automatic logic [79:0] sketch_reference(input logic [255:0] word);
        logic [79:0] result;
        result=0;
        for(integer w=0;w<16;w++)for(integer b=0;b<16;b++)if(word[16*w+b])begin
            result[5*w+4]=~result[5*w+4];
            if(b<15)result[5*w+:4]=result[5*w+:4]^4'(b+1);
        end
        return result;
    endfunction
    task automatic aw(input logic [11:0] addr);
        @(negedge clk); awaddr=addr; awvalid=1;
        do @(posedge clk); while(!awready);
        @(negedge clk); awvalid=0;
    endtask
    task automatic wd(input logic [31:0] data,input logic [3:0] strobe=4'hf);
        @(negedge clk); wdata=data; wstrb=strobe; wvalid=1;
        do @(posedge clk); while(!wready);
        @(negedge clk); wvalid=0;
    endtask
    task automatic response(input logic [1:0] exp_resp=0,input integer stall=0);
        while(!bvalid) @(negedge clk);
        repeat(stall) begin
            @(negedge clk);
            if(!bvalid || bresp!=exp_resp) $fatal(1,"B response changed under backpressure");
        end
        if(bresp!=exp_resp) $fatal(1,"Unexpected BRESP %0d",bresp);
        bready=1; @(posedge clk); @(negedge clk); bready=0;
    endtask
    task automatic write_reg(input logic [11:0] addr,input logic [31:0] data,
                              input integer order=0,input logic [3:0] strobe=4'hf,
                              input logic [1:0] exp_resp=0,input integer stall=0);
        if(order==1) begin wd(data,strobe); repeat(3) @(negedge clk); aw(addr); end
        else if(order==2) begin fork aw(addr); wd(data,strobe); join end
        else begin aw(addr); repeat(2) @(negedge clk); wd(data,strobe); end
        response(exp_resp,stall);
    endtask
    task automatic read_reg(input logic [11:0] addr,output logic [31:0] data,
                            input logic [1:0] exp_resp=0,input integer stall=0);
        @(negedge clk); araddr=addr; arvalid=1;
        do @(posedge clk); while(!arready);
        @(negedge clk); arvalid=0;
        while(!rvalid) @(negedge clk);
        data=rdata;
        repeat(stall) begin
            @(negedge clk);
            if(!rvalid || rdata!==data || rresp!=exp_resp) $fatal(1,"R response changed under backpressure");
        end
        if(rresp!=exp_resp) $fatal(1,"Unexpected RRESP");
        rready=1; @(posedge clk); @(negedge clk); rready=0;
    endtask
    task automatic expect_reg(input logic [11:0] addr,input logic [31:0] want);
        logic [31:0] got;
        read_reg(addr,got);
        if(got!==want) $fatal(1,"reg[%h]=%h expected=%h",addr,got,want);
    endtask
    task automatic configure;
        write_reg('h014,128);write_reg('h018,64);
        for(integer w=0;w<10;w++)write_reg(12'('h100+4*w),bitmap[32*w+:32]);
        write_reg('h140,gold_helper[31:0]);write_reg('h144,gold_helper[63:32]);write_reg('h148,{16'd0,gold_helper[79:64]});
    endtask
    task automatic run_puf(input logic [31:0] cmd,input bit helper_valid,input integer want_status,
                           input logic [255:0] want_key,input integer corrected=0);
        write_reg('h010,cmd);write_reg('h030,32'(helper_valid));read_reg('h024,seq_before);
        write_reg('h008,17,2);
        flags=0;
        for(integer polls=0;polls<10000 && !flags[2];polls++)begin
            repeat(100)@(negedge clk);read_reg('h00c,flags);
        end
        if(!flags[2])$fatal(1,"PUF result timeout");
        expect_reg('h024,seq_before+1);expect_reg('h028,cmd);
        expect_reg('h01c,32'(want_status==0 ? 0 : 256+want_status));
        expect_reg('h020,32'(corrected));
        if(flags[3]!=(want_status==0) || flags[4]!=(want_status==0 && cmd==0))$fatal(1,"result qualification flags");
        for(integer w=0;w<8;w++)read_reg(12'('h180+4*w),got_key[32*w+:32]);
        if(got_key!==want_key)$fatal(1,"Key mismatch status=%0d got=%h want=%h",want_status,got_key,want_key);
        read_reg('h1c0,got_helper[31:0]);read_reg('h1c4,got_helper[63:32]);read_reg('h1c8,value);got_helper[79:64]=value[15:0];
        if(value[31:16]!=0)$fatal(1,"reserved helper output bits");
        if(got_helper!==((want_status==0 && cmd==0)?gold_helper:80'd0))$fatal(1,"helper output mismatch");
        repeat(20)@(negedge clk);
        expect_reg('h024,seq_before+1);expect_reg('h180,want_key[31:0]);
        write_reg('h008,1);read_reg('h00c,flags);
        if(!flags[5])$fatal(1,"START during held result was accepted");
        write_reg('h100,0,0,4'hf,2);
        expect_reg('h100,bitmap[31:0]);
        write_reg('h008,2);repeat(3)@(negedge clk);read_reg('h00c,flags);
        if(!flags[0] || flags[2])$fatal(1,"result consume did not restore READY");
        $display("[PASS] command=%0d status=%0d corrected=%0d",cmd,want_status,corrected);
    endtask
    task automatic raw_measure(input integer p,input integer want_status=0);
        logic [31:0] previous,a,b;
        write_reg('h200,32'(p));read_reg('h210,previous);write_reg('h008,24);
        flags=0;
        for(integer poll=0;poll<20000 && !flags[8];poll++)begin repeat(10)@(negedge clk);read_reg('h00c,flags);end
        if(!flags[8])$fatal(1,"raw diagnostic timeout");
        expect_reg('h210,previous+1);expect_reg('h214,32'(p));expect_reg('h20c,32'(want_status));
        read_reg('h204,a);read_reg('h208,b);
        if(want_status==0 && (a==0 || b==0 || (a>b)!=expected_bit(p)))$fatal(1,"raw bit/count failed pair %0d",p);
        if(enable!=0)$fatal(1,"ROs left enabled");
    endtask
    initial begin
        reset_n=0;awaddr=0;araddr=0;awvalid=0;wvalid=0;bready=0;arvalid=0;rready=0;wdata=0;wstrb=0;
        stop_mask=0;fast_mask=0;flip_mask=0;tie_mask=0;phase=0;bitmap=0;gold_key=0;gold_helper=0;
        begin integer k;k=0;for(integer p=0;p<320;p++)if(p%5!=0)begin bitmap[p]=1;gold_key[k]=expected_bit(p);k++;end end
        gold_helper=sketch_reference(gold_key);
        repeat(5)@(negedge clk);reset_n=1;
        phase=1;
        expect_reg(0,32'h50554631);expect_reg(4,32'h00010000);expect_reg('h038,320);expect_reg('h03c,256);expect_reg('h040,80);
        write_reg('h014,32'h12345678,0,4'hf,0,5);write_reg('h014,32'habcd,1,4'h3);expect_reg('h014,32'h1234abcd);
        write_reg('h014,32'hffffffff,2,0);expect_reg('h014,32'h1234abcd);
        read_reg('h014,value,0,5);write_reg(0,0,0,4'hf,2);write_reg('h101,0,0,4'hf,2);read_reg('h7fc,value,2);write_reg(8,3,0,4'hf,2);
        configure();
        $display("[PASS] AXI independent channels, WSTRB, response backpressure, invalid accesses");
        phase=2;
        for(integer p=0;p<320;p++)raw_measure(p);
        raw_measure(320,1);
        $display("[PASS] all 320 diagnostic pair positions via real RO-wave counters");
        phase=3;run_puf(0,0,0,gold_key);
        phase=4;run_puf(1,0,6,0);run_puf(3,1,1,0);run_puf(32'h100,1,1,0);
        bitmap[1]=0;configure();run_puf(0,0,7,0);bitmap[1]=1;bitmap[0]=1;configure();run_puf(0,0,7,0);bitmap[0]=0;configure();
        write_reg('h014,15);run_puf(0,0,8,0);write_reg('h014,128);write_reg('h018,63);run_puf(0,0,9,0);write_reg('h018,64);
        phase=5;run_puf(1,1,0,gold_key);
        flip_mask[1]=1;run_puf(1,1,0,gold_key,1);flip_mask=0;
        phase=6;flip_mask[1]=1;flip_mask[2]=1;run_puf(1,1,5,0);flip_mask=0;
        phase=7;tie_mask[1]=1;run_puf(0,0,4,0);tie_mask=0;
        stop_mask[2]=1;run_puf(0,0,10,0);stop_mask=0;
        fast_mask[2]=1;fast_mask[3]=1;write_reg('h014,100000);run_puf(0,0,11,0);fast_mask=0;write_reg('h014,128);
        phase=8;
        write_reg('h010,0);write_reg('h008,1);wait(enable!=0);repeat(8)@(negedge clk);
        write_reg('h014,256,0,4'hf,2);write_reg('h008,4);repeat(4)@(negedge clk);
        read_reg('h00c,flags);if(!flags[0] || flags[2] || enable!=0)$fatal(1,"ABORT contract");
        expect_reg('h180,0);expect_reg('h100,bitmap[31:0]);run_puf(1,1,0,gold_key);
        phase=9;
        write_reg('h010,0);write_reg('h008,1);wait(enable!=0);repeat(8)@(negedge clk);reset_n=0;
        repeat(5)@(negedge clk);reset_n=1;repeat(3)@(negedge clk);
        expect_reg('h024,0);expect_reg('h100,0);expect_reg('h180,0);
        configure();run_puf(1,1,0,gold_key);
        $display("[SUCCESS] PUF256 real-wave/counter/ECC/AXI regression; reset recovery without re-enrollment");$finish;
    end
endmodule
