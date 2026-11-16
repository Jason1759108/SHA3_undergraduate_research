import sha3_pkg::*;
module keccak_chi_row #(
    parameter bit FT_ENABLE = 1'b1
) (
    input state_t in_state,
    input logic clk, rst_n, start, replay, hold,
    input logic [4:0] round_index,
    output logic [2:0] cnt,
    output state_t out_state,
    output logic done,
    output logic [24:0] lane_active, predicted_parity
);
    logic running, active;
    state_t frozen_state;
    row_t row_in;
    logic [4:0] lane_parity;
    logic [63:0] chi_lane_00, iota_lane_00;
    assign active = start || replay || running;
    keccak_iota u_iota (.round_index(round_index), .in_lane(chi_lane_00), .out_lane(iota_lane_00));
    always_comb begin
        for (int x = 0; x < 5; x++)
            row_in[x] = start ? in_state[x][0] : frozen_state[x][cnt];
    end
    generate if (FT_ENABLE) begin : gen_ft
        keccak_chi_parity u_predictor (
            .row_in(row_in), .row0(cnt == 3'd0),
            .round_index(round_index), .lane_parity(lane_parity)
        );
    end else begin : gen_no_ft
        assign lane_parity = '0;
    end endgenerate
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            running <= 1'b0;
            cnt <= '0;
            for (int x = 0; x < 5; x++)
                for (int y = 0; y < 5; y++) frozen_state[x][y] <= '0;
        end else begin
            // Rho/pi mixes rows: retain the original inputs through all retries.
            if (start) frozen_state <= in_state;
            if (active && !hold) begin
                if (cnt == 3'd4) begin
                    running <= 1'b0;
                    cnt <= '0;
                end else begin
                    running <= 1'b1;
                    cnt <= cnt + 3'd1;
                end
            end
        end
    end
    always_comb begin
        lane_active = '0;
        predicted_parity = '0;
        out_state = in_state;
        chi_lane_00 = row_in[0] ^ ((~row_in[1]) & row_in[2]);
        if (active) begin
            for (int x = 0; x < 5; x++) begin
                lane_active[cnt*5+x] = 1'b1;
                predicted_parity[cnt*5+x] = lane_parity[x];
                out_state[x][cnt] = row_in[x] ^ ((~row_in[(x+1)%5]) & row_in[(x+2)%5]);
            end
            if (cnt == 3'd0) out_state[0][0] = iota_lane_00;
        end
    end
    assign done = active && cnt == 3'd4 && !hold;
endmodule
