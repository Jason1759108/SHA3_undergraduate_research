`timescale 1ns/1ps
module PATTERN_RO #(parameter real CLK_PERIOD_NS=10.0)(
    output logic clk,rst_n,enable_a,enable_b,req,
    input logic ready,valid,
    input logic[7:0] ca,cb
);
    always #(CLK_PERIOD_NS/2.0) clk=~clk;
    task automatic read_counts(input logic a_running);
        @(negedge clk);req=1;
        @(negedge clk);req=0;
        while(!valid)@(negedge clk);
        if(cb<198||cb>202)$fatal(1,"RO B count=%0d",cb);
        if(a_running ? (ca<248||ca>252) : (ca!=0))$fatal(1,"RO A count=%0d",ca);
        $display("[PASS] waveform counters A=%0d B=%0d",ca,cb);
    endtask
    initial begin
        clk=0;rst_n=0;enable_a=1;enable_b=1;req=0;
        repeat(4)@(negedge clk);rst_n=1;
        for(integer i=0;i<8;i++)read_counts(1);
        enable_a=0;read_counts(0);
        enable_a=1;read_counts(1);
        @(negedge clk);rst_n=0;
        repeat(3)@(negedge clk);rst_n=1;read_counts(1);
        $display("[SUCCESS] RO waveform and Gray counter regression");$finish;
    end
    initial begin #1000000;$fatal(1,"RO watchdog");end
endmodule
