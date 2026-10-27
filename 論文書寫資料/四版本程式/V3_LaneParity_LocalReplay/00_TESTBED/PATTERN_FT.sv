`timescale 1ns/1ps
`ifdef FT_PATTERN
import sha3_pkg::*;
module PATTERN_FT #(parameter real CLK_PERIOD_NS = 10.0) (
    output logic clk, rst_n, in_valid,
    output logic [1087:0] msg_in,
    output logic [7:0] msg_length,
    output logic in_last,
    input logic in_ready,
    input logic [31:0] out_data,
    input logic out_valid, hash_done,
    output logic ft_inject_valid,
    output logic [4:0] ft_inject_lane,
    output logic [63:0] ft_inject_mask,
    output logic ft_c_inject_valid,
    output logic [2:0] ft_c_inject_col,
    output logic [63:0] ft_c_inject_mask,
    output logic ft_d_inject_valid,
    output logic [2:0] ft_d_inject_col,
    output logic [63:0] ft_d_inject_mask
);
    localparam logic [255:0] EMPTY_DIGEST =
        256'h4a43f8804b0ad882fa493be44dff80f562d661a05647c15166d71ebff8c6ffa7;
    int pass_count, fault_count, perm_cycles, baseline_cycles;
    int message_bytes;
    logic counting;
    event case_start;
    bit drive_done, collect_done, inject_done;
    bit cfg_inject, cfg_chi, cfg_use_d, cfg_second, cfg_detectable, cfg_use_c;
    int cfg_index, cfg_round, cfg_lane, cfg_duration;
    logic [63:0] cfg_mask;
    logic [255:0] case_digest;
    // Independent workers avoid simulator-specific fork/task inlining limits.
    initial forever begin
        @case_start;
        drive_message();
        drive_done = 1;
    end
    initial forever begin
        @case_start;
        collect_digest(case_digest);
        collect_done = 1;
    end
    initial forever begin
        @case_start;
        if (cfg_inject) inject_at(cfg_chi,cfg_index,cfg_round,cfg_lane,cfg_use_d,cfg_mask,cfg_duration,cfg_detectable,cfg_use_c);
        if (cfg_second) inject_at(1,3,cfg_round,17,0,64'h1,1,1);
        inject_done = 1;
    end
    initial clk = 0;
    always #(CLK_PERIOD_NS/2) clk = ~clk;
    // Global watchdog catches deadlock even when a forked driver is stuck.
    initial begin
        #(CLK_PERIOD_NS * 200000);
        $fatal(1, "global FT timeout");
    end
    always @(posedge clk) begin
        if (!rst_n) begin
            counting <= 0;
            perm_cycles <= 0;
            fault_count <= 0;
        end else begin
            if (TESTBED.u_sha3_top.fault_valid) fault_count <= fault_count + 1;
            if (TESTBED.u_sha3_top.start_process) counting <= 1;
            else if (counting) begin
                perm_cycles <= perm_cycles + 1;
                if (TESTBED.u_sha3_top.process_done) counting <= 0;
            end
        end
    end
    task automatic reset_dut();
        rst_n = 0;
        in_valid = 0; msg_in = '0; msg_length = 0; in_last = 0;
        ft_inject_valid = 0; ft_inject_lane = 0; ft_inject_mask = 0;
        ft_c_inject_valid = 0; ft_c_inject_col = 0; ft_c_inject_mask = 0;
        ft_d_inject_valid = 0; ft_d_inject_col = 0; ft_d_inject_mask = 0;
        repeat (4) @(negedge clk);
        rst_n = 1;
        repeat (2) @(negedge clk);
    endtask
    task automatic drive_message();
        int offset, length;
        offset = 0;
        do begin
            @(negedge clk);
            while (!in_ready) @(negedge clk);
            length = message_bytes - offset;
            if (length > 136) length = 136;
            msg_in = '0;
            for (int i = 0; i < length; i++) msg_in[i*8 +: 8] = 8'((offset+i)%256);
            msg_length = 8'(length);
            in_last = (offset + length == message_bytes);
            in_valid = 1;
            @(negedge clk);
            in_valid = 0;
            offset += length;
        end while (offset < message_bytes);
    endtask
    task automatic collect_digest(output logic [255:0] digest);
        int words, timeout_cycles;
        words = 0; timeout_cycles = 0; digest = '0;
        while (!hash_done) begin
            @(negedge clk);
            if (out_valid) begin
                if (words >= 8) $fatal(1, "extra digest word");
                digest[words*32 +: 32] = out_data;
                words++;
            end
            timeout_cycles++;
            if (timeout_cycles > 4000) $fatal(1, "hash timeout");
        end
        if (words != 8) $fatal(1, "missing digest words");
    endtask
    task automatic inject_at(
        input bit chi, input int index, input int round_no, input int lane,
        input bit use_d, input logic [63:0] mask, input int duration,
        input bit expect_detect, input bit use_c = 0
    );
        int waited;
        bit hit;
        state_t before_state;
        waited = 0; hit = 0;
        while (!hit) begin
            @(negedge clk); #1;
            hit = TESTBED.u_sha3_top.round_index == 5'(round_no) &&
                  (chi ? ((|TESTBED.u_sha3_top.chi_lane_active) && TESTBED.u_sha3_top.chi_cnt == 3'(index)) :
                         ((|TESTBED.u_sha3_top.theta_lane_active) && TESTBED.u_sha3_top.theta_col == 3'(index)));
            waited++;
            if (waited > 2000) $fatal(1, "injection window missed");
        end
        if (!TESTBED.u_sha3_top.state_active_mask[lane] && !use_d && !use_c)
            $fatal(1, "test selected inactive lane");
        before_state = TESTBED.u_sha3_top.cur_state;
        if (use_c) begin
            ft_c_inject_valid=1; ft_c_inject_col=3'(lane); ft_c_inject_mask=mask;
        end else if (use_d) begin
            ft_d_inject_valid = 1; ft_d_inject_col = 3'(index); ft_d_inject_mask = mask;
        end else begin
            ft_inject_valid = 1; ft_inject_lane = 5'(lane); ft_inject_mask = mask;
        end
        repeat (duration) begin
            #1;
            if (TESTBED.u_sha3_top.fault_valid !== expect_detect)
                $fatal(1, "parity detection mismatch chi=%0d index=%0d mask=%h",chi,index,mask);
            if (expect_detect && !(chi ? TESTBED.u_sha3_top.chi_hold : TESTBED.u_sha3_top.theta_hold))
                $fatal(1, "missing hold");
            @(posedge clk); #1;
            if (expect_detect) begin
                if (hash_done || out_valid || TESTBED.u_sha3_top.process_done) $fatal(1, "completion during fault");
                for (int x = 0; x < 5; x++)
                    for (int y = 0; y < 5; y++)
                        if (TESTBED.u_sha3_top.cur_state[x][y] !== before_state[x][y])
                            $fatal(1, "fault committed a partial operation");
                if (TESTBED.u_sha3_top.round_index != 5'(round_no)) $fatal(1, "round advanced on fault");
                if (!(chi ? TESTBED.u_sha3_top.chi_replay : TESTBED.u_sha3_top.theta_replay))
                    $fatal(1, "missing replay, including repeated fault");
            end
            if (duration > 1) begin @(negedge clk); #1; end
        end
        ft_inject_valid = 0; ft_d_inject_valid = 0;
        ft_c_inject_valid = 0;
    endtask
    task automatic run_case(
        input string name, input bit inject, input bit chi, input int index,
        input int round_no, input int lane, input bit use_d,
        input logic [63:0] mask, input int duration, input bit second_fault,
        input bit detectable, input int bytes_count, input logic [255:0] expected, input bit use_c = 0
    );
        logic [255:0] digest;
        int expected_faults;
        message_bytes = bytes_count;
        reset_dut();
        cfg_inject=inject; cfg_chi=chi; cfg_index=index; cfg_round=round_no;
        cfg_lane=lane; cfg_use_d=use_d; cfg_mask=mask; cfg_duration=duration;
        cfg_second=second_fault; cfg_detectable=detectable; cfg_use_c=use_c;
        drive_done=0; collect_done=0; inject_done=0;
        ->case_start;
        wait(drive_done && collect_done && inject_done);
        digest = case_digest;
        expected_faults = (inject && detectable ? duration : 0) + (second_fault ? 1 : 0);
        if (fault_count != expected_faults) $fatal(1, "%s fault count %0d expected %0d",name,fault_count,expected_faults);
        if (!inject || detectable) begin
            if (digest !== expected) $fatal(1, "%s digest mismatch %h",name,digest);
        end else begin
            // Deliberate coverage characterization: even errors are not recoverable.
            if (digest === expected) $fatal(1, "%s blind-spot test did not corrupt digest",name);
        end
        if (bytes_count == 0 && baseline_cycles != 0 && perm_cycles != baseline_cycles + expected_faults)
            $fatal(1, "%s unexpected replay latency %0d",name,perm_cycles-baseline_cycles);
        if (!inject && bytes_count == 0) baseline_cycles = perm_cycles;
        pass_count++;
        $display("[PASS] %s faults=%0d cycles=%0d",name,fault_count,perm_cycles);
    endtask
    initial begin
        pass_count = 0; baseline_cycles = 0;
        run_case("baseline",0,0,0,0,0,0,0,0,0,1,0,EMPTY_DIGEST);
        for (int b = 0; b < 64; b++) begin
            run_case($sformatf("theta_bit_%0d",b),1,0,b%5,b%24,(b%5)+5*((b/5)%5),0,64'h1<<b,1,0,1,0,EMPTY_DIGEST);
            run_case($sformatf("chi_bit_%0d",b),1,1,b%5,b%24,(b%5)*5+(b/5)%5,0,64'h1<<b,1,0,1,0,EMPTY_DIGEST);
        end
        for (int c = 0; c < 5; c++)
            run_case($sformatf("d_column_%0d",c),1,0,c,0,c,1,64'h8000000000000000,1,0,1,0,EMPTY_DIGEST);
        run_case("theta_col0_repeated",1,0,0,0,0,0,1,5,0,1,0,EMPTY_DIGEST);
        run_case("chi_row0_repeated",1,1,0,0,0,0,1,5,0,1,0,EMPTY_DIGEST);
        run_case("theta_last_repeated",1,0,4,23,4,0,1,5,0,1,0,EMPTY_DIGEST);
        run_case("chi_last_repeated",1,1,4,23,24,0,1,5,0,1,0,EMPTY_DIGEST);
        for (int c=0;c<5;c++)
            run_case($sformatf("c_checkpoint_%0d",c),1,0,0,0,c,0,1,1,0,1,0,EMPTY_DIGEST,1);
        run_case("c_checkpoint_repeated",1,0,0,0,2,0,1,3,0,1,0,EMPTY_DIGEST,1);
        run_case("d_repeated",1,0,3,0,3,1,1,5,0,1,0,EMPTY_DIGEST);
        run_case("two_faults_same_round",1,0,1,0,1,0,1,1,1,1,0,EMPTY_DIGEST);
        run_case("three_bits",1,1,2,7,12,0,7,1,0,1,0,EMPTY_DIGEST);
        run_case("even_lane_blind_spot",1,1,0,23,0,0,3,1,0,0,0,EMPTY_DIGEST);
        run_case("even_d_blind_spot",1,0,3,0,3,1,3,1,0,0,0,EMPTY_DIGEST);
        // Filled from hashlib.sha3_256(bytes(range(n))); SV word order is little-endian.
        run_case("message_135_fault",1,1,4,23,20,0,1,3,0,1,135,256'he2d5315247b9c9a9aae9b715d0d1aad8cfe5c56b7c3beb1e601c55d6d98fedfd);
        run_case("message_136_fault",1,1,4,23,20,0,1,3,0,1,136,256'he530498c3fe7df5769108817eebf4947e130c41783d3c26091a28024f9cf3ccf);
        run_case("message_137_fault",1,1,4,23,20,0,1,3,0,1,137,256'hcada8480ee830adc07ed18ef9b27d6c652539a47195074925dee1309c97d9dce);
        run_case("message_272_fault",1,1,4,23,20,0,1,3,0,1,272,256'hb57d57648ea3305c9f41bf3f92e0245b5108abe09fba099e176dff8e4aec210b);
        $display("[SUCCESS] All %0d parity/replay cases passed",pass_count);
        $finish;
    end
endmodule
`endif
