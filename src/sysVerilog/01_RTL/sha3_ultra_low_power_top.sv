module sha3_ultra_low_power_top (
    input  logic          clk,
    input  logic          rst_n,

    // One input transaction is one 1088-bit (136-byte) rate block.
    input  logic          in_valid,
    input  logic [1087:0] msg_in,
    input  logic [7:0]    msg_length,
    input  logic          in_last,

    output logic          in_ready,
    output logic [31:0]   out_data,
    output logic          out_valid,
    output logic          hash_done,

    // Fault injection (synthesis / original PATTERN tie these to 0).
    input  logic          ft_inject_valid,
    input  logic [4:0]    ft_inject_lane,
    input  logic [71:0]   ft_inject_mask,
    input  logic          ft_d_inject_valid,
    input  logic [2:0]    ft_d_inject_col,
    input  logic [71:0]   ft_d_inject_mask
);

    import sha3_pkg::*;

    localparam logic [24:0] ALL_LANES  = 25'h1FFFFFF;
    localparam logic [24:0] RATE_LANES = 25'h001FFFF;

    logic [7:0]    msg_length_q;
    logic          block_last_q;

    logic          message_active_q;
    logic          extra_pad_active_q;

    logic          accept_msg;
    logic          clear_state;

    logic          absorb_en;
    logic          start_process;
    logic          squeeze_start;
    logic          formatter_start_q;
    logic          process_done;
    logic          formatter_done;

    logic          ctrl_block_ready;
    logic          need_extra_pad;
    logic          final_block_done;

    logic          theta_start;
    logic          theta_done;
    logic          theta_hold;
    logic          theta_replay;
    logic          theta_compute_d;
    logic [2:0]    theta_col;
    logic [24:0]   theta_lane_active;
    ft_status_e    theta_d_status [1:4];

    logic          chi_start;
    logic          chi_done;
    logic          chi_hold;
    logic          chi_replay;
    logic [2:0]    chi_cnt;
    logic [24:0]   chi_lane_active;

    logic [4:0]    round_index;

    logic          fault_valid;
    ft_replay_e    replay_kind;
    ft_replay_e    active_replay_kind;
    ft_src_e       ft_src;

    logic [24:0]   sleep_en;
    logic [24:0]   lane_clk;
    logic [24:0]   state_active_mask;

    logic [24:0]   lane_inject_en;
    logic [71:0]   lane_inject_mask [0:24];
    logic [7:0]    ecc_q [0:24];
    ft_status_e    lane_status [0:24];
    logic          any_uncorr;
    logic [24:0]   uncorr_mask;
    state_t        data_wr;

    state_t cur_state;
    state_t nxt_state;
    state_t absorbed_state;
    state_t theta_state;
    state_t rho_pi_state;
    state_t chi_state;

    logic [1087:0] padded_block;

    logic          input_buffer_valid_q;
    logic [1087:0] input_buffer_data_q;
    logic [7:0]    input_buffer_length_q;
    logic          input_buffer_last_q;
    logic          input_buffer_push;
    logic          input_buffer_pop;

    // The input register is a one-block buffer.  in_ready describes the
    // buffer's capacity, while ctrl_block_ready describes the core's capacity.
    assign in_ready          = !input_buffer_valid_q;
    assign input_buffer_push = in_valid && in_ready;
    // 不再複製一份 1088-bit msg_in_q。padding 直接讀 buffer，
    // 所以要等到 absorb 真正吃掉這塊才 pop。extra_pad 那一拍
    // 不走訊息內容，不可把已經排隊的下一塊 pop 掉。
    assign accept_msg        = input_buffer_valid_q && ctrl_block_ready;
    assign input_buffer_pop  = absorb_en && input_buffer_valid_q &&
                               !extra_pad_active_q;

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
            msg_length_q       <= 8'd0;
            block_last_q       <= 1'b0;
            message_active_q   <= 1'b0;
            extra_pad_active_q <= 1'b0;
            formatter_start_q  <= 1'b0;
        end
        else begin
            if (accept_msg) begin
                msg_length_q <= input_buffer_length_q;
                block_last_q <= input_buffer_last_q;

                extra_pad_active_q <= 1'b0;
                message_active_q   <= 1'b1;
            end

            if (process_done && need_extra_pad)
                extra_pad_active_q <= 1'b1;

            formatter_start_q <= process_done && final_block_done;

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
        .msg_in         (input_buffer_data_q),
        .msg_length     (msg_length_q),
        .block_last     (block_last_q),
        .extra_pad_block(extra_pad_active_q),
        .absorb_en      (absorb_en),
        .padded_block   (padded_block)
    );

    sha3_absorb_xor u_absorb_xor (
        .in_state     (cur_state),
        .padded_block (padded_block),
        .absorb_en    (absorb_en),
        .out_state    (absorbed_state)
    );

    keccak_round_scheduler u_round_scheduler (
        .clk               (clk),
        .rst_n             (rst_n),
        .start_process     (start_process),
        .theta_done        (theta_done),
        .chi_done          (chi_done),
        .fault_valid       (fault_valid),
        .replay_kind       (replay_kind),
        .theta_start       (theta_start),
        .chi_start         (chi_start),
        .round_index       (round_index),
        .process_done      (process_done),
        .theta_hold        (theta_hold),
        .chi_hold          (chi_hold),
        .theta_replay      (theta_replay),
        .chi_replay        (chi_replay),
        .active_replay_kind(active_replay_kind)
    );

    keccak_theta_serial u_theta (
        .in_state    (cur_state),
        .clk         (clk),
        .rst_n       (rst_n),
        .start       (theta_start),
        .replay      (theta_replay),
        .hold        (theta_hold),
        .replay_kind (active_replay_kind),
        .d_inject_valid(ft_d_inject_valid),
        .d_inject_col  (ft_d_inject_col),
        .d_inject_mask (ft_d_inject_mask),
        .out_state   (theta_state),
        .done        (theta_done),
        .lane_active (theta_lane_active),
        .compute_d   (theta_compute_d),
        .col         (theta_col),
        .d_status    (theta_d_status)
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
        .round_index (round_index),
        .replay      (chi_replay),
        .hold        (chi_hold),
        .cnt         (chi_cnt),
        .out_state   (chi_state),
        .done        (chi_done),
        .lane_active (chi_lane_active)
    );

    sha3_output_formatter u_output_formatter (
        .clk       (clk),
        .rst_n     (rst_n),
        .start     (formatter_start_q),
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
                    nxt_state[x][y] = chi_state[x][y];
                end
            end
        end
    end

    assign sleep_en = ~state_active_mask;

    always_comb begin
        lane_inject_en = 25'd0;
        for (int i = 0; i < 25; i++)
            lane_inject_mask[i] = 72'd0;

        // 只在 keccak-f 且該 lane 正在寫時注入；absorb / pad 不打。
        if (ft_inject_valid &&
            (ft_inject_lane <= 5'd24) &&
            ((theta_lane_active != 25'd0) || (chi_lane_active != 25'd0)) &&
            state_active_mask[ft_inject_lane]) begin
            lane_inject_en[ft_inject_lane]   = 1'b1;
            lane_inject_mask[ft_inject_lane] = ft_inject_mask;
        end

        if (theta_lane_active != 25'd0)
            ft_src = FT_SRC_THETA;
        else if (chi_lane_active != 25'd0)
            ft_src = FT_SRC_CHI;
        else
            ft_src = FT_SRC_NONE;
    end

    keccak_lane_ecc u_lane_ecc (
        .clk         (clk),
        .rst_n       (rst_n),
        .lane_clk    (lane_clk),
        .lane_active (state_active_mask),
        .data_nxt    (nxt_state),
        .data_cur    (cur_state),
        .inject_en   (lane_inject_en),
        .inject_mask (lane_inject_mask),
        .data_wr     (data_wr),
        .ecc_q       (ecc_q),
        .status      (lane_status),
        .any_uncorr  (any_uncorr),
        .uncorr_mask (uncorr_mask)
    );

    keccak_ft_region u_ft_region (
        .src            (ft_src),
        .theta_compute_d(theta_compute_d),
        .theta_col      (theta_col),
        .chi_cnt        (chi_cnt),
        .uncorr_mask    (uncorr_mask),
        .d_status       (theta_d_status),
        .replay_kind    (replay_kind),
        .fault_valid    (fault_valid)
    );

    sha3_low_power_gating u_low_power_gating (
        .clk      (clk),
        .rst_n    (rst_n),
        .sleep_en (sleep_en),
        .gated_clk(lane_clk)
    );

    keccak_state_bank u_state_bank (
        .lane_clk (lane_clk),
        .rst_n    (rst_n),
        .nxt_state(data_wr),
        .cur_state(cur_state)
    );

    always_ff @(posedge clk or negedge rst_n) begin : input_buffer_ff
        if (!rst_n) begin
            input_buffer_valid_q  <= 1'b0;
            input_buffer_data_q   <= '0;
            input_buffer_length_q <= '0;
            input_buffer_last_q   <= 1'b0;
        end
        else begin
            if (input_buffer_push) begin
                input_buffer_valid_q  <= 1'b1;
                input_buffer_data_q   <= msg_in;
                input_buffer_length_q <= msg_length;
                input_buffer_last_q   <= in_last;
            end
            else if (input_buffer_pop) begin
                input_buffer_valid_q <= 1'b0;
            end
        end
    end

endmodule