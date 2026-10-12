import sha3_pkg::*;

module keccak_lane_ecc (
    input  logic        clk,   // 保留原介面；校驗 FF 使用 lane_clk
    input  logic        rst_n,
    input  logic [24:0]  lane_clk,
    input  logic [24:0]  lane_active,

    input  state_t      data_nxt,
    input  state_t      data_cur, // 新增：UNCORR 時保留舊資料

    input  logic [24:0]  inject_en,
    input  logic [71:0]  inject_mask [0:24],

    output state_t      data_wr,
    output logic [7:0]  ecc_q [0:24],
    output ft_status_e  status [0:24],
    output logic        any_uncorr,
    output logic [24:0]  uncorr_mask
);

    generate
        for (genvar y = 0; y < ROW_NUM; y++) begin : gen_y
            for (genvar x = 0; x < COL_NUM; x++) begin : gen_x
                localparam int I = y * COL_NUM + x;

                logic [FT_DATA_W-1:0] enc_data;
                logic [FT_CODE_W-1:0] encoded_code;
                logic [FT_CODE_W-1:0] received_code;

                logic [FT_DATA_W-1:0] decoded_data;
                logic [FT_HAM_P-1:0]  lane_syndrome;
                logic                 lane_ext_fail;
                logic                 write_ok;

                logic [FT_DATA_W-1:0] reencode_data;
                logic [FT_CODE_W-1:0] clean_code;

                // 1. Inactive lane 的 encoder 輸入固定為 0
                assign enc_data = lane_active[I] ? data_nxt[x][y] : '0;

                // 2. 編碼後才注入；inactive lane 的 decoder 輸入為 0
                // inject_en 必須由外部限制為 Keccak-f 期間才有效
                assign received_code = lane_active[I]? (encoded_code ^ (inject_en[I] ? inject_mask[I] : 72'b0)) : 72'b0;

                // 3. 使用你目前合併 enc / dec 的 Hamming module
                keccak_hamming64 u_hamming (
                    .data_in  (enc_data),
                    .code_out (encoded_code),

                    .code_in  (received_code),
                    .data_out (decoded_data),
                    .syndrome (lane_syndrome),
                    .ext_fail (lane_ext_fail),
                    .status   (status[I])
                );

                // 4. 只有 OK 或 CORRECTED 才接受新資料
                assign write_ok = lane_active[I] && ((status[I] == FT_ST_OK) || (status[I] == FT_ST_CORRECTED));

                assign data_wr[x][y] = write_ok ? decoded_data : data_cur[x][y];

                assign uncorr_mask[I] = lane_active[I] && (status[I] == FT_ST_UNCORR);

                // 5. 修正後重新 encode，取得乾淨的校驗碼
                assign reencode_data = write_ok ? decoded_data : '0;

                // 這個 instance 只使用 encoder；
                // decoder 輸入綁 0，輸出不使用
                keccak_hamming64 u_reencode (
                    .data_in  (reencode_data),
                    .code_out (clean_code),

                    .code_in  (72'b0),
                    .data_out (),
                    .syndrome (),
                    .ext_fail (),
                    .status   ()
                );

                // 6. 校驗 FF 與資料 bank 使用同一個 lane clock
                //
                // ecc_q[I][0:6] 分別存 P1/P2/P4/P8/P16/P32/P64
                // ecc_q[I][7]   存 P_ext
                always_ff @(posedge lane_clk[I] or negedge rst_n) begin
                    if (!rst_n) begin
                        ecc_q[I] <= '0;
                    end
                    else if (write_ok) begin
                        for (int k = 0; k < FT_HAM_P; k++) begin
                            ecc_q[I][k] <= clean_code[FT_HAM_POS[k]-1];
                        end

                        ecc_q[I][7] <= clean_code[FT_CODE_W-1];
                    end
                    // 其他情況保持原本 ecc_q
                end
            end
        end
    endgenerate

    assign any_uncorr = |uncorr_mask;

endmodule