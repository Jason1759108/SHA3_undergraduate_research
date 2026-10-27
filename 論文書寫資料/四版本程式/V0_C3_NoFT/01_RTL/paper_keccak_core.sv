// Paper-only standalone permutation boundary. Extracted from this version's
// original top; includes state bank, scheduler, lane gates and all FT logic.
// Excludes message buffer, padding, absorb XOR, SHA3 controller and formatter.
// load_state loads all 1600 bits in one idle cycle; not part of reported latency.
module paper_keccak_core (
    input logic clk, rst_n, start_process, load_state,
    input logic [1599:0] initial_state,
    output logic [1599:0] state_out,
    output logic process_done
);
    import sha3_pkg::*;
    localparam logic [24:0] ALL_LANES=25'h1ffffff;
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


    for(genvar x=0;x<5;x++) for(genvar y=0;y<5;y++)
        assign state_out[(y*5+x)*64+:64]=cur_state[x][y];
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
        .round_index (round_index),
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

    sha3_low_power_gating u_low_power_gating (
        .clk      (clk),
        .rst_n    (rst_n),
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
