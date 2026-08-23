`timescale 1ns/1ps

module PATTERN (
    output logic          clk,
    output logic          rst_n,
    output logic          in_valid,
    output logic [1087:0] msg_in,
    output logic [7:0]    msg_length,
    output logic          in_last,

    input  logic          in_ready,
    input  logic [31:0]   out_data,
    input  logic          out_valid,
    input  logic          hash_done
);

int pass_count;

// ------------------------------------------------------------------------
// 時脈產生 (10ns 週期)
// ------------------------------------------------------------------------
initial clk = 1'b0;
always #5 clk = ~clk;

// ------------------------------------------------------------------------
// 通用 Multi-Block 測試 Task
// 支援 dynamic byte array，自動切割 136-byte (1088-bit) rate blocks
// ------------------------------------------------------------------------
task automatic run_bytes_case(
    input string        case_name,
    input byte          msg_bytes[],
    input logic [255:0] expected_digest
);
    logic [255:0] digest;
    int           word_count;
    int           cycles;
    int           total_bytes;
    int           offset;
    int           bytes_remaining;
    int           current_block_len;
    logic [1087:0] block_data;
    logic         is_last_block;

    begin
        digest      = '0;
        word_count  = 0;
        cycles      = 0;
        total_bytes = msg_bytes.size();
        offset      = 0;

        // 處理 Empty Message (0 bytes) 特殊情況
        if (total_bytes == 0) begin
            wait (in_ready === 1'b1);
            @(negedge clk);
            msg_in     = '0;
            msg_length = 8'd0;
            in_last    = 1'b1;
            in_valid   = 1'b1;

            @(negedge clk);
            msg_in     = '0;
            msg_length = 8'd0;
            in_last    = 1'b0;
            in_valid   = 1'b0;
        end else begin
            // 處理有資料的 Message (單 Block 或 Multi-Block)
            while (offset < total_bytes) begin
                bytes_remaining = total_bytes - offset;
                if (bytes_remaining > 136) begin
                    current_block_len = 136;
                    is_last_block     = 1'b0;
                end else begin
                    current_block_len = bytes_remaining;
                    is_last_block     = 1'b1;
                end

                // 將 byte 填入 1088-bit (136-byte) msg_in 中
                block_data = '0;
                for (int i = 0; i < current_block_len; i++) begin
                    block_data[i*8 +: 8] = msg_bytes[offset + i];
                end

                // 嚴格 Handshake: 等待 in_ready 為 高準位 (1'b1)
                wait (in_ready === 1'b1);
                @(negedge clk);

                msg_in     = block_data;
                msg_length = current_block_len[7:0];
                in_last    = is_last_block;
                in_valid   = 1'b1;

                @(negedge clk);
                msg_in     = '0;
                msg_length = 8'd0;
                in_last    = 1'b0;
                in_valid   = 1'b0;

                offset += current_block_len;
            end
        end

        // 等待並收集 8 個 32-bit out_data
        while (hash_done !== 1'b1) begin
            @(negedge clk);
            if (out_valid) begin
                if (word_count < 8) begin
                    digest[word_count*32 +: 32] = out_data;
                end
                word_count++;
            end

            cycles++;
            if (cycles > 20000) begin
                $display("[FAIL] %0s timeout waiting for hash_done (cycles=%0d)", case_name, cycles);
                $finish;
            end
        end

        // 檢測輸出的 32-bit word 數量與最終 Digest
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
        $display("[PASS] %0s (len=%0d bytes, cycles=%0d) digest=%064h", case_name, total_bytes, cycles, digest);
        @(negedge clk);
    end
endtask

// ------------------------------------------------------------------------
// Helper Task: 字串轉換
// ------------------------------------------------------------------------
task automatic run_string_case(
    input string        s,
    input logic [255:0] expected_digest
);
    byte msg_bytes[];
    msg_bytes = new[s.len()];
    for (int i = 0; i < s.len(); i++) begin
        msg_bytes[i] = byte'(s[i]);
    end
    run_bytes_case(s, msg_bytes, expected_digest);
endtask

// ------------------------------------------------------------------------
// Helper Task: 重複 Byte Pattern (例如生成 135/136/137/272/300 bytes)
// ------------------------------------------------------------------------
task automatic run_pattern_case(
    input string        case_name,
    input int           len,
    input byte          pattern_type, // 0: 遞增 (0,1,2...), 1: 固定值 (如 0xAA)
    input byte          fill_val,
    input logic [255:0] expected_digest
);
    byte msg_bytes[];
    msg_bytes = new[len];
    for (int i = 0; i < len; i++) begin
        if (pattern_type == 0)
            msg_bytes[i] = i[7:0];
        else
            msg_bytes[i] = fill_val;
    end
    run_bytes_case(case_name, msg_bytes, expected_digest);
endtask

// ------------------------------------------------------------------------
// 主測試流程 (含 17 個涵蓋各種邊界條件的 Test Cases)
// ------------------------------------------------------------------------
initial begin
    // 初始狀態與 Reset
    rst_n      = 1'b0;
    in_valid   = 1'b0;
    msg_in     = '0;
    msg_length = 8'd0;
    in_last    = 1'b0;
    pass_count = 0;

    repeat (4) @(negedge clk);
    rst_n = 1'b1;
    repeat (2) @(negedge clk);

    $display("\n==================================================");
    $display("   STARTING SHA3-256 MULTI-BLOCK VERIFICATION     ");
    $display("==================================================\n");

    // [Case 1] Empty message (0 byte)
    run_pattern_case("empty", 0, 0, 8'h00, 256'h4a43f8804b0ad882fa493be44dff80f562d661a05647c15166d71ebff8c6ffa7);

    // [Case 2] 1 byte
    run_pattern_case("one_ff", 1, 1, 8'hff, 256'h42a4ecee176aa48cf52622c72f82a0bc233afdde198fc95dec5a39ceec894b44);

    // [Case 3] Short strings
    run_string_case("abc", 256'h3215431145e2bf465b529d3e6e085f85bd90d36b2d175c04b225e24fa75d983a);
    run_string_case("hello", 256'h92f3982320b9f42a794d424fb888a8536468f0cd86498138f3c5504f69be3833);
    run_string_case("sha3", 256'h150070d51fbc334720d6a58b10747734c4d3623ff00842412fc6e5bfed908c6f);
    run_string_case("1234567890", 256'h63a174f343909111d46aa7d0cb1d3967921c5fd4625ac1a53a9176e94388da01);
    run_string_case("SystemVerilog", 256'h9c7c0f42b0680e064ac0ee3698c558900964230a741b221d3845f6a77e6a1989);
    run_string_case("0123456789abcdef", 256'h1fa00d4b2db4622033af6831c415a1302f9a705b0767f6acdbb5fde9aa4cdfa5);

    // [Case 4] Single Block Max Payload (135 bytes)
    run_pattern_case("rate_minus_1", 135, 0, 8'h00, 256'he2d5315247b9c9a9aae9b715d0d1aad8cfe5c56b7c3beb1e601c55d6d98fedfd);
    run_pattern_case("135_bytes_0xAA", 135, 1, 8'hAA, 256'hb196674fdc873448ca2e26e430289177b9e783b4047b1bf6352c83b97686d0eb);

    // [Case 5] Exact Block Boundary (136 bytes -> Requires Extra Padding Block)
    run_pattern_case("exact_136_bytes", 136, 0, 8'h00, 256'he530498c3fe7df5769108817eebf4947e130c41783d3c26091a28024f9cf3ccf);
    run_pattern_case("136_bytes_0xAA", 136, 1, 8'hAA, 256'h24bd65fda7fca7a3eda7216ef3f33a244f7d8efc94dbe3c42b33cc38e18a276f);

    // [Case 6] Multi-Block Boundary (137 bytes -> 2 Blocks)
    run_pattern_case("multi_137_bytes", 137, 0, 8'h00, 256'hcada8480ee830adc07ed18ef9b27d6c652539a47195074925dee1309c97d9dce);
    run_pattern_case("137_bytes_0xAA", 137, 1, 8'hAA, 256'hb80e29a67f283986966629d66608d419bf34c4e8721c088325b7069108c7919c);

    // [Case 7] Multi-Block Exact Multiple (272 bytes -> 2 full blocks + Extra Padding Block)
    run_pattern_case("exact_272_bytes", 272, 0, 8'h00, 256'hb57d57648ea3305c9f41bf3f92e0245b5108abe09fba099e176dff8e4aec210b);

    // [Case 8] Multi-Block General Length (300 bytes -> 3 Blocks)
    run_pattern_case("multi_300_bytes", 300, 0, 8'h00, 256'h0181c534465d2d970c64a561630ef08b55bc475f3ad3ad61ce2085ebbb065c81);

    // [Case 9] Long String Multi-Block (180 bytes -> 2 Blocks)
    run_string_case("The quick brown fox jumps over the lazy dog. The quick brown fox jumps over the lazy dog. The quick brown fox jumps over the lazy dog. The quick brown fox jumps over the lazy dog. ", 256'hf017475e75626680ae0bbd8852bad4dbb00e85a0f9c3f024e70f99f206157ba8);

    $display("\n==================================================");
    $display("[SUCCESS] All %0d SHA3-256 test cases passed!", pass_count);
    $display("==================================================\n");
    #20;
    $finish;
end

endmodule