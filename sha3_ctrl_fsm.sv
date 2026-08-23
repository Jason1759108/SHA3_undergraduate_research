module sha3_ctrl_fsm (
    input  logic clk,
    input  logic rst_n,

    input  logic in_valid,
    input  logic process_done,
    input  logic squeeze_done,
    input  logic need_extra_pad,
    input  logic final_block_done,

    output logic absorb_en,
    output logic start_process,
    output logic squeeze_start,
    output logic hash_done,
    output logic block_ready
);
    import sha3_pkg::*;

    top_fsm_state_e cur_state, nxt_state;

    always_comb begin
        nxt_state = cur_state;

        case (cur_state)
            ST_IDLE: begin
                if (in_valid)
                    nxt_state = ST_ABSORB;
            end

            ST_ABSORB: begin
                nxt_state = ST_RUN_ROUND;
            end

            ST_RUN_ROUND: begin
                if (process_done) begin
                    if (need_extra_pad)
                        nxt_state = ST_ABSORB;
                    else if (final_block_done)
                        nxt_state = ST_SQUEEZE;
                    else
                        nxt_state = ST_WAIT_BLOCK;
                end
            end

            ST_WAIT_BLOCK: begin
                if (in_valid)
                    nxt_state = ST_ABSORB;
            end

            ST_SQUEEZE: begin
                if (squeeze_done)
                    nxt_state = ST_DONE;
            end

            ST_DONE: begin
                nxt_state = ST_IDLE;
            end

            default: begin
                nxt_state = ST_IDLE;
            end
        endcase
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cur_state     <= ST_IDLE;
            start_process <= 1'b0;
            squeeze_start <= 1'b0;
        end else begin
            cur_state <= nxt_state;

            // Default: single-cycle pulses.
            start_process <= 1'b0;
            squeeze_start <= 1'b0;

            // 跨區塊切換時，精準發出 1-cycle start_process 脈波
            if ((nxt_state == ST_RUN_ROUND) && (cur_state != ST_RUN_ROUND)) begin
                start_process <= 1'b1;
            end

            // 最後一塊運算完畢時，精準發出 1-cycle squeeze_start 脈波
            if ((nxt_state == ST_SQUEEZE) && (cur_state != ST_SQUEEZE)) begin
                squeeze_start <= 1'b1;
            end
        end
    end

    assign block_ready = (cur_state == ST_IDLE) ||
                         (cur_state == ST_WAIT_BLOCK);
    assign absorb_en = (cur_state == ST_ABSORB);
    assign hash_done = (cur_state == ST_DONE);

endmodule