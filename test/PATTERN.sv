`timescale 1ns/1ps

module PATTERN (
    output logic          clk,
    output logic          rst_n,
    output logic          in_valid,
    output logic [1079:0] msg_in,
    output logic [7:0]    msg_length,

    input  logic          in_ready,
    input  logic [31:0]   out_data,
    input  logic          out_valid,
    input  logic          hash_done
);

    import sha3_pkg::*;

    int pass_count;

    // 時脈產生 (10ns 週期)
    initial clk = 1'b0;
    always #5 clk = ~clk;

    // ------------------------------------------------------------------------
    // 自動監視任務：於背景監控全域 X/Z 感染與分段正確性
    // ------------------------------------------------------------------------
    initial begin
        // 等待重置結束
        wait (rst_n === 1'b1);
        /*
        forever begin
            @(posedge clk);
            
            // 監控 1: 檢查內部的 cur_state 是否被 X 污染
            if ($isunknown(TESTBED.u_sha3_top.cur_state[0][0])) begin
                $display("\n==================================================");
                $display("[DIAGNOSTIC ERROR] 'X' detected in cur_state[0][0] at time %0t!", $time);
                $display("==================================================\n");
                $finish;
            end

            // 監控 2: Padding 完成檢查
            if (TESTBED.u_sha3_top.accept_msg) begin
                #1; check_padding_domain();
            end

            // 監控 3: Absorb 完成檢查
            if (TESTBED.u_sha3_top.absorb_en) begin
                #1; check_absorb_state();
            end

            // 監控 4: Round 0 Theta 檢查
            if (TESTBED.u_sha3_top.theta_done && TESTBED.u_sha3_top.round_index == 5'd0) begin
                #1; check_theta_round0();
            end

            // ----------------------------------------------------------------
            // [修正] 監控 5: 回合結束攔截 (利用 chi_done 判斷 Round 結束)
            // ----------------------------------------------------------------
            if (TESTBED.u_sha3_top.chi_done) begin
                #1; // 等待 1 unit 讓 nxt_state 確實寫入 cur_state 暫存器
                
                // 檢查 Round 0 結束時的狀態 (確認第一次的非線性與常數運算)
                if (TESTBED.u_sha3_top.round_index == 5'd0) begin
                    $display("\n[DIAGNOSTIC] --- Round 0 Finished (After Iota) ---");
                    $display("  R0 state[0][0] = %16h", TESTBED.u_sha3_top.cur_state[0][0]);
                    $display("  R0 state[1][0] = %16h", TESTBED.u_sha3_top.cur_state[1][0]);
                end
                
                // 檢查 Round 23 結束時的狀態 (確認進入 Formatter 前的最終矩陣)
                if (TESTBED.u_sha3_top.round_index == 5'd23) begin
                    $display("\n[DIAGNOSTIC] === Final Keccak State (Round 23) ===");
                    $display("  Final state[0][0] = %16h", TESTBED.u_sha3_top.cur_state[0][0]);
                    $display("  Final state[1][0] = %16h", TESTBED.u_sha3_top.cur_state[1][0]);
                    $display("  Final state[2][0] = %16h", TESTBED.u_sha3_top.cur_state[2][0]);
                    $display("  Final state[3][0] = %16h", TESTBED.u_sha3_top.cur_state[3][0]);
                    $display("  *(Note: SHA3-256 Digest is extracted from these 4 words)*\n");
                end
            end

            // ----------------------------------------------------------------
            // [保留] 監控 6: 輸出攔截 (檢查 Output Formatter 是怎麼切資料的)
            // ----------------------------------------------------------------
            if (TESTBED.u_sha3_top.out_valid) begin
                #1;
                $display("[DIAGNOSTIC] Formatter Output[%0d] = %08h", 
                         TESTBED.u_sha3_top.u_output_formatter.cnt, 
                         TESTBED.u_sha3_top.out_data);
            end
        end
        */
        
    end

    // 請將原本的 always @(negedge clk) 改成 posedge，並加上 #1 延遲
    always @(posedge clk) begin
        if (TESTBED.u_sha3_top.chi_done) begin
            #1; // 延遲 1 單位時間，確保 nxt_state 已經確實寫入 cur_state
            $display("\n[DIAGNOSTIC] --- True Round %0d Finished ---", TESTBED.u_sha3_top.round_index);
            $display("  state[0][0] = %16h", TESTBED.u_sha3_top.cur_state[0][0]);
            $display("  state[1][0] = %16h", TESTBED.u_sha3_top.cur_state[1][0]);
        end
    end

    // ------------------------------------------------------------------------
    // 子驗證 Task
    // ------------------------------------------------------------------------
    task automatic check_padding_domain();
        logic [1087:0] pad;
        pad = TESTBED.u_sha3_top.padded_block;

        if ($isunknown(pad)) begin
            $display("[FAIL][STAGE: PAD] padded_block contains X/Z!");
            $finish;
        end

        // 針對 empty message (msg_length = 0) 進行檢查
        if (TESTBED.u_sha3_top.msg_length_q == 8'd0) begin
            if (pad[7:0] !== 8'h06 || pad[1087:1080] !== 8'h80) begin
                $display("[FAIL][STAGE: PAD] Empty message domain padding error!");
                $display("  Expected pad[7:0] = 0x06, got = 0x%02h", pad[7:0]);
                $display("  Expected pad[1087:1080] = 0x80, got = 0x%02h", pad[1087:1080]);
                $finish;
            end else begin
                $display("[DIAGNOSTIC][PASS] Step 1: Padding Domain OK.");
            end
        end
    endtask

    task automatic check_absorb_state();
        state_t abs_st;
        logic [$bits(state_t)-1:0] abs_st_packed; // 宣告 packed 變數
        
        abs_st = TESTBED.u_sha3_top.absorbed_state;
        abs_st_packed = {>>{abs_st}}; // 先攤平賦值

        if ($isunknown(abs_st_packed)) begin
            $display("[FAIL][STAGE: ABSORB] absorbed_state contains X/Z!");
            $finish;
        end

        if (TESTBED.u_sha3_top.msg_length_q == 8'd0) begin
            if (abs_st[0][0] !== 64'h0000000000000006 || abs_st[1][3] !== 64'h8000000000000000) begin
                $display("[FAIL][STAGE: ABSORB] Empty message absorb state mismatch!");
                $display("  Expected abs_st[0][0] = 64'h0000000000000006, got = 64'h%16h", abs_st[0][0]);
                $display("  Expected abs_st[1][3] = 64'h8000000000000000, got = 64'h%16h", abs_st[1][3]);
                $finish;
            end else begin
                $display("[DIAGNOSTIC][PASS] Step 2: Absorb State OK.");
            end
        end
    endtask

    task automatic check_theta_round0();
        state_t th_st;
        logic [$bits(state_t)-1:0] th_st_packed; // 宣告 packed 變數
        
        th_st = TESTBED.u_sha3_top.theta_state;
        th_st_packed = {>>{th_st}}; // 先攤平賦值

        if ($isunknown(th_st_packed)) begin
            $display("[FAIL][STAGE: THETA] Round 0 theta_state contains X/Z!");
            $finish;
        end

        // 理論值驗證 (Round 0 for empty message)
        if (TESTBED.u_sha3_top.msg_length_q == 8'd0) begin
            if (th_st[0][0] !== 64'h0000000000000007 || th_st[1][3] !== 64'h8000000000000006) begin
                $display("[FAIL][STAGE: THETA] Round 0 Theta execution error!");
                $display("  Expected theta[0][0] = 64'h0000000000000007, got = 64'h%16h", th_st[0][0]);
                $display("  Expected theta[1][3] = 64'h8000000000000006, got = 64'h%16h", th_st[1][3]);
                $finish;
            end else begin
                $display("[DIAGNOSTIC][PASS] Step 3: Round 0 Theta OK.");
            end
        end
    endtask

    // ------------------------------------------------------------------------
    // 主測試 Pattern
    // ------------------------------------------------------------------------
    task automatic run_case(
        input [8*16-1:0]   case_name,
        input int          length,
        input logic [1079:0] message,
        input logic [255:0] expected_digest
    );
        logic [255:0] digest;
        int word_count;
        int cycles;
        begin
            digest     = '0;
            word_count = 0;
            cycles     = 0;

            wait (in_ready === 1'b0 || in_ready === 1'b1);
            @(negedge clk);
            msg_in     = message;
            msg_length = length[7:0];
            in_valid   = 1'b1;

            @(negedge clk);
            msg_in     = '0;
            msg_length = 8'd0;
            in_valid   = 1'b0;

            while (hash_done !== 1'b1) begin
                @(negedge clk);
                if (out_valid) begin
                    if (word_count < 8) begin
                        digest[word_count*32 +: 32] = out_data;
                    end
                    word_count++;
                end

                cycles++;
                if (cycles > 6000) begin
                    $display("[FAIL] %0s timeout waiting for hash_done", case_name);
                    $finish;
                end
            end

            if (word_count != 8) begin
                $display("[FAIL] %0s expected 8 output words, got %0d", case_name, word_count);
                $finish;
            end

            if (digest !== expected_digest) begin
                $display("[FAIL] %0s digest mismatch", case_name);
                $display("       expected = %064h", expected_digest);
                $display("       got      = %064h", digest);
                $finish;
            end

            pass_count++;
            $display("[PASS] %0s cycles=%0d digest=%064h", case_name, cycles, digest);
            @(negedge clk);
        end
    endtask

    initial begin
        logic [1079:0] message;

        rst_n      = 1'b0;
        in_valid   = 1'b0;
        msg_in     = '0;
        msg_length = 8'd0;
        pass_count = 0;

        repeat (4) @(negedge clk);
        rst_n = 1'b1;
        repeat (2) @(negedge clk);

        message = '0;
        run_case("empty", 0, message,
                 256'h4a43f8804b0ad882fa493be44dff80f562d661a05647c15166d71ebff8c6ffa7);

        message = '0;
        message[0*8 +: 8] = 8'h61;
        message[1*8 +: 8] = 8'h62;
        message[2*8 +: 8] = 8'h63;
        run_case("abc", 3, message,
                 256'h3215431145e2bf465b529d3e6e085f85bd90d36b2d175c04b225e24fa75d983a);

        message = '0;
        message[0 +: 8] = 8'hff;
        run_case("one_ff", 1, message,
                 256'h42a4ecee176aa48cf52622c72f82a0bc233afdde198fc95dec5a39ceec894b44);

        message = '0;
        for (int i = 0; i < 135; i++) begin
            message[i*8 +: 8] = i[7:0];
        end
        run_case("rate_minus_1", 135, message,
                 256'he2d5315247b9c9a9aae9b715d0d1aad8cfe5c56b7c3beb1e601c55d6d98fedfd);

        $display("[PASS] All %0d SHA3-256 top-level cases passed.", pass_count);
        #20;
        $finish;

        $display("[PASS] All %0d SHA3-256 top-level cases passed.", pass_count);
        #20;
        $finish;
    end

endmodule