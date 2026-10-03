import sha3_pkg::*;
module keccak_round_scheduler (
    input  logic       clk,
    input  logic       rst_n,

    input  logic       start_process,
    input  logic       theta_done,
    input  logic       chi_done,

    input  logic       fault_valid,
    input  ft_replay_e replay_kind,

    output logic       theta_start,
    output logic       chi_start,
    output logic [4:0] round_index,
    output logic       process_done,

    // T: hold the failing index. T+1: execute one replay command.
    // See others/scheduler_replay_interface.md for the datapath contract.
    output logic       theta_hold,
    output logic       chi_hold,
    output logic       theta_replay,
    output logic       chi_replay,
    output ft_replay_e active_replay_kind
);

    typedef enum logic [2:0] {
        SCHED_IDLE,  
        SCHED_THETA_START,   
        SCHED_THETA_WAIT,   
        SCHED_CHI_START,  
        SCHED_CHI_WAIT,   
        SCHED_DONE   
    } round_sched_state_e;
    round_sched_state_e FSM_state, nxt_FSM_state;

    logic theta_phase, chi_phase;
    logic theta_request, chi_request;
    logic replay_pending;
    logic replay_used;
    logic theta_complete, chi_complete;
    ft_replay_e saved_replay_kind;

    assign theta_phase = (FSM_state == SCHED_THETA_START) ||
                         (FSM_state == SCHED_THETA_WAIT);
    assign chi_phase = (FSM_state == SCHED_CHI_START) ||
                       (FSM_state == SCHED_CHI_WAIT);

    // A request is accepted in START as well as WAIT. Ignore kinds belonging
    // to the other phase and do not retry repeatedly on a persistent fault.
    // The injection contract permits at most one fault per round.
    always_comb begin
        theta_request = 1'b0;
        chi_request = 1'b0;
        if (fault_valid && !replay_pending && !replay_used) begin
            case (replay_kind)
                FT_REPLAY_THETA_COL,
                FT_REPLAY_THETA_CD,
                FT_REPLAY_THETA_FROM0: theta_request = theta_phase;
                FT_REPLAY_CHI_ROW: chi_request = chi_phase;
                default: begin end
            endcase
        end
    end

    assign theta_hold = theta_request;
    assign chi_hold = chi_request;
    assign theta_replay = replay_pending && theta_phase;
    assign chi_replay = replay_pending && chi_phase;
    assign active_replay_kind = replay_pending ? saved_replay_kind : FT_REPLAY_NONE;

    // Hold 當拍的 done 不收（可能是出錯拍）。replay 當拍若剛好是最後
    // 一欄／列，done 是重算成功後的新完成，要收下，否則會多卡 1 拍。
    assign theta_complete = (FSM_state == SCHED_THETA_WAIT) && theta_done &&
                            !theta_request;
    assign chi_complete = (FSM_state == SCHED_CHI_WAIT) && chi_done &&
                          !chi_request;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            replay_pending <= 1'b0;
            replay_used <= 1'b0;
            saved_replay_kind <= FT_REPLAY_NONE;
        end else begin
            // One-cycle command, including FROM0: theta restarts internally
            // and the scheduler subsequently waits for a fresh theta_done.
            replay_pending <= 1'b0;
            if ((FSM_state == SCHED_IDLE) || (FSM_state == SCHED_DONE) ||
                chi_complete) begin
                replay_used <= 1'b0;
                saved_replay_kind <= FT_REPLAY_NONE;
            end else if (theta_request || chi_request) begin
                replay_pending <= 1'b1;
                replay_used <= 1'b1;
                saved_replay_kind <= replay_kind;
            end
        end
    end
    
    assign theta_start  = (FSM_state == SCHED_THETA_START);
    assign chi_start    = (FSM_state == SCHED_CHI_START);
    assign process_done = (FSM_state == SCHED_DONE);

    always_ff @( posedge clk or negedge rst_n ) begin
        if (!rst_n) begin
            round_index <= 5'd0;
        end else if ((FSM_state == SCHED_IDLE) || (FSM_state == SCHED_DONE)) begin
            round_index <= 5'd0;
        end else if (chi_complete && (round_index < 5'd23)) begin
            round_index <= round_index + 5'd1;
        end
    end

    always_comb begin: FSM_state_logic
        nxt_FSM_state = FSM_state;
        case (FSM_state)
            SCHED_IDLE: begin
                if (start_process) begin
                    nxt_FSM_state = SCHED_THETA_START;
                end
            end

            SCHED_THETA_START: begin
                nxt_FSM_state = SCHED_THETA_WAIT;
            end

            SCHED_THETA_WAIT: begin
                if (theta_complete) begin
                    // 原本先跳 SCHED_RHO_PI_START，現在直接跳 SCHED_CHI_START。
                    nxt_FSM_state = SCHED_CHI_START;
                end
            end

            SCHED_CHI_START: begin
                nxt_FSM_state = SCHED_CHI_WAIT;
            end

            SCHED_CHI_WAIT: begin
                if (chi_complete) begin
                    if (round_index == 5'd23) begin
                        nxt_FSM_state = SCHED_DONE;
                    end else begin
                        nxt_FSM_state = SCHED_THETA_START;
                    end
                end
            end

            SCHED_DONE: begin
                nxt_FSM_state = SCHED_IDLE;
            end

            default: begin
                nxt_FSM_state = SCHED_IDLE;
            end
        endcase
    end

    always_ff @( posedge clk or negedge rst_n ) begin: FSM_state_ff
        if (!rst_n) begin
            FSM_state <= SCHED_IDLE;
        end
        else begin
            FSM_state <= nxt_FSM_state;
        end
    end

endmodule
