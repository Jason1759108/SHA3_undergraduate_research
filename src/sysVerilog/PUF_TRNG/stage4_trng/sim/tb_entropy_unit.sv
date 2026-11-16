`timescale 1ns/1ps
module tb_entropy_unit;
reg s_axi_aclk=0; always #5 s_axi_aclk=~s_axi_aclk;
reg s_axi_aresetn=0;
reg [15:0] s_axi_awaddr=0,s_axi_araddr=0;
reg [2:0] s_axi_awprot=0,s_axi_arprot=0;
reg s_axi_awvalid=0,s_axi_wvalid=0,s_axi_bready=0,s_axi_arvalid=0,s_axi_rready=0;
reg [31:0] s_axi_wdata=0;reg [3:0] s_axi_wstrb=15;
wire s_axi_awready,s_axi_wready,s_axi_bvalid,s_axi_arready,s_axi_rvalid;
wire [1:0] s_axi_bresp,s_axi_rresp;wire [31:0] s_axi_rdata;

entropy_axi #(.DEPTH(16),.WARMUP(8),.STARTUP_SAMPLES(8),.RCT_C(5),.APT_WINDOW(8),.APT_C(7),.WATCHDOG(50000)) dut(.*);
reg [7:0] injected;
integer mode=0;
always @* begin
 injected=dut.observed[0]?8'haa:8'h55;
 if(mode==1) injected=0;
 if(mode==2) injected=(dut.observed==3)?8'hff:0;
 if(mode==3 && dut.observed>=8) injected=8'haa;
 if(mode==4 && dut.observed>=19) injected=8'haa;
end
reg[7:0] expected[0:15];integer seen=0;
always @(posedge s_axi_aclk) begin
 if(dut.start_cmd)seen=0;
 else if(dut.sample_tick && dut.startup_ok && !(|dut.fail_now)) begin
  expected[seen]=dut.sync_data;seen=seen+1;
 end
end
task automatic wr(input [15:0] addr,input [31:0] data,input integer order,input [3:0] strobe,input [1:0] resp);
 reg [1:0] saved;
 fork
  begin
   if(order==1) repeat(4) @(negedge s_axi_aclk);
   @(negedge s_axi_aclk);s_axi_awaddr=addr;s_axi_awvalid=1;
   do @(posedge s_axi_aclk);while(!s_axi_awready);
   @(negedge s_axi_aclk);s_axi_awvalid=0;
  end
  begin
   if(order==2) repeat(4) @(negedge s_axi_aclk);
   @(negedge s_axi_aclk);s_axi_wdata=data;s_axi_wstrb=strobe;s_axi_wvalid=1;
   do @(posedge s_axi_aclk);while(!s_axi_wready);
   @(negedge s_axi_aclk);s_axi_wvalid=0;
  end
 join
 wait(s_axi_bvalid);saved=s_axi_bresp;
 repeat(4) begin @(negedge s_axi_aclk);if(!s_axi_bvalid || s_axi_bresp!==saved)$fatal(1,"Unstable B under backpressure");end
 if(saved!==resp)$fatal(1,"Write response addr=%h actual=%b expected=%b",addr,saved,resp);
 s_axi_bready=1;@(posedge s_axi_aclk);@(negedge s_axi_aclk);s_axi_bready=0;
endtask

task automatic rd(input [15:0] addr,output [31:0] data,input [1:0] resp);
 reg [31:0] saved;
 @(negedge s_axi_aclk);s_axi_araddr=addr;s_axi_arvalid=1;
 do @(posedge s_axi_aclk);while(!s_axi_arready);
 @(negedge s_axi_aclk);s_axi_arvalid=0;
 wait(s_axi_rvalid);saved=s_axi_rdata;
 repeat(4) begin @(negedge s_axi_aclk);if(!s_axi_rvalid || s_axi_rdata!==saved)$fatal(1,"Unstable R under backpressure");end
 if(s_axi_rresp!==resp)$fatal(1,"Read response addr=%h",addr);
 data=saved;s_axi_rready=1;@(posedge s_axi_aclk);@(negedge s_axi_aclk);s_axi_rready=0;
endtask

task automatic finish_capture;
 reg[31:0] status;
 for(integer i=0;i<20000;i++) begin
  rd(4,status,0);if(!status[0])return;
 end
 $fatal(1,"Capture never completed");
endtask
reg [31:0] value;
task automatic check(input[15:0] addr,input[31:0] wanted,input[1:0] resp=0);
 rd(addr,value,resp);if(value!==wanted)$fatal(1,"addr=%h value=%h expected=%h",addr,value,wanted);
endtask
task automatic start_normal;
 mode=0;wr(0,4,0,15,0);wr(16,16,0,15,0);wr(0,1,0,15,0);
endtask
initial begin
 force dut.sync_data=injected;
 repeat(20)@(negedge s_axi_aclk);s_axi_aresetn=1;
 check(20,32'h524f4832);check(32,0);check(16,512);check(4096,0,2);
 wr(16,16,1,15,0);wr(16,4097,2,15,2);wr(16,16,0,1,2);
 wr(0,1,0,0,0);check(4,0);
 start_normal();check(4096,0,2);wr(16,32,1,15,2);wr(0,1,2,15,2);
 finish_capture();check(4,194);check(8,16);check(64,24);check(76,8);check(32,0);
 if(seen!=16)$fatal(1,"scoreboard count");
 for(integer i=0;i<16;i++)check(4096+i*4,{24'b0,expected[i]});
 check(4096+16*4,0,2);wr(4096,0,0,15,2);wr(16'h80,0,0,15,2);
 $display("PASS HEALTH UNIT startup discard, valid gating, full RAM, AW/W ordering, stalls");
 mode=1;wr(0,1,0,15,0);finish_capture();check(4,6);check(8,0);check(48,255);check(52,255);check(56,0);check(32,0);check(4096,0,2);
 wr(0,1,0,15,2);check(52,255);wr(0,4,0,15,0);check(52,0);
 mode=2;wr(0,1,0,15,0);finish_capture();check(4,6);check(52,0);check(56,255);check(4096,0,2);
 $display("PASS HEALTH UNIT startup RCT/APT fail, sticky fault, explicit clear");
 wr(0,4,0,15,0);mode=3;wr(0,1,0,15,0);finish_capture();check(4,70);check(8,3);check(4096,0,2);
 wr(0,4,0,15,0);mode=4;wr(0,1,0,15,0);finish_capture();check(4,70);check(8,15);check(4096,0,2);
 $display("PASS HEALTH UNIT monitor continuity across startup and fault at last payload sample wins");
 start_normal();wr(0,2,0,15,0);check(4,10);check(4096,0,2);wr(0,1,0,15,2);
 wr(0,4,0,15,0);mode=0;wr(16,4096,0,15,0);wr(0,1,0,15,0);finish_capture();check(4,86);check(32,0);check(4096,0,2);
 start_normal();@(negedge s_axi_aclk);s_axi_aresetn=0;repeat(4)@(negedge s_axi_aclk);s_axi_aresetn=1;
 check(4,0);check(8,0);check(16,512);check(48,0);check(4096,0,2);
 start_normal();finish_capture();check(4,194);
 $display("SUCCESS HEALTH UNIT startup RCT APT valid-gate last-sample sticky abort watchdog reset recovery");$finish;
end
initial begin #20000000;$fatal(1,"Global timeout");end
endmodule
