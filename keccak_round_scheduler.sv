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

    import sha3_pkg::*;

    round_sched_state_e cur_state, nxt_state;

    always_ff @( posedge clk or negedge rst_n ) begin
        if (!rst_n) begin
            round_index <= 5'd0;
        end else if ((cur_state == SCHED_IDLE) || (cur_state == SCHED_DONE)) begin
            round_index <= 5'd0;
        end else if ((cur_state == SCHED_CHI_WAIT) && chi_done && (round_index < 5'd23)) begin
            round_index <= round_index + 5'd1;
        end
    end

    assign theta_start  = (cur_state == SCHED_THETA_START);
    assign chi_start    = (cur_state == SCHED_CHI_START);
    assign process_done = (cur_state == SCHED_DONE);

    always_comb begin
        nxt_state = cur_state;
        case (cur_state)
            SCHED_IDLE: begin
                if (start_process) begin
                    nxt_state = SCHED_THETA_START;
                end
            end

            SCHED_THETA_START: begin
                nxt_state = SCHED_THETA_WAIT;
            end

            SCHED_THETA_WAIT: begin
                if (theta_done) begin
                    nxt_state = SCHED_RHO_PI_START;
                end
            end

            SCHED_RHO_PI_START: begin
                nxt_state = SCHED_RHO_PI_WAIT;
            end

            SCHED_RHO_PI_WAIT: begin
                nxt_state = SCHED_CHI_START;
            end

            SCHED_CHI_START: begin
                nxt_state = SCHED_CHI_WAIT;
            end

            SCHED_CHI_WAIT: begin
                if (chi_done) begin
                    if (round_index == 5'd23) begin
                        nxt_state = SCHED_DONE;
                    end else begin
                        nxt_state = SCHED_THETA_START;
                    end
                end
            end

            SCHED_DONE: begin
                nxt_state = SCHED_IDLE;
            end

            default: begin
                nxt_state = SCHED_IDLE;
            end
        endcase
    end

    always_ff @( posedge clk or negedge rst_n ) begin: state
        if (!rst_n) begin
            cur_state <= SCHED_IDLE;
        end
        else begin
            cur_state <= nxt_state;
        end
    end

endmodule
