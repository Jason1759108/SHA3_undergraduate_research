import sha3_pkg::*;
module keccak_iota (
    input  logic [4:0]       round_index,
    input  logic [LANE_W-1:0] in_lane,
    output logic [LANE_W-1:0] out_lane
);

    // 只 XOR lane(0,0)。整包 1600-bit 轉送沒人用，會跟著 χ 輸出空轉。
    assign out_lane = in_lane ^ RC[round_index];

endmodule