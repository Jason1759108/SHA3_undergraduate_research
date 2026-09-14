module sha3_absorb_xor (
    input  sha3_pkg::state_t in_state,     
    input  logic [1087:0]    padded_block, 
    input  logic             absorb_en,    
    output sha3_pkg::state_t out_state
);
    import sha3_pkg::*;

    always_comb begin
        out_state = in_state;

        if (absorb_en) begin
            for (int idx = 0; idx < 17; idx++) begin
                out_state[idx % COL_NUM][idx / COL_NUM] =
                    in_state[idx % COL_NUM][idx / COL_NUM]
                    ^ padded_block[idx*LANE_W +: LANE_W];
            end
        end
    end
endmodule
