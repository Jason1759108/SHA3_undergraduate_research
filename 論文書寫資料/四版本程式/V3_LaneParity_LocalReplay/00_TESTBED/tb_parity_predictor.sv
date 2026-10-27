`timescale 1ns/1ps
import sha3_pkg::*;
module tb_parity_predictor;
    state_t in_state, data_nxt, data_wr;
    row_t row_in;
    logic start, row0, check_valid, checkpoint_fault, inject_valid;
    logic [2:0] col;
    logic [4:0] saved_cp, live_cp, theta_p, chi_p, round_index, inject_lane;
    logic [24:0] active, predicted, mismatch;
    logic [63:0] inject_mask;
    logic fault;
    logic [63:0] c [0:4];
    logic [63:0] d, actual_chi;
    logic [63:0] rng = 64'hc0decafe01234567;
    int checks;
    keccak_theta_parity theta_predictor (
        .in_state(in_state), .start(start), .col(col), .c_parity_saved(saved_cp),
        .c_parity_live(live_cp), .lane_parity(theta_p)
    );
    keccak_chi_parity chi_predictor (
        .row_in(row_in), .row0(row0), .round_index(round_index), .lane_parity(chi_p)
    );
    keccak_lane_parity checker_dut (
        .data_nxt(data_nxt), .data_cur(in_state), .lane_active(active),
        .check_valid(check_valid), .checkpoint_fault(checkpoint_fault),
        .predicted_parity(predicted), .inject_valid(inject_valid),
        .inject_lane(inject_lane), .inject_mask(inject_mask),
        .data_wr(data_wr), .mismatch_mask(mismatch), .fault_valid(fault)
    );
    function automatic logic [63:0] next_random(input logic [63:0] v);
        logic [63:0] t;
        t=v^(v<<13); t=t^(t>>7); return t^(t<<17);
    endfunction
    task automatic check_atomic();
        if (!fault) $fatal(1,"missing fault");
        for (int x=0;x<5;x++)
            for (int y=0;y<5;y++)
                if (data_wr[x][y] !== in_state[x][y]) $fatal(1,"partial commit");
        checks++;
    endtask
    initial begin
        checks=0; start=0; row0=0; col=0; round_index=0;
        active=0; predicted=0; check_valid=1; checkpoint_fault=0;
        inject_valid=0; inject_lane=0; inject_mask=0;
        for (int n=0;n<1000;n++) begin
            for (int x=0;x<5;x++) begin
                c[x]=0;
                for (int y=0;y<5;y++) begin
                    rng=next_random(rng); in_state[x][y]=rng;
                    c[x]^=rng;
                end
                saved_cp[x]=^c[x];
                row_in[x]=in_state[x][n%5];
            end
            start=1'(n%2); row0=(n%5==0); round_index=5'(n%24);
            for (int x=0;x<5;x++) begin
                col=3'(x); #1;
                d=c[(x+4)%5] ^ {c[(x+1)%5][62:0],c[(x+1)%5][63]};
                for (int y=0;y<5;y++) begin
                    if (theta_p[y] !== (^(in_state[x][y]^d))) $fatal(1,"theta prediction");
                    checks++;
                end
                if (start && live_cp !== saved_cp) $fatal(1,"C parity prediction");
            end
            for (int x=0;x<5;x++) begin
                actual_chi=row_in[x]^((~row_in[(x+1)%5])&row_in[(x+2)%5]);
                if (row0 && x==0) actual_chi^=RC[round_index];
                if (chi_p[x] !== (^actual_chi)) $fatal(1,"chi/iota prediction");
                checks++;
            end
            // Exercise the checker interface using the reference theta result.
            data_nxt=in_state; active=0; predicted=0;
            for (int y=0;y<5;y++) begin
                active[y*5+4]=1;
                data_nxt[4][y]=in_state[4][y]^d;
                predicted[y*5+4]=theta_p[y];
            end
            #1;
            if (fault) $fatal(1,"false positive");
            for (int y=0;y<5;y++)
                if (data_wr[4][y] !== data_nxt[4][y]) $fatal(1,"clean commit");
            inject_valid=1; inject_lane=24; inject_mask=64'h1<<(n%64);
            #1; check_atomic();
            inject_mask=(64'h1<<(n%64)) | (64'h1<<((n+1)%64));
            #1;
            if (fault) $fatal(1,"even-bit parity characterization");
            inject_valid=0;
            // Two odd faults in different lanes must NOT cancel each other.
            data_nxt[4][0]^=64'h1; data_nxt[4][1]^=64'h1;
            #1; check_atomic();
            if (mismatch !== ((25'h1<<4)|(25'h1<<9))) $fatal(1,"per-lane mismatch mask");
            check_valid=0; #1;
            if (fault) $fatal(1,"inactive checker raised fault");
            checkpoint_fault=1; #1; check_atomic();
            checkpoint_fault=0; check_valid=1; active=0; #1;
            if (fault) $fatal(1,"inactive lanes raised fault");
        end
        $display("[SUCCESS] %0d predictor/checker checks on 1000 random states",checks);
        $finish;
    end
endmodule
