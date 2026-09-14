module sha3_ultra_low_power_top (
    input  logic          clk,
    input  logic          rst_n,

    // One input transaction is one 1088-bit (136-byte) rate block.
    input  logic          in_valid,
    input  logic [1087:0] msg_in,
    input  logic [7:0]    msg_length, // 0..136
    input  logic          in_last,    // 1 only on the final input block

    output logic          in_ready,
    output logic [31:0]   out_data,
    output logic          out_valid,
    output logic          hash_done
);

    import sha3_pkg::*;

    localparam logic [24:0] ALL_LANES  = 25'h1FFFFFF;
    localparam logic [24:0] RATE_LANES = 25'h001FFFF;
    localparam logic [24:0] LANE_00    = 25'h000001;

    // Current input block registers.
    logic [1087:0] msg_in_q;
    logic [7:0]    msg_length_q;
    logic          block_last_q;

    // Tracks whether a real message is currently being processed.
    logic          message_active_q;

    // High while the synthetic padding-only block is being processed.
    logic          extra_pad_active_q;

    logic          accept_msg;
    logic          clear_state;

    logic          absorb_en;
    logic          start_process;
    logic          squeeze_start;
    logic          process_done;
    logic          formatter_done;

    logic          ctrl_block_ready;
    logic          need_extra_pad;
    logic          final_block_done;

    logic          theta_start;
    logic          theta_done;
    logic [24:0]   theta_lane_active;

    logic          chi_start;
    logic          chi_done;
    logic [24:0]   chi_lane_active;

    logic [4:0]    round_index;
    logic [24:0]   sleep_en;
    logic [24:0]   lane_clk;
    logic [24:0]   state_active_mask;

    state_t cur_state;
    state_t nxt_state;
    state_t absorbed_state;
    state_t theta_state;
    state_t rho_pi_state;
    state_t chi_state;
    state_t iota_state;

    logic [1087:0] padded_block;

    assign in_ready  = ctrl_block_ready;
    assign accept_msg = in_valid && in_ready;

    assign clear_state = accept_msg && !message_active_q;

    assign need_extra_pad =
        block_last_q &&
        (msg_length_q == 8'd136) &&
        !extra_pad_active_q;

    assign final_block_done =
        extra_pad_active_q ||
        (block_last_q && (msg_length_q < 8'd136));

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            msg_in_q          <= '0;
            msg_length_q      <= 8'd0;
            block_last_q      <= 1'b0;
            message_active_q  <= 1'b0;
            extra_pad_active_q<= 1'b0;
        end
        else begin
            if (accept_msg) begin
                msg_in_q     <= msg_in;
                msg_length_q <= msg_length;
                block_last_q <= in_last;

                extra_pad_active_q <= 1'b0;
                message_active_q   <= 1'b1;
            end

            if (process_done && need_extra_pad) begin
                extra_pad_active_q <= 1'b1;
            end

            if (hash_done) begin
                message_active_q   <= 1'b0;
                extra_pad_active_q <= 1'b0;
            end
        end
    end

    sha3_ctrl_fsm u_ctrl_fsm (
        .clk             (clk),
        .rst_n           (rst_n),
        .in_valid        (accept_msg),
        .process_done    (process_done),
        .squeeze_done    (formatter_done),
        .need_extra_pad  (need_extra_pad),
        .final_block_done(final_block_done),
        .absorb_en       (absorb_en),
        .start_process   (start_process),
        .squeeze_start   (squeeze_start),
        .hash_done       (hash_done),
        .block_ready     (ctrl_block_ready)
    );

    sha3_pad_domain u_pad_domain (
        .msg_in         (msg_in_q),
        .msg_length     (msg_length_q),
        .block_last     (block_last_q),
        .extra_pad_block(extra_pad_active_q),
        .padded_block   (padded_block)
    );

    sha3_rate_buffer u_rate_buffer (
        .in_state     (cur_state),
        .padded_block (padded_block),
        .absorb_en    (absorb_en),
        .out_state    (absorbed_state)
    );

    keccak_round_scheduler u_round_scheduler (
        .clk          (clk),
        .rst_n        (rst_n),
        .start_process(start_process),
        .theta_done   (theta_done),
        .chi_done     (chi_done),
        .theta_start  (theta_start),
        .chi_start    (chi_start),
        .round_index  (round_index),
        .process_done (process_done)
    );

    keccak_theta_serial u_theta (
        .in_state    (cur_state),
        .clk         (clk),
        .rst_n       (rst_n),
        .start       (theta_start),
        .out_state   (theta_state),
        .done        (theta_done),
        .lane_active (theta_lane_active)
    );

    keccak_rho_pi_wire u_rho_pi (
        .in_state  (cur_state),
        .out_state (rho_pi_state)
    );

    keccak_chi_row u_chi (
        .in_state    (rho_pi_state),
        .clk         (clk),
        .rst_n       (rst_n),
        .start       (chi_start),
        .out_state   (chi_state),
        .done        (chi_done),
        .lane_active (chi_lane_active)
    );

    keccak_iota u_iota (
        .round_index(round_index),
        .in_state   (chi_state),
        .out_state  (iota_state)
    );

    sha3_output_formatter u_output_formatter (
        .clk       (clk),
        .rst_n     (rst_n),
        .start     (squeeze_start),
        .in_state  (cur_state),
        .out_data  (out_data),
        .out_valid (out_valid),
        .done      (formatter_done)
    );

    always_comb begin
        state_active_mask = 25'd0;

        for (int x = 0; x < COL_NUM; x++) begin
            for (int y = 0; y < ROW_NUM; y++) begin
                nxt_state[x][y] = cur_state[x][y];
            end
        end

        if (clear_state) begin
            state_active_mask = ALL_LANES;
            for (int x = 0; x < COL_NUM; x++) begin
                for (int y = 0; y < ROW_NUM; y++) begin
                    nxt_state[x][y] = '0;
                end
            end
        end
        else if (absorb_en) begin
            state_active_mask = RATE_LANES;
            for (int x = 0; x < COL_NUM; x++) begin
                for (int y = 0; y < ROW_NUM; y++) begin
                    nxt_state[x][y] = absorbed_state[x][y];
                end
            end
        end
        else if (theta_lane_active != 25'd0) begin
            state_active_mask = theta_lane_active;
            for (int x = 0; x < COL_NUM; x++) begin
                for (int y = 0; y < ROW_NUM; y++) begin
                    nxt_state[x][y] = theta_state[x][y];
                end
            end
        end
        else if (chi_lane_active != 25'd0) begin
            state_active_mask = chi_lane_active;
            for (int x = 0; x < COL_NUM; x++) begin
                for (int y = 0; y < ROW_NUM; y++) begin
                    if (x == 0 && y == 0)
                        nxt_state[x][y] = iota_state[x][y];
                    else
                        nxt_state[x][y] = chi_state[x][y];
                end
            end
        end
    end

    assign sleep_en = ~state_active_mask;

    sha3_low_power_gating u_low_power_gating (
        .clk      (clk),
        .sleep_en (sleep_en),
        .gated_clk(lane_clk)
    );

    keccak_state_bank u_state_bank (
        .lane_clk (lane_clk),
        .rst_n    (rst_n),
        .nxt_state(nxt_state),
        .cur_state(cur_state)
    );

endmodule