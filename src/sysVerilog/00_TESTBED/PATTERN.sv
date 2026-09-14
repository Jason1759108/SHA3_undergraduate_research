`timescale 1ns/1ps

module PATTERN #(
    // 使用者可直接修改或在實例化時覆寫此參數。
    parameter real CLK_PERIOD_NS = 10.0
) (
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

int              pass_count;
longint unsigned sim_cycle;

// ------------------------------------------------------------------------
// 時脈產生
// ------------------------------------------------------------------------
initial clk = 1'b0;
always #(CLK_PERIOD_NS / 2.0) clk = ~clk;

initial sim_cycle = 0;

always @(posedge clk) begin
    if (!rst_n)
        sim_cycle <= 0;
    else
        sim_cycle <= sim_cycle + 1;
end


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
    int           timeout_cycles;
    int           timeout_limit;
    int           permutation_count;

    int           total_bytes;
    int           offset;
    int           bytes_remaining;
    int           current_block_len;

    longint unsigned start_cycle;
    longint unsigned end_cycle;
    longint unsigned latency_cycles;

    real          elapsed_ns;
    real          throughput_mbps;

    bit           measurement_started;

    logic [1087:0] block_data;
    logic          is_last_block;

    begin

        digest             = '0;
        word_count         = 0;
        timeout_cycles     = 0;
        start_cycle        = 0;
        end_cycle          = 0;
        latency_cycles     = 0;
        elapsed_ns         = 0.0;
        throughput_mbps    = 0.0;
        measurement_started = 1'b0;

        total_bytes = msg_bytes.size();
        offset      = 0;

        // SHA3 padding guarantees one final permutation, including empty and
        // exact-rate messages.
        permutation_count = (total_bytes / 136) + 1;
        timeout_limit      = permutation_count * 1000 + 1000;


        // =================================================================
        // Empty Message (0 bytes)
        // =================================================================
        if (total_bytes == 0) begin

            wait (in_ready === 1'b1);

            @(posedge clk);
            #1;

            msg_in     = '0;
            msg_length = 8'd0;
            in_last    = 1'b1;
            in_valid   = 1'b1;

            @(posedge clk);
            #1;

            start_cycle         = sim_cycle;
            measurement_started = 1'b1;

            msg_in     = '0;
            msg_length = 8'd0;
            in_last    = 1'b0;
            in_valid   = 1'b0;

        end
        else begin

            // =================================================================
            // Non-empty Message
            // =================================================================
            while (offset < total_bytes) begin

                bytes_remaining = total_bytes - offset;

                if (bytes_remaining > 136) begin
                    current_block_len = 136;
                    is_last_block     = 1'b0;
                end
                else begin
                    current_block_len = bytes_remaining;
                    is_last_block     = 1'b1;
                end


                // ----------------------------------------------------------------
                // 將 byte 填入 1088-bit (136-byte) msg_in
                // ----------------------------------------------------------------
                block_data = '0;

                for (int i = 0; i < current_block_len; i++) begin
                    block_data[i*8 +: 8] =
                        msg_bytes[offset + i];
                end


                // ----------------------------------------------------------------
                // 等待 DUT 準備好接收資料
                // ----------------------------------------------------------------
                wait (in_ready === 1'b1);

                @(posedge clk);
                #1;

                msg_in     = block_data;
                msg_length = current_block_len[7:0];
                in_last    = is_last_block;
                in_valid   = 1'b1;


                // ----------------------------------------------------------------
                // DUT 在下一個 posedge 接收資料
                // ----------------------------------------------------------------
                @(posedge clk);
                #1;

                if (!measurement_started) begin
                    start_cycle         = sim_cycle;
                    measurement_started = 1'b1;
                end

                msg_in     = '0;
                msg_length = 8'd0;
                in_last    = 1'b0;
                in_valid   = 1'b0;

                offset += current_block_len;

            end

        end


        // =================================================================
        // 等待並收集 8 個 32-bit out_data
        // =================================================================
        while (hash_done !== 1'b1) begin

            @(negedge clk);

            if (out_valid) begin

                if (word_count < 8) begin
                    digest[word_count*32 +: 32] = out_data;
                end

                word_count++;

            end

            timeout_cycles++;

            if (timeout_cycles > timeout_limit) begin

                $display(
                    "[FAIL] %0s timeout waiting for hash_done (wait_cycles=%0d, limit=%0d)",
                    case_name,
                    timeout_cycles,
                    timeout_limit
                );

                $finish;

            end

        end

        end_cycle      = sim_cycle;
        latency_cycles = end_cycle - start_cycle;
        elapsed_ns     = latency_cycles * CLK_PERIOD_NS;

        if ((total_bytes > 0) && (elapsed_ns > 0.0)) begin
            throughput_mbps =
                (total_bytes * 8.0 * 1000.0) / elapsed_ns;
        end


        // =================================================================
        // 檢測輸出的 32-bit word 數量
        // =================================================================
        if (word_count != 8) begin

            $display(
                "[FAIL] %0s expected 8 output words, got %0d",
                case_name,
                word_count
            );

            $finish;

        end


        // =================================================================
        // 檢測最終 Digest
        // =================================================================
        if (digest !== expected_digest) begin

            $display(
                "[FAIL] %0s digest mismatch",
                case_name
            );

            $display(
                "       expected = %064h",
                expected_digest
            );

            $display(
                "       got      = %064h",
                digest
            );

            $finish;

        end


        pass_count++;

        if (total_bytes == 0) begin
            $display(
                "[PASS] %0s len=%0d bytes latency=%0d cycles time=%0.3f ns throughput=N/A digest=%064h",
                case_name,
                total_bytes,
                latency_cycles,
                elapsed_ns,
                digest
            );
        end
        else begin
            $display(
                "[PASS] %0s len=%0d bytes latency=%0d cycles time=%0.3f ns throughput=%0.3f Mbps digest=%064h",
                case_name,
                total_bytes,
                latency_cycles,
                elapsed_ns,
                throughput_mbps,
                digest
            );
        end

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

    run_bytes_case(
        s,
        msg_bytes,
        expected_digest
    );

endtask


// ------------------------------------------------------------------------
// Helper Task: 重複 Byte Pattern
// ------------------------------------------------------------------------
task automatic run_pattern_case(
    input string        case_name,
    input int           len,
    input byte          pattern_type,
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

    run_bytes_case(
        case_name,
        msg_bytes,
        expected_digest
    );

endtask


// ------------------------------------------------------------------------
// 主測試流程 (17 個功能案例 + 1 個 throughput 案例)
// ------------------------------------------------------------------------
initial begin

    // --------------------------------------------------------------------
    // 初始狀態與 Reset
    // --------------------------------------------------------------------
    rst_n      = 1'b0;
    in_valid   = 1'b0;
    msg_in     = '0;
    msg_length = 8'd0;
    in_last    = 1'b0;

    pass_count = 0;

    repeat (4) @(negedge clk);

    rst_n = 1'b1;

    repeat (2) @(negedge clk);


    // --------------------------------------------------------------------
    // Start
    // --------------------------------------------------------------------
    $display("");
    $display("==================================================");
    $display("   STARTING SHA3-256 MULTI-BLOCK VERIFICATION");
    $display(
        "   All following tests use Clock Period = %0.3f ns",
        CLK_PERIOD_NS
    );
    $display("==================================================");
    $display("");


    // ====================================================================
    // [Case 1] Empty Message
    // ====================================================================
    run_pattern_case(
        "empty",
        0,
        0,
        8'h00,
        256'h4a43f8804b0ad882fa493be44dff80f562d661a05647c15166d71ebff8c6ffa7
    );


    // ====================================================================
    // [Case 2] 1 byte 0xFF
    // ====================================================================
    run_pattern_case(
        "one_ff",
        1,
        1,
        8'hff,
        256'h42a4ecee176aa48cf52622c72f82a0bc233afdde198fc95dec5a39ceec894b44
    );


    // ====================================================================
    // [Case 3] Short Strings
    // ====================================================================
    run_string_case(
        "abc",
        256'h3215431145e2bf465b529d3e6e085f85bd90d36b2d175c04b225e24fa75d983a
    );

    run_string_case(
        "hello",
        256'h92f3982320b9f42a794d424fb888a8536468f0cd86498138f3c5504f69be3833
    );

    run_string_case(
        "sha3",
        256'h150070d51fbc334720d6a58b10747734c4d3623ff00842412fc6e5bfed908c6f
    );

    run_string_case(
        "1234567890",
        256'h63a174f343909111d46aa7d0cb1d3967921c5fd4625ac1a53a9176e94388da01
    );

    run_string_case(
        "SystemVerilog",
        256'h9c7c0f42b0680e064ac0ee3698c558900964230a741b221d3845f6a77e6a1989
    );

    run_string_case(
        "0123456789abcdef",
        256'h1fa00d4b2db4622033af6831c415a1302f9a705b0767f6acdbb5fde9aa4cdfa5
    );


    // ====================================================================
    // [Case 4] Single Block Max Payload (135 bytes)
    // ====================================================================
    run_pattern_case(
        "rate_minus_1",
        135,
        0,
        8'h00,
        256'he2d5315247b9c9a9aae9b715d0d1aad8cfe5c56b7c3beb1e601c55d6d98fedfd
    );

    run_pattern_case(
        "135_bytes_0xAA",
        135,
        1,
        8'hAA,
        256'hb196674fdc873448ca2e26e430289177b9e783b4047b1bf6352c83b97686d0eb
    );


    // ====================================================================
    // [Case 5] Exact Block Boundary (136 bytes)
    // ====================================================================
    run_pattern_case(
        "exact_136_bytes",
        136,
        0,
        8'h00,
        256'he530498c3fe7df5769108817eebf4947e130c41783d3c26091a28024f9cf3ccf
    );

    run_pattern_case(
        "136_bytes_0xAA",
        136,
        1,
        8'hAA,
        256'h24bd65fda7fca7a3eda7216ef3f33a244f7d8efc94dbe3c42b33cc38e18a276f
    );


    // ====================================================================
    // [Case 6] Multi-Block Boundary (137 bytes)
    // ====================================================================
    run_pattern_case(
        "multi_137_bytes",
        137,
        0,
        8'h00,
        256'hcada8480ee830adc07ed18ef9b27d6c652539a47195074925dee1309c97d9dce
    );

    run_pattern_case(
        "137_bytes_0xAA",
        137,
        1,
        8'hAA,
        256'hb80e29a67f283986966629d66608d419bf34c4e8721c088325b7069108c7919c
    );


    // ====================================================================
    // [Case 7] Multi-Block Exact Multiple (272 bytes)
    // ====================================================================
    run_pattern_case(
        "exact_272_bytes",
        272,
        0,
        8'h00,
        256'hb57d57648ea3305c9f41bf3f92e0245b5108abe09fba099e176dff8e4aec210b
    );


    // ====================================================================
    // [Case 8] Multi-Block General Length (300 bytes)
    // ====================================================================
    run_pattern_case(
        "multi_300_bytes",
        300,
        0,
        8'h00,
        256'h0181c534465d2d970c64a561630ef08b55bc475f3ad3ad61ce2085ebbb065c81
    );


    // ====================================================================
    // [Case 9] Long String Multi-Block
    // ====================================================================
    run_string_case(
        "The quick brown fox jumps over the lazy dog. The quick brown fox jumps over the lazy dog. The quick brown fox jumps over the lazy dog. The quick brown fox jumps over the lazy dog. ",
        256'hf017475e75626680ae0bbd8852bad4dbb00e85a0f9c3f024e70f99f206157ba8
    );


    // ====================================================================
    // [Throughput] 4096-byte deterministic payload
    // Byte i = i mod 256. 31 Keccak permutations including final padding.
    // ====================================================================
    run_pattern_case(
        "throughput_4096_bytes",
        4096,
        0,
        8'h00,
        256'h83ec70ca871e4398e046c14ef4bb9c100187c3e7e36513a3a2ff5ce6ceb4b3ee
    );


    // ====================================================================
    // Finish
    // ====================================================================
    $display("");
    $display("==================================================");
    $display(
        "[SUCCESS] All %0d SHA3-256 test cases passed!",
        pass_count
    );
    $display("==================================================");
    $display("");

    #20;

    $finish;

end

endmodule
