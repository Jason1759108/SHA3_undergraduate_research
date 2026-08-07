module keccak_rho_pi_wire (
    input  sha3_pkg::state_t in_state,
    output sha3_pkg::state_t out_state
);
    import sha3_pkg::*;

    // 使用 generate 在編譯期強制展開成純連線 (Wire)
    genvar x, y;
    generate
        for (x = 0; x < 5; x++) begin : gen_rho_x
            for(y = 0; y < 5; y++) begin : gen_rho_y
                // 利用 localparam 在編譯期把 offset 算死
                localparam int offset = RHO_OFFSET[PI_Y_MAP[x][y]][x];

                if (offset == 0) begin
                    assign out_state[x][y] = in_state[PI_Y_MAP[x][y]][x];
                end else begin
                    assign out_state[x][y] = (in_state[PI_Y_MAP[x][y]][x] << offset) | 
                                             (in_state[PI_Y_MAP[x][y]][x] >> (LANE_W - offset));
                end 
            end
        end
    endgenerate
endmodule