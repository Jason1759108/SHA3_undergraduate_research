import sha3_pkg::*;

// 1600-bit 對照：一顆 (1612,1600) SECDED 包整顆 state。
// 頂層 / scheduler / θ / χ / region 腳位維持與 25-lane 版相同。
// 72-bit inject_mask 會映到該 lane 在大碼裡的對應 data / P 位，所以 PATTERN 的 mask 不用改。
module keccak_lane_ecc (
    input  logic        clk,
    input  logic        rst_n,
    input  logic [24:0]  lane_clk,
    input  logic [24:0]  lane_active,

    input  state_t      data_nxt,
    input  state_t      data_cur,

    input  logic [24:0]  inject_en,
    input  logic [71:0]  inject_mask [0:24],

    output state_t      data_wr,
    output logic [7:0]  ecc_q [0:24],
    output ft_status_e  status [0:24],
    output logic        any_uncorr,
    output logic [24:0]  uncorr_mask
);

    logic [FT_S_DATA_W-1:0] pack_nxt;
    logic [FT_S_DATA_W-1:0] enc_data;
    logic [FT_S_CODE_W-1:0] encoded_code;
    logic [FT_S_CODE_W-1:0] inject_xor;
    logic [FT_S_CODE_W-1:0] received_code;
    logic [FT_S_DATA_W-1:0] decoded_data;
    logic [FT_S_HAM_P-1:0]  state_syndrome;
    logic                   state_ext_fail;
    ft_status_e             global_status;
    logic                   any_active;
    logic                   write_ok;
    logic [24:0]            first_active;
    logic [7:0]             par_lo;
    logic [7:0]             par_hi;

    function automatic int map_lane_code_bit(input int I, input int k);
        int pos;
        int d;
        pos = k + 1;
        if (pos == FT_EXT_POS)
            return FT_S_CODE_W - 1;
        if (ft_pos_is_ham_p(pos))
            return pos - 1;
        d = 0;
        for (int t = 0; t < FT_DATA_W; t++) begin
            if (FT_DATA_POS[t] == pos)
                d = t;
        end
        return FT_S_DATA_POS[I * FT_DATA_W + d] - 1;
    endfunction

    always_comb begin
        for (int y = 0; y < ROW_NUM; y++) begin
            for (int x = 0; x < COL_NUM; x++) begin
                pack_nxt[(y * COL_NUM + x) * LANE_W +: LANE_W] = data_nxt[x][y];
            end
        end
    end

    assign any_active = |lane_active;
    assign enc_data   = any_active ? pack_nxt : '0;

    always_comb begin
        inject_xor = '0;
        for (int I = 0; I < 25; I++) begin
            if (inject_en[I]) begin
                for (int k = 0; k < FT_CODE_W; k++) begin
                    if (inject_mask[I][k])
                        inject_xor[map_lane_code_bit(I, k)] ^= 1'b1;
                end
            end
        end
    end

    assign received_code = encoded_code ^ inject_xor;

    keccak_hamming1600 u_hamming (
        .data_in  (enc_data),
        .code_out (encoded_code),
        .code_in  (received_code),
        .data_out (decoded_data),
        .syndrome (state_syndrome),
        .ext_fail (state_ext_fail),
        .status   (global_status)
    );

    assign write_ok   = any_active &&
                        ((global_status == FT_ST_OK) || (global_status == FT_ST_CORRECTED));
    assign any_uncorr = any_active && (global_status == FT_ST_UNCORR);

    always_comb begin
        first_active = 25'd0;
        for (int I = 0; I < 25; I++) begin
            if (lane_active[I] && (first_active == 25'd0))
                first_active[I] = 1'b1;
        end
    end

    always_comb begin
        uncorr_mask = 25'd0;
        for (int y = 0; y < ROW_NUM; y++) begin
            for (int x = 0; x < COL_NUM; x++) begin
                int I;
                I = y * COL_NUM + x;
                status[I] = lane_active[I] ? global_status : FT_ST_OK;
                data_wr[x][y] = write_ok && lane_active[I] ?
                                decoded_data[I * LANE_W +: LANE_W] :
                                data_cur[x][y];
            end
        end
        if (any_uncorr) begin
            if (|inject_en)
                uncorr_mask = inject_en & lane_active;
            else
                uncorr_mask = first_active;
        end
    end

    always_comb begin
        par_lo = '0;
        par_hi = '0;
        for (int p = 0; p < 7; p++)
            par_lo[p] = encoded_code[FT_S_HAM_POS[p]-1];
        par_lo[7] = encoded_code[FT_S_HAM_POS[7]-1];
        par_hi[0] = encoded_code[FT_S_HAM_POS[8]-1];
        par_hi[1] = encoded_code[FT_S_HAM_POS[9]-1];
        par_hi[2] = encoded_code[FT_S_HAM_POS[10]-1];
        par_hi[3] = encoded_code[FT_S_CODE_W-1];
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int I = 0; I < 25; I++)
                ecc_q[I] <= '0;
        end
        else if (write_ok) begin
            ecc_q[0] <= par_lo;
            ecc_q[1] <= par_hi;
        end
    end

endmodule
