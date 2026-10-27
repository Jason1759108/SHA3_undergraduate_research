import sha3_pkg::*;
// Separate hierarchy is required; syn.tcl preserves predictor/datapath cones.
module keccak_theta_parity (
    input state_t in_state,
    input logic start,
    input logic [2:0] col,
    input logic [4:0] c_parity_saved,
    output logic [4:0] c_parity_live, lane_parity
);
    localparam int PREV [0:4] = '{4,0,1,2,3};
    localparam int NEXT [0:4] = '{1,2,3,4,0};
    logic [4:0] c_parity;
    always_comb begin
        c_parity_live = '0;
        if (start)
            for (int x = 0; x < 5; x++)
                for (int y = 0; y < 5; y++) c_parity_live[x] ^= ^in_state[x][y];
        c_parity = start ? c_parity_live : c_parity_saved;
        for (int y = 0; y < 5; y++)
            lane_parity[y] = (^in_state[col][y]) ^ c_parity[PREV[col]] ^ c_parity[NEXT[col]];
    end
endmodule

module keccak_chi_parity (
    input row_t row_in,
    input logic row0,
    input logic [4:0] round_index,
    output logic [4:0] lane_parity
);
    // p(a XOR (~b AND c)) = p(a) XOR p(c) XOR p(b AND c).
    // Predict from inputs; never re-encode the actual chi result.
    always_comb begin
        for (int x = 0; x < 5; x++)
            lane_parity[x] = (^row_in[x]) ^ (^row_in[(x+2)%5]) ^
                             (^(row_in[(x+1)%5] & row_in[(x+2)%5]));
        if (row0) lane_parity[0] ^= ^RC[round_index];
    end
endmodule
