import sha3_pkg::*;
module keccak_theta_serial #(
    parameter bit FT_ENABLE = 1'b1
) (
    input state_t in_state,
    input logic clk, rst_n, start, replay, hold,
    input logic c_inject_valid,
    input logic [2:0] c_inject_col,
    input logic [63:0] c_inject_mask,
    input logic d_inject_valid,
    input logic [2:0] d_inject_col,
    input logic [63:0] d_inject_mask,
    output state_t out_state,
    output logic done,
    output logic [24:0] lane_active, predicted_parity,
    output logic compute_d, checkpoint_fault,
    output logic [2:0] col
);
    logic running, active, compute_c;
    logic [63:0] c_live [0:4], c_saved [0:4];
    logic [4:0] c_parity_live, c_parity_saved, lane_parity;
    logic [63:0] d_value;
    localparam int PREV [0:4] = '{4,0,1,2,3};
    localparam int NEXT [0:4] = '{1,2,3,4,0};
    assign active = start || replay || running;
    assign compute_d = active;
    assign compute_c = active && col == 3'd0;

    // Failed columns never commit. Only C is checkpointed (320 bits).
    always_comb begin
        for (int x = 0; x < 5; x++) begin
            c_live[x] = '0;
            if (compute_c)
                for (int y = 0; y < 5; y++) c_live[x] ^= in_state[x][y];
            if (FT_ENABLE && compute_c && c_inject_valid && c_inject_col == 3'(x))
                c_live[x] ^= c_inject_mask;
        end
        if (compute_c)
            d_value = c_live[PREV[col]] ^ {c_live[NEXT[col]][62:0], c_live[NEXT[col]][63]};
        else
            d_value = c_saved[PREV[col]] ^ {c_saved[NEXT[col]][62:0], c_saved[NEXT[col]][63]};
        // Injection corrupts the datapath, independently of the predictor.
        if (FT_ENABLE && active && d_inject_valid && d_inject_col == col)
            d_value ^= d_inject_mask;
    end
    generate if (FT_ENABLE) begin : gen_ft
        keccak_theta_parity u_predictor (
            .in_state(in_state), .start(compute_c), .col(col),
            .c_parity_saved(c_parity_saved),
            .c_parity_live(c_parity_live), .lane_parity(lane_parity)
        );
    end else begin : gen_no_ft
        assign c_parity_live = '0;
        assign lane_parity = '0;
    end endgenerate

    // Validate all five C words before trusting the checkpoint, including C
    // words not used by D[0]. A col0 retry can still read the entire old state.
    always_comb begin
        checkpoint_fault = 1'b0;
        if (FT_ENABLE && compute_c)
            for (int x = 0; x < 5; x++)
                checkpoint_fault |= (^c_live[x]) ^ c_parity_live[x];
    end
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            running <= 1'b0;
            col <= '0;
            c_parity_saved <= '0;
            for (int x = 0; x < 5; x++) c_saved[x] <= '0;
        end else begin
            // Commit C only with a successful col0. A failed col0 recomputes C.
            if (compute_c && !hold) begin
                for (int x = 0; x < 5; x++) c_saved[x] <= c_live[x];
                c_parity_saved <= c_parity_live;
            end
            if (active && !hold) begin
                if (col == 3'd4) begin
                    running <= 1'b0;
                    col <= '0;
                end else begin
                    running <= 1'b1;
                    col <= col + 3'd1;
                end
            end
        end
    end
    always_comb begin
        out_state = in_state;
        lane_active = '0;
        predicted_parity = '0;
        if (active) begin
            for (int y = 0; y < 5; y++) begin
                lane_active[y*5+int'(col)] = 1'b1;
                predicted_parity[y*5+int'(col)] = lane_parity[y];
                out_state[col][y] = in_state[col][y] ^ d_value;
            end
        end
    end
    assign done = active && col == 3'd4 && !hold;
endmodule
