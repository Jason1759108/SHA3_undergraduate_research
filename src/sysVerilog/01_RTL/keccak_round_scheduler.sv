import sha3_pkg::*;
module keccak_round_scheduler (
    input  logic       clk,
    input  logic       rst_n,

    input  logic       start_process,
    input  logic       theta_done,
    input  logic       chi_done,

    output logic       theta_start,
    output logic       chi_start,
    output logic [4:0] round_index,
    output logic       process_done
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
    
    assign theta_start  = (FSM_state == SCHED_THETA_START);
    assign chi_start    = (FSM_state == SCHED_CHI_START);
    assign process_done = (FSM_state == SCHED_DONE);

    always_ff @( posedge clk or negedge rst_n ) begin
        if (!rst_n) begin
            round_index <= 5'd0;
        end else if ((FSM_state == SCHED_IDLE) || (FSM_state == SCHED_DONE)) begin
            round_index <= 5'd0;
        end else if ((FSM_state == SCHED_CHI_WAIT) && chi_done && (round_index < 5'd23)) begin
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
                if (theta_done) begin
                    // 原本先跳 SCHED_RHO_PI_START，現在直接跳 SCHED_CHI_START。
                    nxt_FSM_state = SCHED_CHI_START;
                end
            end

            SCHED_CHI_START: begin
                nxt_FSM_state = SCHED_CHI_WAIT;
            end

            SCHED_CHI_WAIT: begin
                if (chi_done) begin
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
