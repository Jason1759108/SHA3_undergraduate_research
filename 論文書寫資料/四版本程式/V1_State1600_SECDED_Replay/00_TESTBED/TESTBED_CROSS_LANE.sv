`timescale 1ns/1ps
// Paper supplement: two active lanes, one data-bit error in each, one event per round.
// Existing PATTERN/PATTERN_FT regressions are retained and run separately.
import sha3_pkg::*;
module TESTBED;
    logic clk=0, rst_n=0, in_valid=0, in_last=0;
    logic [1087:0] msg_in='0;
    logic [7:0] msg_length=0;
    wire in_ready, out_valid, hash_done;
    wire [31:0] out_data;
    sha3_ultra_low_power_top u_sha3_top (
        .clk(clk), .rst_n(rst_n), .in_valid(in_valid), .in_last(in_last),
        .msg_in(msg_in), .msg_length(msg_length), .in_ready(in_ready),
        .out_data(out_data), .out_valid(out_valid), .hash_done(hash_done),
        .ft_inject_valid(1'b0), .ft_inject_lane(5'd0), .ft_inject_mask('0),
        .ft_d_inject_valid(1'b0), .ft_d_inject_col(3'd0), .ft_d_inject_mask('0)
    );
    always #5 clk=~clk;
    localparam logic [255:0] EMPTY_DIGEST =
        256'h4a43f8804b0ad882fa493be44dff80f562d661a05647c15166d71ebff8c6ffa7;
    localparam bit EXPECT_REPLAY = 1'b1;
    int point=0, first_lane, second_lane, pass_count=0;
    int cycles=0, baseline=0, faults=0;
    bit in_perm=0, injection_done=0;
    state_t saved_state;
    logic [FT_S_CODE_W-1:0] forced_code;
    event inject_start;

    task automatic fail_now(input string message);
        $display("[FAIL] cross_lane point=%0d: %s",point,message);
        $fatal(1,"cross-lane regression failed");
    endtask

    always @(posedge clk) begin
        if (!rst_n) begin cycles=0; in_perm=0; faults=0; end
        else begin
            if (u_sha3_top.start_process) begin cycles=0; in_perm=1; end
            else if (in_perm) begin
                cycles++;
                if (u_sha3_top.process_done) in_perm=0;
            end
            if (u_sha3_top.fault_valid) faults++;
        end
    end

    function automatic bit point_hit();
        case(point)
          1: return u_sha3_top.theta_start && u_sha3_top.theta_compute_d;
          2: return (|u_sha3_top.theta_lane_active) && u_sha3_top.theta_col==3 && !u_sha3_top.theta_compute_d;
          3: return u_sha3_top.chi_start;
          4: return (|u_sha3_top.chi_lane_active) && u_sha3_top.chi_cnt==3;
          5: return (|u_sha3_top.chi_lane_active) && u_sha3_top.chi_cnt==4 && u_sha3_top.round_index==23;
          default: return 0;
        endcase
    endfunction

    // Independent worker avoids a forked automatic-task lifetime dependency.
    initial forever begin
        @inject_start;
        if(point!=0) begin
            do begin @(negedge clk); #1; end while(!point_hit());
            case(point)
                1: begin first_lane=0; second_lane=5; end
                2: begin first_lane=3; second_lane=8; end
                3: begin first_lane=0; second_lane=1; end
                4: begin first_lane=15; second_lane=16; end
                5: begin first_lane=20; second_lane=21; end
            endcase
            if(!u_sha3_top.state_active_mask[first_lane] || !u_sha3_top.state_active_mask[second_lane])
                fail_now("both target lanes must be active");
            saved_state=u_sha3_top.cur_state;
            forced_code=u_sha3_top.u_lane_ecc.encoded_code;
            forced_code[FT_S_DATA_POS[first_lane*64]-1] ^= 1'b1;
            forced_code[FT_S_DATA_POS[second_lane*64]-1] ^= 1'b1;
            force u_sha3_top.u_lane_ecc.received_code=forced_code;
            #1;
            if(u_sha3_top.u_lane_ecc.global_status !== FT_ST_UNCORR) fail_now("global code must report UNCORR");
            if(u_sha3_top.fault_valid !== EXPECT_REPLAY)
                fail_now("unexpected fault_valid");
            if((u_sha3_top.theta_hold || u_sha3_top.chi_hold) !== EXPECT_REPLAY)
                fail_now("unexpected hold");
            @(posedge clk); #1;
            if(EXPECT_REPLAY) begin
                for(int x=0;x<5;x++) for(int y=0;y<5;y++)
                    if(u_sha3_top.cur_state[x][y] !== saved_state[x][y])
                        fail_now("state changed on held operation");
                if(!(u_sha3_top.theta_replay || u_sha3_top.chi_replay))
                    fail_now("missing replay on T+1");
                if(u_sha3_top.process_done) fail_now("premature process_done");
            end
            release u_sha3_top.u_lane_ecc.received_code;
            injection_done=1;
        end else injection_done=1;
    end

    task automatic run_case(input int p);
        logic [255:0] digest;
        int words, timeout_cycles, extra;
        point=p; injection_done=0;
        rst_n=0; in_valid=0; in_last=0;
        repeat(4) @(negedge clk);
        rst_n=1;
        repeat(2) @(negedge clk);
        ->inject_start;
        while(!in_ready) @(negedge clk);
        in_last=1; in_valid=1;
        @(negedge clk); in_last=0; in_valid=0;
        digest='0; words=0; timeout_cycles=0;
        while(!hash_done) begin
            @(negedge clk);
            if(out_valid) begin
                if(words<8) digest[words*32+:32]=out_data;
                words++;
            end
            timeout_cycles++;
            if(timeout_cycles>4000) fail_now("timeout waiting for hash_done");
        end
        if(!injection_done) fail_now("injection window not reached");
        if(words!=8 || digest!==EMPTY_DIGEST) fail_now("digest/output word count mismatch");
        if(p==0) baseline=cycles;
        extra=cycles-baseline;
        if(extra != ((p!=0 && EXPECT_REPLAY)?1:0)) fail_now("unexpected extra cycles");
        if(faults != ((p!=0 && EXPECT_REPLAY)?1:0)) fail_now("unexpected fault count");
        pass_count++;
        $display("[PASS] cross_lane point=%0d lanes=%0d,%0d cycles=%0d extra=%0d faults=%0d digest=%064h",
                 p,first_lane,second_lane,cycles,extra,faults,digest);
        @(negedge clk);
    endtask

    initial begin
        $display("==================================================");
        $display("   SHA3-256 CROSS-LANE FAULT VERIFICATION");
        $display("==================================================");
        run_case(0);
        for(int p=1;p<=5;p++) run_case(p);
        $display("[SUCCESS] All %0d cross-lane test cases passed!",pass_count);
        #20; $finish;
    end
    initial begin #1000000; fail_now("global watchdog expired"); end
endmodule
