module sha3_absorb_xor (
    input  sha3_pkg::state_t in_state,     
    input  logic [1087:0]    padded_block, 
    input  logic             absorb_en,    
    output sha3_pkg::state_t out_state
);
    import sha3_pkg::*;

    always_comb begin
        // Operand isolation：absorb 沒開時不要整包轉送 in_state。
        // Top 只在 absorb_en 才用 absorbed_state；Keccak 期間輸出 0，
        // 避免 1600-bit 複製跟著 cur_state 空轉。不新增長 clock。
        for (int x = 0; x < COL_NUM; x++) begin
            for (int y = 0; y < ROW_NUM; y++) begin
                out_state[x][y] = '0;
            end
        end

        if (absorb_en) begin
            for (int x = 0; x < COL_NUM; x++) begin
                for (int y = 0; y < ROW_NUM; y++) begin
                    out_state[x][y] = in_state[x][y];
                end
            end

            for (int idx = 0; idx < 17; idx++) begin
                out_state[idx % COL_NUM][idx / COL_NUM] =
                    in_state[idx % COL_NUM][idx / COL_NUM]
                    ^ padded_block[idx*LANE_W +: LANE_W];
            end
        end
    end
endmodule