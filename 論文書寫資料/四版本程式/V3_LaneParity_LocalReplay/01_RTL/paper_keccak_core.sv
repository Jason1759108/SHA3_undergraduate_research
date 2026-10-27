// Paper-only standalone permutation boundary. Extracted from this version's
// original top; includes state bank, scheduler, lane gates and all FT logic.
// Excludes message buffer, padding, absorb XOR, SHA3 controller and formatter.
// load_state loads all 1600 bits in one idle cycle; not part of reported latency.
module paper_keccak_core #(parameter bit FT_ENABLE=1'b1) (
    input logic clk, rst_n, start_process, load_state,
    input logic [1599:0] initial_state,
    output logic [1599:0] state_out,
    output logic process_done,
    input  logic          ft_inject_valid,
    input  logic [4:0]    ft_inject_lane,
    input  logic [63:0]   ft_inject_mask,
    input  logic          ft_c_inject_valid,
    input  logic [2:0]    ft_c_inject_col,
    input  logic [63:0]   ft_c_inject_mask,
    input  logic          ft_d_inject_valid,
    input  logic [2:0]    ft_d_inject_col,
    input  logic [63:0]   ft_d_inject_mask

);
    import sha3_pkg::*;
    localparam logic [24:0] ALL_LANES=25'h1ffffff;
    logic          theta_start;
    logic          theta_done;
    logic          theta_hold;
    logic          theta_replay;
    logic          theta_compute_d, theta_checkpoint_fault;
    logic [2:0]    theta_col;
    logic [24:0]   theta_lane_active;
    logic [24:0]   theta_predicted_parity, chi_predicted_parity;

    logic          chi_start;
    logic          chi_done;
    logic          chi_hold;
    logic          chi_replay;
    logic [2:0]    chi_cnt;
    logic [24:0]   chi_lane_active;

    logic [4:0]    round_index;

    logic          fault_valid;
    logic [24:0]   sleep_en;
    logic [24:0]   lane_clk;
    logic [24:0]   state_active_mask;

    logic [24:0]   mismatch_mask, predicted_parity;
    logic          parity_check_valid;
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
        .theta_start       (theta_start),
        .chi_start         (chi_start),
        .round_index       (round_index),
        .process_done      (process_done),
        .theta_hold        (theta_hold),
        .chi_hold          (chi_hold),
        .theta_replay      (theta_replay),
        .chi_replay        (chi_replay)
    );

    keccak_theta_serial #(.FT_ENABLE(FT_ENABLE)) u_theta (
        .in_state    (cur_state),
        .clk         (clk),
        .rst_n       (rst_n),
        .start       (theta_start),
        .replay      (theta_replay),
        .hold        (theta_hold),
        .c_inject_valid(ft_c_inject_valid),
        .c_inject_col(ft_c_inject_col),
        .c_inject_mask(ft_c_inject_mask),
        .d_inject_valid(ft_d_inject_valid),
        .d_inject_col  (ft_d_inject_col),
        .d_inject_mask (ft_d_inject_mask),
        .out_state   (theta_state),
        .done        (theta_done),
        .lane_active (theta_lane_active),
        .compute_d   (theta_compute_d),
        .checkpoint_fault(theta_checkpoint_fault),
        .col         (theta_col),
        .predicted_parity(theta_predicted_parity)
    );

    keccak_rho_pi_wire u_rho_pi (
        .in_state  (cur_state),
        .out_state (rho_pi_state)
    );

    keccak_chi_row #(.FT_ENABLE(FT_ENABLE)) u_chi (
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
        .lane_active (chi_lane_active),
        .predicted_parity(chi_predicted_parity)
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

    assign parity_check_valid = (|theta_lane_active) || (|chi_lane_active);
    assign predicted_parity = (|theta_lane_active) ? theta_predicted_parity : chi_predicted_parity;
    generate if (FT_ENABLE) begin : gen_ft
        keccak_lane_parity u_lane_parity (
            .data_nxt(nxt_state), .data_cur(cur_state),
            .lane_active(state_active_mask), .check_valid(parity_check_valid),
            .checkpoint_fault(theta_checkpoint_fault),
            .predicted_parity(predicted_parity),
            .inject_valid(ft_inject_valid), .inject_lane(ft_inject_lane),
            .inject_mask(ft_inject_mask), .data_wr(data_wr),
            .mismatch_mask(mismatch_mask), .fault_valid(fault_valid)
        );
    end else begin : gen_no_ft
        assign data_wr = nxt_state;
        assign mismatch_mask = '0;
        assign fault_valid = 1'b0;
    end endgenerate

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
