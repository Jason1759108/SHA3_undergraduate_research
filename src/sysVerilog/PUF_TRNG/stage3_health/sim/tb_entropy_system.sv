`timescale 1ns/1ps
`define PS dut.design_1_i.processing_system7_0.inst
`define ENT dut.design_1_i.entropy_ip.inst
module tb_entropy_system;
reg clk_drive=0,por_drive=0,srst_drive=0;
wire clk=clk_drive,por_n=por_drive,srst_n=srst_drive;
always #10 clk_drive=~clk_drive;
design_1_wrapper dut(.FIXED_IO_ps_clk(clk),.FIXED_IO_ps_porb(por_n),.FIXED_IO_ps_srstb(srst_n));
reg[7:0] injected;integer mode=0;
always @* begin
 injected=`ENT.observed[0]?8'haa:8'h55;
 if(mode==1)injected=0;
 if(mode==2)injected=(`ENT.observed%5==4)?8'hff:0;
 if(mode==3 && `ENT.observed>=1024)injected=8'haa;
 if(mode==4 && `ENT.observed>=2007)injected=8'haa;
end
reg [7:0] expected[0:1023];integer seen=0;
always @(posedge dut.design_1_i.processing_system7_0_FCLK_CLK0) begin
 if(`ENT.start_cmd)seen=0;
 else if(`ENT.sample_tick && `ENT.startup_ok && !(|`ENT.fail_now))begin
  expected[seen]=`ENT.sync_data;seen=seen+1;
 end
end
task automatic wr(input[31:0] off,input[31:0] val,input[1:0] wanted=0);
 reg[1:0] resp;
 `PS.write_data(32'h43c00000+off,4,val,resp);
 if(resp!==wanted)$fatal(1,"PS write response %h off=%h",resp,off);
endtask
task automatic rd(input[31:0] off,output[31:0] val,input[1:0] wanted=0);
 reg[2047:0] data;reg[1:0] resp;
 `PS.read_data(32'h43c00000+off,4,data,resp);val=data[31:0];
 if(resp!==wanted)$fatal(1,"PS read response %h off=%h",resp,off);
endtask
task automatic reset_pl;
 `PS.fpga_soft_reset(15);repeat(40)@(posedge `ENT.s_axi_aclk);
 if(`ENT.s_axi_aresetn!==0)$fatal(1,"Reset did not assert");
 `PS.fpga_soft_reset(0);repeat(250)@(posedge `ENT.s_axi_aclk);
 if(`ENT.s_axi_aresetn!==1 || dut.design_1_i.axi_control.ARESETN!==1)$fatal(1,"Reset did not release");
 if(`ENT.ro_enable!==0)$fatal(1,"RO not off at reset");
 $display("PASS SYSTEM reset assert/release and RO default off");
endtask
task automatic wait_done;
 reg[31:0] status;
 for(integer i=0;i<10000;i++)begin rd(4,status);if(!status[0])return;end
 $fatal(1,"System capture timeout");
endtask
task automatic normal_capture;
 reg[31:0] val;
 mode=0;wr(0,4);wr(16,16);wr(0,1);wait_done();rd(4,val);if(val!==194)$fatal(1,"Normal status=%h",val);
 rd(8,val);if(val!==1024 || seen!=1024)$fatal(1,"Capture count");
 for(integer i=0;i<1024;i++)begin
  rd(4096+i*4,val);if(val!=={24'b0,expected[i]})$fatal(1,"PS RAM read mismatch at %0d",i);
 end
 rd(32,val);if(val!==0)$fatal(1,"RO not auto-off");
 $display("PASS SYSTEM 1024 samples captured and ALL read through PS GP0 match independent scoreboard");
endtask
reg[31:0] value;
initial begin
 force `ENT.sync_data=injected;
 #2000;por_drive=1;srst_drive=1;`PS.set_debug_level_info(0);`PS.set_stop_on_error(1);
 reset_pl();rd(20,value);if(value!==32'h524f4832)$fatal(1,"ID");
 rd(4096,value,2);rd(16'h8000,value,2);wr(16'h40,0,2);
 normal_capture();
 mode=1;wr(0,1);wait_done();rd(4,value);if(value!==6)$fatal(1,"Startup RCT status %h",value);
 rd(52,value);if(value!==255)$fatal(1,"RCT mask");rd(32,value);if(value!==0)$fatal(1,"RO off");rd(4096,value,2);wr(0,1,2);
 wr(0,4);mode=2;wr(0,1);wait_done();rd(56,value);if(value!==255)$fatal(1,"APT mask");rd(52,value);if(value!==0)$fatal(1,"APT should not need RCT");rd(4096,value,2);
 wr(0,4);mode=3;wr(0,1);wait_done();rd(4,value);if(value!==70)$fatal(1,"Runtime RCT status");rd(8,value);if(value!==39)$fatal(1,"Continuity count %d",value);rd(4096,value,2);
 wr(0,4);mode=4;wr(0,1);wait_done();rd(4,value);if(value!==70)$fatal(1,"Last sample priority");rd(8,value);if(value!==1023)$fatal(1,"Last sample count");rd(4096,value,2);
 wr(0,4);mode=0;wr(0,1);wr(0,2);rd(4,value);if(value!==10)$fatal(1,"Abort status %h",value);rd(4096,value,2);
 reset_pl();normal_capture();
 repeat(20)@(posedge `ENT.s_axi_aclk);
 $display("SUCCESS HEALTH SYSTEM reset GP0 startup RCT APT RAM-read fault abort recovery");$finish;
end
initial begin #50000000;$fatal(1,"System global timeout");end
endmodule
`undef PS
`undef ENT
