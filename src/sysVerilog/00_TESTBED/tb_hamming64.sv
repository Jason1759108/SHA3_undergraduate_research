`timescale 1ns/1ps

// =============================================================================
// Person B / Phase 2
// -----------------------------------------------------------------------------
// 這個檔只測 (72,64) SECDED 編解碼，不進正式 PATTERN、不進合成、不進 filelist.f。
// 測完 Hamming 單元後再接到 top。θ / χ / scheduler 這一 phase 不准動。
//
// 怎麼跑（工作站，A 的 keccak_hamming64.sv 要在同一 filelist 裡）：
//   編譯：sha3_pkg.sv + keccak_hamming64.sv + 本檔
//   頂層 module 就是 tb_hamming64（不要用 TESTBED）
// =============================================================================
import sha3_pkg::*;

module tb_hamming64;

    logic [FT_DATA_W-1:0] data_in;
    logic [FT_CODE_W-1:0] code_out;
    logic [FT_CODE_W-1:0] code_in;
    logic [FT_DATA_W-1:0] data_out;
    logic [FT_HAM_P-1:0]  syndrome;
    logic                 ext_fail;
    ft_status_e           status;

    keccak_hamming64 u_dut (
        .data_in  (data_in),
        .code_out (code_out),
        .code_in  (code_in),
        .data_out (data_out),
        .syndrome (syndrome),
        .ext_fail (ext_fail),
        .status   (status)
    );

    int unsigned fail_n;
    int unsigned pass_n;
    bit          case_bad;

    function automatic logic [FT_CODE_W-1:0] ft_flip_pos(
        input logic [FT_CODE_W-1:0] code,
        input int                   pos
    );
        logic [FT_CODE_W-1:0] out_code;
        out_code = code;
        if ((pos >= 1) && (pos <= FT_CODE_W))
            out_code[pos-1] = ~out_code[pos-1];
        return out_code;
    endfunction

    task automatic start_case();
        case_bad = 1'b0;
    endtask

    task automatic fail_msg(input string msg);
        case_bad = 1'b1;
        $error("[FAIL] %s", msg);
    endtask

    // 一次 decode 算一筆：有任何條件錯 → fail_n+1，全過 → pass_n+1
    task automatic end_case(input string tag);
        if (case_bad) begin
            fail_n++;
            $display("[FAIL] %s", tag);
        end
        else begin
            pass_n++;
        end
    endtask

    task automatic check_clean(input logic [FT_DATA_W-1:0] data, input string tag);
        begin
            start_case();
            data_in = data;
            #1;
            code_in = code_out;
            #1;
            if (status != FT_ST_OK) fail_msg("status != FT_ST_OK");
            if (data_out != data) fail_msg("data_out != data");
            if (syndrome != 0) fail_msg("syndrome != 0");
            if (ext_fail != 0) fail_msg("ext_fail != 0");
            end_case($sformatf("check_clean %s data=%h", tag, data));
        end
    endtask

    task automatic check_flip_each_data_bit(input logic [FT_DATA_W-1:0] data, input string tag);
        int d;
        int pos;
        begin
            for (d = 0; d < FT_DATA_W; d++) begin
                start_case();
                pos = ft_data_pos(d);
                data_in = data;
                #1;
                code_in = ft_flip_pos(code_out, pos);
                #1;
                if (status != FT_ST_CORRECTED) fail_msg("status != FT_ST_CORRECTED");
                if (data_out != data) fail_msg("data_out != data");
                if (syndrome != pos) fail_msg("syndrome != pos");
                end_case($sformatf("flip_data %s d=%0d pos=%0d", tag, d, pos));
            end
            $display("[DONE] check_flip_each_data_bit %s", tag);
        end
    endtask

    task automatic check_flip_each_parity_bit(input logic [FT_DATA_W-1:0] data, input string tag);
        int i;
        int pos;
        begin
            data_in = data;
            #1;
            for (i = 0; i < FT_HAM_P; i++) begin
                start_case();
                pos = FT_HAM_POS[i];
                code_in = ft_flip_pos(code_out, pos);
                #1;
                if (status != FT_ST_CORRECTED) fail_msg("status != FT_ST_CORRECTED");
                if (data_out != data) fail_msg("data_out != data");
                if (syndrome != pos) fail_msg("syndrome != pos");
                end_case($sformatf("flip_ham %s pos=%0d", tag, pos));
            end
            start_case();
            code_in = ft_flip_pos(code_out, FT_EXT_POS);
            #1;
            if (status != FT_ST_CORRECTED) fail_msg("status != FT_ST_CORRECTED");
            if (data_out != data) fail_msg("data_out != data");
            if (syndrome != 0) fail_msg("syndrome != 0");
            if (ext_fail != 1) fail_msg("ext_fail != 1");
            end_case($sformatf("flip_pext %s", tag));
            $display("[DONE] check_flip_each_parity_bit %s", tag);
        end
    endtask

    task automatic check_two_bit_errors(input logic [FT_DATA_W-1:0] data, input string tag);
        int i;
        int r1, r2;
        begin
            data_in = data;
            #1;

            start_case();
            code_in = ft_flip_pos(ft_flip_pos(code_out, FT_DATA_POS[6]), FT_DATA_POS[7]);
            #1;
            if (status != FT_ST_UNCORR) fail_msg("status != FT_ST_UNCORR");
            end_case($sformatf("two_bit data+data %s", tag));

            start_case();
            code_in = ft_flip_pos(ft_flip_pos(code_out, FT_DATA_POS[25]), FT_HAM_POS[3]);
            #1;
            if (status != FT_ST_UNCORR) fail_msg("status != FT_ST_UNCORR");
            end_case($sformatf("two_bit data+ham %s", tag));

            start_case();
            code_in = ft_flip_pos(ft_flip_pos(code_out, FT_HAM_POS[5]), FT_HAM_POS[6]);
            #1;
            if (status != FT_ST_UNCORR) fail_msg("status != FT_ST_UNCORR");
            end_case($sformatf("two_bit ham+ham %s", tag));

            for (i = 0; i < 17; i++) begin
                start_case();
                r1 = $urandom_range(1, FT_EXT_POS);
                r2 = $urandom_range(1, FT_EXT_POS);
                while (r1 == r2)
                    r2 = $urandom_range(1, FT_EXT_POS);
                code_in = ft_flip_pos(ft_flip_pos(code_out, r1), r2);
                #1;
                if (status != FT_ST_UNCORR) fail_msg("status != FT_ST_UNCORR");
                end_case($sformatf("two_bit rnd %s p=%0d,%0d", tag, r1, r2));
            end
            $display("[DONE] check_two_bit_errors %s", tag);
        end
    endtask

    initial begin
        int                 k;
        logic [FT_DATA_W-1:0] rnd;

        pass_n  = 0;
        fail_n  = 0;
        data_in = '0;
        code_in = '0;

        check_clean(64'h0,                    "zeros");
        check_clean(64'hFFFF_FFFF_FFFF_FFFF,  "ones");
        check_clean(64'hDEAD_BEEF_0123_4567,  "deadbeef");

        check_flip_each_data_bit(64'h0,                   "zeros");
        check_flip_each_data_bit(64'hFFFF_FFFF_FFFF_FFFF, "ones");
        check_flip_each_data_bit(64'hDEAD_BEEF_0123_4567, "deadbeef");

        check_flip_each_parity_bit(64'h0,                   "zeros");
        check_flip_each_parity_bit(64'hFFFF_FFFF_FFFF_FFFF, "ones");
        check_flip_each_parity_bit(64'hDEAD_BEEF_0123_4567, "deadbeef");

        check_two_bit_errors(64'h0,                   "zeros");
        check_two_bit_errors(64'hDEAD_BEEF_0123_4567, "deadbeef");

        for (k = 0; k < 20; k++) begin
            rnd = {32'($urandom()), 32'($urandom())};
            check_clean(rnd, $sformatf("random_%0d", k));
            check_flip_each_data_bit(rnd, $sformatf("random_%0d", k));
            check_flip_each_parity_bit(rnd, $sformatf("random_%0d", k));
            check_two_bit_errors(rnd, $sformatf("random_%0d", k));
        end

        $display("[tb_hamming64] pass=%0d fail=%0d", pass_n, fail_n);
        if (fail_n != 0)
            $fatal(1, "tb_hamming64 failed");
        $finish;
    end

endmodule
