
`timescale 1ns/1ps
module tb_reset_audit;
 reg clk=0;
 always #20 clk=~clk;
 reg ext_n=0;
 reg aux_good_n=1;
 wire bad_reset_n,good_reset_n,bad_bus_n,good_bus_n;
 design_1_rst_ps7_0_50M_0 bad (
 .slowest_sync_clk(clk),.ext_reset_in(ext_n),.aux_reset_in(1'b0),
 .mb_debug_sys_rst(1'b0),.dcm_locked(1'b1),
 .peripheral_aresetn(bad_reset_n),.interconnect_aresetn(bad_bus_n));
 design_1_rst_ps7_0_50M_0 good (
 .slowest_sync_clk(clk),.ext_reset_in(ext_n),.aux_reset_in(aux_good_n),
 .mb_debug_sys_rst(1'b0),.dcm_locked(1'b1),
 .peripheral_aresetn(good_reset_n),.interconnect_aresetn(good_bus_n));
 initial begin
  repeat(10) @(negedge clk);
  ext_n=1;
  repeat(200) @(negedge clk);
  if (bad_reset_n !== 0 || bad_bus_n !== 0)
   $fatal(1,"The original connection did not reproduce held reset");
  if (good_reset_n !== 1 || good_bus_n !== 1)
   $fatal(1,"Corrected inactive aux reset did not release outputs");
  $display("CONFIRMED original AUX=0 holds peripheral_aresetn=0 and interconnect_aresetn=0");
  $display("CONFIRMED corrected AUX=1 releases both reset outputs to 1");
  aux_good_n=0;
  repeat(20) @(negedge clk);
  if (good_reset_n !== 0 || good_bus_n !== 0) $fatal(1,"Aux reset assertion failed");
  aux_good_n=1;
  repeat(200) @(negedge clk);
  if (good_reset_n !== 1 || good_bus_n !== 1) $fatal(1,"Aux reset release failed");
  $display("PASS actual generated Reset IP reproduces the fault and validates the connection fix");
  $finish;
 end
 initial begin
  #50000;
  $fatal(1,"Timeout");
 end
endmodule
