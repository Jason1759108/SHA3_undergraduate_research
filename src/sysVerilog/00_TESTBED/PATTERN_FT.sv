`timescale 1ns/1ps

`ifdef FT_PATTERN

// =============================================================================
// PATTERN_FT — Keccak-f lane Hamming injection
// -----------------------------------------------------------------------------
// 不要拿這個檔取代原本 PATTERN.sv。無注入回歸仍用：
//   make vcs_rtl
// 注入測試：
//   make vcs_rtl_ft
//   或  make vcs_rtl define=FT_PATTERN
//
// 規則（寫死）：
//   1. 只在 keccak-f 且 lane_active[i]=1 的當拍，對 72-bit codeword XOR mask。
//   2. 同一輪 Keccak-f 最多注入 1 次。
//   3. 1-bit：CORRECTED、fault_valid=0、extra cycle=0、hash 對。
//   4. 2-bit：UNCORR → T hold、T+1 replay、hash 對。
// =============================================================================

import sha3_pkg::*;

module PATTERN_FT #(
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
    input  logic          hash_done,

    output logic          ft_inject_valid,
    output logic [4:0]    ft_inject_lane,
    output logic [71:0]   ft_inject_mask,
    output logic          ft_d_inject_valid,
    output logic [2:0]    ft_d_inject_col,
    output logic [71:0]   ft_d_inject_mask
);

    localparam logic [255:0] EMPTY_DIGEST =
        256'h4a43f8804b0ad882fa493be44dff80f562d661a05647c15166d71ebff8c6ffa7;

    typedef enum int {
        PT_NONE,
        PT_THETA_COL0,
        PT_THETA_COL3,
        PT_CHI_ROW0,
        PT_CHI_ROW3,
        PT_CHI_LAST,
        PT_THETA_COL3_D
    } inject_point_e;

    int              pass_count;
    longint unsigned sim_cycle;
    int              baseline_f_cycles;
    bit              case_fail;

    inject_point_e   cfg_point;
    int              cfg_nbit;
    logic [4:0]      cfg_lane;
    logic [2:0]      cfg_d_col;
    logic [71:0]     cfg_mask;
    ft_replay_e      cfg_expect_kind;
    bit              cfg_use_d;

    bit              saw_inject;
    bit              saw_hold;
    bit              saw_replay;
    bit              saw_fault;
    ft_status_e      saw_status;
    ft_replay_e      saw_kind;
    int              saw_active_n;
    int              f_cycles;
    bit              in_perm;

    initial clk = 1'b0;
    always #(CLK_PERIOD_NS / 2.0) clk = ~clk;

    initial sim_cycle = 0;
    always @(posedge clk) begin
        if (!rst_n)
            sim_cycle <= 0;
        else
            sim_cycle <= sim_cycle + 1;
    end

    // Hierarchical monitors (TESTBED.u_sha3_top).
    wire        dut_start_process    = TESTBED.u_sha3_top.start_process;
    wire        dut_process_done     = TESTBED.u_sha3_top.process_done;
    wire        dut_theta_start      = TESTBED.u_sha3_top.theta_start;
    wire        dut_theta_compute_d  = TESTBED.u_sha3_top.theta_compute_d;
    wire [2:0]  dut_theta_col        = TESTBED.u_sha3_top.theta_col;
    wire [24:0] dut_theta_lane_active= TESTBED.u_sha3_top.theta_lane_active;
    wire        dut_chi_start        = TESTBED.u_sha3_top.chi_start;
    wire [2:0]  dut_chi_cnt          = TESTBED.u_sha3_top.chi_cnt;
    wire [24:0] dut_chi_lane_active  = TESTBED.u_sha3_top.chi_lane_active;
    wire [4:0]  dut_round_index      = TESTBED.u_sha3_top.round_index;
    wire        dut_fault_valid      = TESTBED.u_sha3_top.fault_valid;
    wire        dut_theta_hold       = TESTBED.u_sha3_top.theta_hold;
    wire        dut_chi_hold         = TESTBED.u_sha3_top.chi_hold;
    wire        dut_theta_replay     = TESTBED.u_sha3_top.theta_replay;
    wire        dut_chi_replay       = TESTBED.u_sha3_top.chi_replay;
    wire [24:0] dut_state_active     = TESTBED.u_sha3_top.state_active_mask;

    function automatic int popcount25(input logic [24:0] bits);
        int n;
        n = 0;
        for (int i = 0; i < 25; i++)
            if (bits[i]) n++;
        return n;
    endfunction

    function automatic bit point_hit();
        case (cfg_point)
            PT_THETA_COL0:
                return dut_theta_start && dut_theta_compute_d;
            PT_THETA_COL3,
            PT_THETA_COL3_D:
                return (dut_theta_lane_active != 25'd0) &&
                       (dut_theta_col == 3'd3) &&
                       !dut_theta_compute_d;
            PT_CHI_ROW0:
                return dut_chi_start;
            PT_CHI_ROW3:
                return (dut_chi_lane_active != 25'd0) && (dut_chi_cnt == 3'd3);
            PT_CHI_LAST:
                return (dut_chi_lane_active != 25'd0) &&
                       (dut_round_index == 5'd23) &&
                       (dut_chi_cnt == 3'd4);
            default:
                return 1'b0;
        endcase
    endfunction

    function automatic string kind_name(input ft_replay_e k);
        case (k)
            FT_REPLAY_NONE:         return "NONE";
            FT_REPLAY_THETA_COL:    return "THETA_COL";
            FT_REPLAY_THETA_CD:     return "THETA_CD";
            FT_REPLAY_THETA_FROM0:  return "THETA_FROM0";
            FT_REPLAY_CHI_ROW:      return "CHI_ROW";
            default:                return "?";
        endcase
    endfunction

    function automatic string status_name(input ft_status_e s);
        case (s)
            FT_ST_OK:        return "OK";
            FT_ST_CORRECTED: return "CORRECTED";
            FT_ST_UNCORR:    return "UNCORR";
            default:         return "?";
        endcase
    endfunction

    task automatic fail_now(input string msg);
        case_fail = 1'b1;
        $display("[FAIL] %s", msg);
    endtask

    always @(posedge clk) begin
        if (!rst_n) begin
            in_perm   <= 1'b0;
            f_cycles  <= 0;
        end
        else if (dut_start_process) begin
            in_perm   <= 1'b1;
            f_cycles  <= 0;
        end
        else if (in_perm) begin
            f_cycles <= f_cycles + 1;
            if (dut_process_done)
                in_perm <= 1'b0;
        end
    end

    task automatic apply_reset();
        rst_n            = 1'b0;
        in_valid         = 1'b0;
        msg_in           = '0;
        msg_length       = 8'd0;
        in_last          = 1'b0;
        ft_inject_valid  = 1'b0;
        ft_inject_lane   = 5'd0;
        ft_inject_mask   = 72'd0;
        ft_d_inject_valid= 1'b0;
        ft_d_inject_col  = 3'd0;
        ft_d_inject_mask = 72'd0;
        repeat (4) @(negedge clk);
        rst_n = 1'b1;
        repeat (2) @(negedge clk);
    endtask

    task automatic drive_empty_msg();
        wait (in_ready === 1'b1);
        @(posedge clk);
        #1;
        msg_in     = '0;
        msg_length = 8'd0;
        in_last    = 1'b1;
        in_valid   = 1'b1;
        @(posedge clk);
        #1;
        msg_in     = '0;
        msg_length = 8'd0;
        in_last    = 1'b0;
        in_valid   = 1'b0;
    endtask

    task automatic collect_digest(output logic [255:0] digest);
        int word_count;
        int timeout_cycles;
        digest      = '0;
        word_count  = 0;
        timeout_cycles = 0;
        while (hash_done !== 1'b1) begin
            @(negedge clk);
            if (out_valid) begin
                if (word_count < 8)
                    digest[word_count*32 +: 32] = out_data;
                word_count++;
            end
            timeout_cycles++;
            if (timeout_cycles > 4000) begin
                fail_now("timeout waiting for hash_done");
                $finish;
            end
        end
        if (word_count != 8)
            fail_now($sformatf("expected 8 output words, got %0d", word_count));
    endtask

    task automatic inject_monitor();
        int wait_cyc;

        saw_inject   = 1'b0;
        saw_hold     = 1'b0;
        saw_replay   = 1'b0;
        saw_fault    = 1'b0;
        saw_status   = FT_ST_OK;
        saw_kind     = FT_REPLAY_NONE;
        saw_active_n = 0;
        wait_cyc     = 0;

        if (cfg_point == PT_NONE)
            return;
        while (!saw_inject) begin
            @(posedge clk);
            #1;
            wait_cyc++;
            if (wait_cyc > 4000) begin
                fail_now("timeout waiting for injection window");
                return;
            end
            if (hash_done === 1'b1) begin
                fail_now("hash_done before injection window");
                return;
            end
            if (point_hit()) begin
                if (cfg_use_d) begin
                    ft_d_inject_valid = 1'b1;
                    ft_d_inject_col   = cfg_d_col;
                    ft_d_inject_mask  = cfg_mask;
                end
                else begin
                    if (!dut_state_active[cfg_lane]) begin
                        fail_now("inject lane is not active");
                        return;
                    end
                    ft_inject_valid = 1'b1;
                    ft_inject_lane  = cfg_lane;
                    ft_inject_mask  = cfg_mask;
                end
                #1;
                saw_inject   = 1'b1;
                saw_kind     = TESTBED.u_sha3_top.replay_kind;
                saw_fault    = dut_fault_valid;
                saw_hold     = dut_theta_hold || dut_chi_hold;
                saw_active_n = popcount25(dut_theta_lane_active | dut_chi_lane_active);
                if (cfg_use_d)
                    saw_status = TESTBED.u_sha3_top.theta_d_status[cfg_d_col];
                else
                    saw_status = TESTBED.u_sha3_top.lane_status[cfg_lane];
            end
        end

        @(posedge clk);
        #1;
        ft_inject_valid   = 1'b0;
        ft_d_inject_valid = 1'b0;
        saw_replay        = dut_theta_replay || dut_chi_replay;
        if (popcount25(dut_theta_lane_active | dut_chi_lane_active) > 5)
            fail_now("replay cycle has more than 5 active lanes");
    endtask

    task automatic run_ft_case(
        input string        case_name,
        input inject_point_e point,
        input int           nbit,
        input logic [4:0]   lane,
        input logic [2:0]   d_col,
        input bit           use_d,
        input logic [71:0]  mask,
        input ft_replay_e   expect_kind
    );
        logic [255:0] digest;
        int extra;

        cfg_point       = point;
        cfg_nbit        = nbit;
        cfg_lane        = lane;
        cfg_d_col       = d_col;
        cfg_use_d       = use_d;
        cfg_mask        = mask;
        cfg_expect_kind = expect_kind;
        case_fail       = 1'b0;

        apply_reset();

        fork
            drive_empty_msg();
            inject_monitor();
        join

        collect_digest(digest);

        extra = f_cycles - baseline_f_cycles;

        if (digest !== EMPTY_DIGEST)
            fail_now($sformatf("digest mismatch extra=%0d", extra));

        if (point != PT_NONE) begin
            if (!saw_inject)
                fail_now("never hit injection window");

            if (saw_active_n > 5)
                fail_now($sformatf("inject cycle active lanes=%0d", saw_active_n));

            if (nbit == 1) begin
                if (saw_status != FT_ST_CORRECTED)
                    fail_now($sformatf("1-bit status=%s, want CORRECTED",
                                      status_name(saw_status)));
                if (saw_fault)
                    fail_now("1-bit saw fault_valid");
                if (saw_hold)
                    fail_now("1-bit must not hold");
                if (saw_replay)
                    fail_now("1-bit must not replay");
                if (extra != 0)
                    fail_now($sformatf("1-bit extra=%0d, want 0", extra));
            end
            else begin
                if (saw_status != FT_ST_UNCORR)
                    fail_now($sformatf("2-bit status=%s, want UNCORR",
                                      status_name(saw_status)));
                if (!saw_fault)
                    fail_now("2-bit missing fault_valid");
                if (saw_kind != expect_kind)
                    fail_now($sformatf("replay_kind=%s, want %s",
                                      kind_name(saw_kind),
                                      kind_name(expect_kind)));
                if (!saw_hold)
                    fail_now("2-bit missing hold on inject cycle");
                if (!saw_replay)
                    fail_now("2-bit missing replay on T+1");
                if (extra < 1)
                    fail_now($sformatf("2-bit extra=%0d, want >=1", extra));
                if ((expect_kind == FT_REPLAY_CHI_ROW) ||
                    (expect_kind == FT_REPLAY_THETA_COL) ||
                    (expect_kind == FT_REPLAY_THETA_CD)) begin
                    if (extra != 1)
                        fail_now($sformatf("%s extra=%0d, want 1",
                                          kind_name(expect_kind), extra));
                end
                if (expect_kind == FT_REPLAY_THETA_FROM0) begin
                    if (extra > 5)
                        fail_now($sformatf("FROM0 extra=%0d, want <=5", extra));
                end
            end
        end

        if (case_fail) begin
            $display(
                "[FAIL] %s nbit=%0d f_cycles=%0d extra=%0d status=%s kind=%s digest=%064h",
                case_name, nbit, f_cycles, extra,
                status_name(saw_status), kind_name(saw_kind), digest
            );
            $finish;
        end

        pass_count++;
        $display(
            "[PASS] %s nbit=%0d f_cycles=%0d extra=%0d status=%s kind=%s hold=%0d replay=%0d",
            case_name, nbit, f_cycles, extra,
            status_name(saw_status), kind_name(saw_kind), saw_hold, saw_replay
        );
        @(negedge clk);
    endtask

    initial begin
        pass_count        = 0;
        baseline_f_cycles = 0;
        cfg_point         = PT_NONE;

        $display("");
        $display("==================================================");
        $display("   SHA3-256 FAULT-INJECTION VERIFICATION");
        $display("==================================================");
        $display("");

        run_ft_case("baseline_no_inject", PT_NONE, 0, 5'd0, 3'd0, 1'b0,
                    72'd0, FT_REPLAY_NONE);
        baseline_f_cycles = f_cycles;
        $display("[INFO] baseline keccak-f cycles (start_process..process_done) = %0d",
                 baseline_f_cycles);

        // 1-bit data position 3 → code[2]
        run_ft_case("theta_col0_1bit", PT_THETA_COL0, 1, 5'd0, 3'd0, 1'b0,
                    72'h1 << 2, FT_REPLAY_NONE);
        run_ft_case("theta_col3_1bit", PT_THETA_COL3, 1, 5'd3, 3'd0, 1'b0,
                    72'h1 << 2, FT_REPLAY_NONE);
        run_ft_case("chi_row0_1bit", PT_CHI_ROW0, 1, 5'd0, 3'd0, 1'b0,
                    72'h1 << 2, FT_REPLAY_NONE);
        run_ft_case("chi_row3_1bit", PT_CHI_ROW3, 1, 5'd15, 3'd0, 1'b0,
                    72'h1 << 2, FT_REPLAY_NONE);
        run_ft_case("chi_last_1bit", PT_CHI_LAST, 1, 5'd20, 3'd0, 1'b0,
                    72'h1 << 2, FT_REPLAY_NONE);

        // 2-bit: positions 3 and 5 → code[2], code[4]
        run_ft_case("theta_col0_2bit", PT_THETA_COL0, 2, 5'd0, 3'd0, 1'b0,
                    (72'h1 << 2) | (72'h1 << 4), FT_REPLAY_THETA_COL);
        run_ft_case("theta_col3_2bit", PT_THETA_COL3, 2, 5'd3, 3'd0, 1'b0,
                    (72'h1 << 2) | (72'h1 << 4), FT_REPLAY_THETA_COL);
        run_ft_case("theta_col3_d_2bit", PT_THETA_COL3_D, 2, 5'd0, 3'd3, 1'b1,
                    (72'h1 << 2) | (72'h1 << 4), FT_REPLAY_THETA_FROM0);
        run_ft_case("chi_row0_2bit", PT_CHI_ROW0, 2, 5'd0, 3'd0, 1'b0,
                    (72'h1 << 2) | (72'h1 << 4), FT_REPLAY_CHI_ROW);
        run_ft_case("chi_row3_2bit", PT_CHI_ROW3, 2, 5'd15, 3'd0, 1'b0,
                    (72'h1 << 2) | (72'h1 << 4), FT_REPLAY_CHI_ROW);
        run_ft_case("chi_last_2bit", PT_CHI_LAST, 2, 5'd20, 3'd0, 1'b0,
                    (72'h1 << 2) | (72'h1 << 4), FT_REPLAY_CHI_ROW);

        $display("");
        $display("==================================================");
        $display("[SUCCESS] All %0d FT test cases passed!", pass_count);
        $display("==================================================");
        $display("");
        #20;
        $finish;
    end

endmodule

`endif
