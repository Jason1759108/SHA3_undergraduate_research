module keccak_state_bank (
    input  logic [24:0]        lane_clk,
    input  logic               rst_n,
    input  sha3_pkg::state_t   nxt_state,
    input  logic [24:0]        lane_wr_en,
    output sha3_pkg::state_t   cur_state
);
    // Lane "1 維座標 0~24" 與 "2 維座標 (x,y)" 的對應關係
    // 1 維座標 = y * 5 + x
    generate
        for (genvar y = 0; y < sha3_pkg::ROW_NUM; y++) begin : gen_lane_y
            for (genvar x = 0; x < sha3_pkg::COL_NUM; x++) begin : gen_lane_x
                localparam int LANE_IDX = y * sha3_pkg::COL_NUM + x;

                always_ff @(posedge lane_clk[LANE_IDX] or negedge rst_n) begin
                    if (!rst_n) begin
                        cur_state[x][y] <= '0;
                    end else if (lane_wr_en[LANE_IDX]) begin
                        cur_state[x][y] <= nxt_state[x][y];
                    end
                end
            end
        end
    endgenerate

endmodule
