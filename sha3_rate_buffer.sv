module sha3_rate_buffer (
    input  sha3_pkg::state_t in_state,     
    input  logic [1087:0]    padded_block, 
    input  logic             absorb_en,    
    output sha3_pkg::state_t out_state
);
    import sha3_pkg::*;

    always_comb begin
        out_state = in_state;
        // 必須加上 automatic 關鍵字，確保每次觸發組合邏輯時都重設為 0
        automatic int x = 0;
        automatic int y = 0;

        for (int idx = 0; idx < 17; idx++) begin
            out_state[x][y] = in_state[x][y] ^ ({64{absorb_en}} & padded_block[64*idx +: 64]);
            
            x++;
            if (x == 5) begin
                x = 0;
                y++;
            end
        end
    end
endmodule