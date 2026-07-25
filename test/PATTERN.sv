`timescale 1ns/1ps

// 關鍵修改 1：把 program 改成 module，避開時序衝突，並允許使用 always
module PATTERN (
    output logic        clk,
    output logic        rst_n,
    output logic        in_valid,
    output logic [63:0] in_data,
    output logic [63:0] in_state,
    input  logic        out_valid,
    input  logic [63:0] out_state
);

    // 產生 Clock (改回最直覺的 always 寫法)
    initial clk = 0;
    always #5 clk = ~clk;

    initial begin
        $display("--> [步驟 1] 開始初始化訊號...");
        rst_n    = 1'b1;
        in_valid = 1'b0;
        in_data  = 64'b0;
        in_state = 64'b0;

        #10 rst_n = 1'b0;
        #10 rst_n = 1'b1;
        #10;
        
        $display("--> [步驟 2] Reset 完成，準備給予測資...");

        @(negedge clk);
        in_valid = 1'b1;
        in_data  = 64'hAAAA_BBBB_CCCC_DDDD;
        in_state = 64'h1111_2222_3333_4444;

        @(negedge clk);
        in_valid = 1'b0;
        in_data  = 64'b0;
        in_state = 64'b0;

        $display("--> [步驟 3] 測資送出完畢，等待 out_valid 拉高...");

        // 關鍵修改 2：加上 Timeout 防呆機制
        fork
            begin
                // 正常情況：等待訊號拉高
                wait(out_valid === 1'b1);
                // @(posedge out_valid); 
            end
            begin
                // 例外情況：如果等了 500ns 都沒反應，就強制中斷模擬
                #500; 
                $display("\n=======================================");
                $display("  [ ERROR ] 卡死了！Timeout 發生！");
                $display("  原因：DUT (test.sv) 沒有將 out_valid 拉高。");
                $display("=======================================\n");
                $finish;
            end
        join_any
        
        $display("--> [步驟 4] 收到 out_valid！開始比對運算結果...");

        if (out_state === (64'hAAAA_BBBB_CCCC_DDDD ^ 64'h1111_2222_3333_4444)) begin
            $display("\n=======================================");
            $display("        [ PASS ] Testbed is working!   ");
            $display("        XOR Result Matched Perfectly.  ");
            $display("=======================================\n");
        end else begin
            $display("\n=======================================");
            $display("        [ FAIL ] Testbed Check Failed! ");
            $display("  Expected : %h", 64'hAAAA_BBBB_CCCC_DDDD ^ 64'h1111_2222_3333_4444);
            $display("  Got      : %h", out_state);
            $display("=======================================\n");
        end

        #20 $finish;
    end
endmodule