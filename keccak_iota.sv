module keccak_iota (
    input  logic [4:0]       round_index,
    input  sha3_pkg::state_t in_state,
    output sha3_pkg::state_t out_state
);
    import sha3_pkg::*;

    always_comb begin
        for (int x = 0; x < COL_NUM; x++) begin
            for (int y = 0; y < ROW_NUM; y++) begin
                out_state[x][y] = in_state[x][y];
            end
        end

        out_state[0][0] = in_state[0][0] ^ RC[round_index];
    end
endmodule
