`timescale 1ns/1ps
// Edge-to-edge timing: first accepted input -> eighth output sampled by a
// synchronous receiver. Includes buffer, padding, absorb, permutation and output.
module paper_cycle_monitor;
    longint cycle_index=0, first_cycle=0, perm_start=0, core_total=0;
    int message_bytes=0, words=0, permutations=0;
    bit active=0, perm_active=0;
    always @(posedge TESTBED.clk) begin
        if(!TESTBED.rst_n) begin
            cycle_index=0; active=0; perm_active=0;
            message_bytes=0; words=0; permutations=0; core_total=0;
        end else begin
            cycle_index++;
            if(TESTBED.in_valid && TESTBED.in_ready) begin
                if(!active) begin
                    active=1; first_cycle=cycle_index; message_bytes=0;
                    words=0; permutations=0; core_total=0;
                end
                message_bytes+=int'(TESTBED.msg_length);
            end
            if(TESTBED.u_sha3_top.start_process) begin perm_start=cycle_index; perm_active=1; end
            if(TESTBED.u_sha3_top.process_done && perm_active) begin
                core_total+=cycle_index-perm_start; permutations++; perm_active=0;
            end
            if(TESTBED.out_valid && active) begin
                words++;
                if(words==8) begin
                    $display("[METRIC] bytes=%0d e2e_cycles=%0d permutations=%0d core_cycles_total=%0d",
                             message_bytes,cycle_index-first_cycle,permutations,core_total);
                    active=0;
                end
            end
        end
    end
endmodule
bind TESTBED paper_cycle_monitor paper_monitor();
