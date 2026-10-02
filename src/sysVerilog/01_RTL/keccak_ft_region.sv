import sha3_pkg::*;

module keccak_ft_region (
    input  ft_src_e     src,
    input  logic        theta_compute_d,
    input  logic [2:0]  theta_col,
    input  logic [2:0]  chi_cnt, 
    input  logic [24:0] uncorr_mask,
    input  ft_status_e  d_status [1:4],
    output ft_replay_e  replay_kind,
    output logic        fault_valid
);

    logic any_lane_uncorr;
    logic any_d_uncorr;
    int unsigned col0_uncorr_count;

    always_comb begin
        any_lane_uncorr = |uncorr_mask;
        any_d_uncorr = 1'b0;
        col0_uncorr_count = 0;
        replay_kind = FT_REPLAY_NONE;

        for (int x = 1; x < COL_NUM; x++) begin
            if (d_status[x] == FT_ST_UNCORR)
                any_d_uncorr = 1'b1;
        end

        // LANE_IDX = y * 5 + x; col0 uses bits 0, 5, 10, 15, 20.
        for (int y = 0; y < ROW_NUM; y++) begin
            if (uncorr_mask[y * COL_NUM])
                col0_uncorr_count = col0_uncorr_count + 1;
        end

        case (src)
            FT_SRC_THETA: begin
                if (theta_compute_d) begin
                    // First cycle: C/D recovery takes priority over lane recovery.
                    if (any_d_uncorr || (col0_uncorr_count >= 2))
                        replay_kind = FT_REPLAY_THETA_CD;
                    else if (any_lane_uncorr)
                        replay_kind = FT_REPLAY_THETA_COL;
                end
                else begin
                    // D[0] is not stored. Guard the index before reading D[1:4].
                    if ((theta_col >= 3'd1) && (theta_col <= 3'd4)) begin
                        if (d_status[theta_col] == FT_ST_UNCORR)
                            replay_kind = FT_REPLAY_THETA_FROM0;
                    end

                    // Also allows a col0 lane replay without recomputing C/D.
                    if ((replay_kind == FT_REPLAY_NONE) && any_lane_uncorr)
                        replay_kind = FT_REPLAY_THETA_COL;
                end
            end

            FT_SRC_CHI: begin
                // All rows use the same replay kind; D status is irrelevant.
                if (any_lane_uncorr)
                    replay_kind = FT_REPLAY_CHI_ROW;
            end

            default: begin
                replay_kind = FT_REPLAY_NONE;
            end
        endcase

        fault_valid = (replay_kind != FT_REPLAY_NONE);
    end

endmodule
