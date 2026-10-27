import sha3_pkg::*;
module keccak_round_scheduler (
    input logic clk, rst_n, start_process, theta_done, chi_done,
    input logic fault_valid,
    output logic theta_start, chi_start,
    output logic [4:0] round_index,
    output logic process_done,
    output logic theta_hold, chi_hold, theta_replay, chi_replay
);
    typedef enum logic [2:0] {
        SCHED_IDLE, SCHED_THETA_START, SCHED_THETA_WAIT,
        SCHED_CHI_START, SCHED_CHI_WAIT, SCHED_DONE
    } round_sched_state_e;
    round_sched_state_e FSM_state, nxt_FSM_state;
    logic theta_phase, chi_phase, replay_pending;
    logic theta_complete, chi_complete;
    assign theta_phase = FSM_state == SCHED_THETA_START || FSM_state == SCHED_THETA_WAIT;
    assign chi_phase = FSM_state == SCHED_CHI_START || FSM_state == SCHED_CHI_WAIT;
    // Every detected error holds, including an error during a replay.
    assign theta_hold = fault_valid && theta_phase;
    assign chi_hold = fault_valid && chi_phase;
    assign theta_replay = replay_pending && theta_phase;
    assign chi_replay = replay_pending && chi_phase;
    assign theta_complete = FSM_state == SCHED_THETA_WAIT && theta_done && !fault_valid;
    assign chi_complete = FSM_state == SCHED_CHI_WAIT && chi_done && !fault_valid;
    assign theta_start = FSM_state == SCHED_THETA_START;
    assign chi_start = FSM_state == SCHED_CHI_START;
    assign process_done = FSM_state == SCHED_DONE;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            FSM_state <= SCHED_IDLE;
            replay_pending <= 1'b0;
            round_index <= '0;
        end else begin
            FSM_state <= nxt_FSM_state;
            replay_pending <= fault_valid && (theta_phase || chi_phase);
            if (FSM_state == SCHED_IDLE || FSM_state == SCHED_DONE) round_index <= '0;
            else if (chi_complete && round_index < 5'd23) round_index <= round_index + 5'd1;
        end
    end
    always_comb begin
        nxt_FSM_state = FSM_state;
        case (FSM_state)
            SCHED_IDLE: if (start_process) nxt_FSM_state = SCHED_THETA_START;
            SCHED_THETA_START: nxt_FSM_state = SCHED_THETA_WAIT;
            SCHED_THETA_WAIT: if (theta_complete) nxt_FSM_state = SCHED_CHI_START;
            SCHED_CHI_START: nxt_FSM_state = SCHED_CHI_WAIT;
            SCHED_CHI_WAIT: if (chi_complete)
                nxt_FSM_state = round_index == 5'd23 ? SCHED_DONE : SCHED_THETA_START;
            SCHED_DONE: nxt_FSM_state = SCHED_IDLE;
            default: nxt_FSM_state = SCHED_IDLE;
        endcase
    end
endmodule
