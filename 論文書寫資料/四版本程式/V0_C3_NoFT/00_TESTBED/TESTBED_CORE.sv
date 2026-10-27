`timescale 1ns/1ps
module TESTBED_CORE;
 logic clk=0,rst_n=0,start_process=0,load_state=0;
 logic [1599:0] initial_state='0;
 wire [1599:0] state_out;
 wire process_done;
 paper_keccak_core dut(.clk(clk),.rst_n(rst_n),.start_process(start_process),
    .load_state(load_state),.initial_state(initial_state),.state_out(state_out),
    .process_done(process_done));
 always #5 clk=~clk;
 longint cycle_index=0,start_cycle=0;
 always @(posedge clk) begin
    cycle_index++;
    if(start_process) start_cycle=cycle_index;
    if(process_done) $display("[CORE_METRIC] cycles=%0d",cycle_index-start_cycle);
 end
 task automatic run_case(input logic[1599:0] data_in, expected,input int number);
    int watchdog;
    // Drive away from DUT edges: gate_en_ff samples load-derived enables
    // on negedge clk. Hold load through that edge AND the next posedge.
    rst_n=0; start_process=0; load_state=0;
    repeat(4) @(negedge clk);
    #1; rst_n=1;
    @(negedge clk); #1; initial_state=data_in; load_state=1;
    @(negedge clk);
    @(posedge clk); #1;
    if(state_out!==data_in) begin
       $display("[FAIL] core load vector=%0d expected=%0400h actual=%0400h",number,data_in,state_out);
       $fatal(1,"[FAIL] core input state was not loaded correctly");
    end
    $display("[PASS] standalone core input vector=%0d loaded 1600-bit state",number);
    @(negedge clk); #1; load_state=0; start_process=1;
    @(negedge clk); #1; start_process=0;
    watchdog=0;
    while(!process_done) begin
       @(negedge clk); watchdog++;
       if(watchdog>4000) $fatal(1,"[FAIL] core timeout");
    end
    if(state_out!==expected) begin
       $display("[FAIL] core result vector=%0d expected=%0400h actual=%0400h",number,expected,state_out);
       $fatal(1,"[FAIL] core vector %0d mismatch",number);
    end
    $display("[PASS] standalone core vector=%0d complete 1600-bit state matches reference",number);
    repeat(2) @(negedge clk);
 endtask
 initial begin
 run_case(1600'h0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000,1600'heaf1ff7b5ceca24975f644e97f30a13b16f53526e70465c21841f924a2c509e4940c7922ae3a26148c3ee88a1ccf32c8b87c5a554fd00ecb613670957bc4661164befef28cc970f205e5635a21d9ae6101f22f1a11a5569f43b831cd0347c82681a57c16dbcf555fa9a6e6260d712103eb5aa93f2317d63530935ab7d08ffc64ad30a6f71b19059c8c5bda0cd6192e7690fee5a0a44647c4ff97a42d7f8e6fd48b284e056253d057bd1547306f80494dd598261ea65aa9ee84d5ccf933c0478af1258f7940e1dde7,0);
run_case(1600'hffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,1600'h3f82afe91ca4b9b0caa831f1a5dc86cec6bc1f3512a665aee8c3c28faf02c7f519866a26cbc8bdc2554d327de6fbad9b2725f1f14230421340cf4eba54a2285dcc4cc7fca665bfadf63b60e27cea6f0e1a9ce5e4b37ddcd3ce442e92c6728660f03ce56503e82921ddad454b84d7ab05004650c533b7bfb39e5d924f1a65ed480bfaeb81a299b5d4eb5e5b55ca4fb4902213b79d9055207c4f44330558eb182ff0f711ba0547331d8bb6f30a010f8228d6539abf24095b97cdf5aa0d21af5e789f00f21bba6817c4,1);
run_case(1600'h000000000000001800000000000000170000000000000016000000000000001500000000000000140000000000000013000000000000001200000000000000110000000000000010000000000000000f000000000000000e000000000000000d000000000000000c000000000000000b000000000000000a0000000000000009000000000000000800000000000000070000000000000006000000000000000500000000000000040000000000000003000000000000000200000000000000010000000000000000,1600'hd153f43a297e4a335e16103071340888421af5937c9948a3a72fe58aa6e0a7dfd4c055c0c5d12330fd0ca63cb499e985777f1f3b43a4d22153f531437e3ed8cfa0f5ea808cc415d7f7afc26c944d31e2e873de0cca309da62e2af6948c901f11c8353e94eb2c3e6a55efdff58b256d7f0b7338de0d9f268f2fe54e389bb17f880cf3a858cbda7a5a487e9472951be3be30d193965138fd3fa1d7144f7c8dd493d15f8ba4f3f6606a20477b43d1760545f765194b8a51797d1df7a676b65694008374b05252ed8115,2);
run_case(1600'h736ae31d6e461e0dd5336963eefba1f836fbefaa6fb125e398c475f0f066a9cefa8cfc37711c2db95c55827df1d1b1a4be1e08c47287358f1fe68f0af33cb97a81af155173f23d65e3779b97f4a7c150454021de755d453ba708a824f612c92608d12e6b76c84d116a99b4b1f77dd0fccc623af8783354e72e2ac13ef8e8d8d28ff34785799e5cbdf1bbcdcbfa53e0a8538454127b096493b54cda58fbbee87e1715609f7c746c6978dde6e5fd29f054daa66d2c7ddf743f3c6ef372fe94f82a9e3779b97f4a7c15,1600'hdf68a7bb5d2b0ce661a163ac3eba80f410ddbeebe458b252862d6584ee50df70c16eead6d0db6010f33a4cd3aa95275700528757e1c03db912592620b4dd0b95eea107ca9361fe321f5d4af14ecb06d97dc6ff6dcae6561f66020944c6b12498ccd5128ad46742a71b579043068f1016116b41d831728eadc153aadc130dc58367e56b60031e29fcb34a25b31b7696997f7bcbcfd16e9b391e347032aed699f8fceaedf9a1f28a536ec37d71757f2bbb5917075d2a3eeb96ef0b3c211f70b40b2aacc1870473730d,3);
 $display("[SUCCESS] All 4 standalone core reference vectors passed!");
 #20; $finish;
 end
 initial begin #1000000; $fatal(1,"[FAIL] core global watchdog"); end
endmodule
