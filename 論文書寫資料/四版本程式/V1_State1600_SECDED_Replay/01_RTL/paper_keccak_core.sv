// Paper-only standalone permutation boundary. Extracted from this version's
// original top; includes state bank, scheduler, lane gates and all FT logic.
// Excludes message buffer, padding, absorb XOR, SHA3 controller and formatter.
// load_state loads all 1600 bits in one idle cycle; not part of reported latency.
module paper_keccak_core (
    input logic clk, rst_n, start_process, load_state,
    input logic [1599:0] initial_state,
    output logic [1599:0] state_out,
    output logic process_done,
    input  logic          ft_inject_valid,
    input  logic [4:0]    ft_inject_lane,
    input  logic [71:0]   ft_inject_mask,
    input  logic          ft_d_inject_valid,
    input  logic [2:0]    ft_d_inject_col,
    input  logic [71:0]   ft_d_inject_mask

);
    import sha3_pkg::*;
    localparam logic [24:0] ALL_LANES=25'h1ffffff;
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


    for(genvar x=0;x<5;x++) for(genvar y=0;y<5;y++)
        assign state_out[(y*5+x)*64+:64]=cur_state[x][y];
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


    always_comb begin
        state_active_mask='0;
        nxt_state=cur_state;
        if(load_state) begin
            state_active_mask=ALL_LANES;
            for(int x=0;x<5;x++) for(int y=0;y<5;y++)
                nxt_state[x][y]=initial_state[(y*5+x)*64+:64];
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


endmodule
