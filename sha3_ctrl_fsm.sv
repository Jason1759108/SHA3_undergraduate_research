module sha3_ctrl_fsm (
    input  logic clk,
    input  logic rst_n,

    input  logic in_valid,
    input  logic process_done,
    input  logic squeeze_done,

    output logic absorb_en,
    output logic start_process,
    output logic squeeze_start,
    output logic hash_done
);
    import sha3_pkg::*;

    top_fsm_state_e cur_state, nxt_state;

    always_comb begin
        nxt_state = cur_state;

        case (cur_state)
            ST_IDLE: begin
                if (in_valid)
                    nxt_state = ST_PAD;
            end

            ST_PAD: begin
                nxt_state = ST_ABSORB;
            end

            ST_ABSORB: begin
                nxt_state = ST_RUN_ROUND;
            end

            ST_RUN_ROUND: begin
                if (process_done)
                    nxt_state = ST_SQUEEZE;
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

            // 預設清除，確保兩者都是單週期脈波
            start_process <= 1'b0;
            squeeze_start <= 1'b0;

            // 離開 ABSORB、進入 RUN_ROUND 時啟動 Scheduler
            if (cur_state == ST_ABSORB)
                start_process <= 1'b1;

            // Scheduler 完成時啟動 Output Formatter
            if ((cur_state == ST_RUN_ROUND) && process_done)
                squeeze_start <= 1'b1;
        end
    end

    assign absorb_en = (cur_state == ST_ABSORB);
    assign hash_done = (cur_state == ST_DONE);

endmodule