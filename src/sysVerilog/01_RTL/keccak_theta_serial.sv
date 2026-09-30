import sha3_pkg::*;
module keccak_theta_serial (
    input  state_t      in_state,
    input  logic        clk,
    input  logic        rst_n,
    input  logic        start,
    input  logic        replay,
    input  ft_replay_e  replay_kind,

    output state_t      out_state,
    output logic        done,
    output logic [24:0] lane_active,
    output logic        compute_d,
    output logic [2:0]  col,
    output ft_status_e  d_status [1:4]
);

    typedef enum logic {
        THETA_IDLE,
        THETA_UPDATE
    } theta_state_e;
    theta_state_e FSM_state, nxt_FSM_state;

    localparam logic [2:0] X_PLUS_4  [0 : COL_NUM-1] = '{3'd4, 3'd0, 3'd1, 3'd2, 3'd3};
    localparam logic [2:0] X_PLUS_1  [0 : COL_NUM-1] = '{3'd1, 3'd2, 3'd3, 3'd4, 3'd0};

    logic [LANE_W-1:0] C_comb [0 : COL_NUM-1];
    logic [LANE_W-1:0] D_comb [0 : COL_NUM-1];
    // col0 在 start 當拍用 D_comb[0] 寫完，D[0] 從來沒被讀過，不必再佔 64-bit FF。
    logic [LANE_W-1:0] D [1:4];
    logic [2:0]        nxt_col;

    logic              open_c_tree;
    logic              latch_D;
    logic              need_cd;
    logic              col_replay_col0;

    logic [FT_CODE_W-1:0] D_enc  [1:4];
    logic [FT_CODE_W-1:0] D_code [1:4];
    logic [LANE_W-1:0]    D_dec  [1:4];
    logic [FT_HAM_P-1:0]  D_syn  [1:4];
    logic                 D_ext  [1:4];
    logic [LANE_W-1:0]    D_use  [1:4];

    // CD / FROM0 都當「再做一次 start 拍」。FROM0 不另做 5 拍 hold。
    assign need_cd = replay &&
                     ((replay_kind == FT_REPLAY_THETA_CD) ||
                      (replay_kind == FT_REPLAY_THETA_FROM0));

    // COL 且人還在 IDLE：只重寫 col0，要開樹才有 D_comb[0]。
    assign col_replay_col0 = replay &&
                             (replay_kind == FT_REPLAY_THETA_COL) &&
                             (FSM_state == THETA_IDLE);

    assign open_c_tree = ((FSM_state == THETA_IDLE) && start) ||
                         need_cd ||
                         col_replay_col0;

    // COL 禁止重鎖 D[1:4]；其餘開樹的拍（正常 start / CD / FROM0）要鎖。
    assign latch_D = open_c_tree &&
                     !(replay && (replay_kind == FT_REPLAY_THETA_COL));

    // 給 region：這一拍是不是 C/D 拍。
    assign compute_d = open_c_tree;

    always_comb begin
        for (int x = 0; x < COL_NUM; x++) begin
            C_comb[x] = (in_state[x][0] & {LANE_W{open_c_tree}}) ^
                        (in_state[x][1] & {LANE_W{open_c_tree}}) ^
                        (in_state[x][2] & {LANE_W{open_c_tree}}) ^
                        (in_state[x][3] & {LANE_W{open_c_tree}}) ^
                        (in_state[x][4] & {LANE_W{open_c_tree}});
        end
    end

    always_comb begin
        for (int x = 0; x < COL_NUM; x++) begin
            D_comb[x] = C_comb[X_PLUS_4[x]] ^
                        {C_comb[X_PLUS_1[x]][LANE_W - 2 : 0],
                         C_comb[X_PLUS_1[x]][LANE_W - 1]};
        end
    end

    genvar gx;
    generate
        for (gx = 1; gx <= 4; gx++) begin : gen_d_ecc
            keccak_hamming64 u_d_ham (
                .data_in (D_comb[gx]),
                .code_out(D_enc[gx]),
                .code_in (open_c_tree ? D_enc[gx] : D_code[gx]),
                .data_out(D_dec[gx]),
                .syndrome(D_syn[gx]),
                .ext_fail(D_ext[gx]),
                .status  (d_status[gx])
            );

            assign D_use[gx] = (d_status[gx] == FT_ST_UNCORR) ? D[gx] : D_dec[gx];
        end
    endgenerate

    always_comb begin: FSM_state_logic
        nxt_FSM_state = FSM_state;
        nxt_col       = col;

        if (replay) begin
            case (replay_kind)
                FT_REPLAY_THETA_COL: begin
                    // hold：UPDATE 重寫當前 col；IDLE 重寫 col0。
                end
                FT_REPLAY_THETA_CD,
                FT_REPLAY_THETA_FROM0: begin
                    nxt_FSM_state = THETA_UPDATE;
                    nxt_col       = 3'd1;
                end
                default: begin
                end
            endcase
        end else begin
            case (FSM_state)
                THETA_IDLE: begin
                    if (start) begin
                        nxt_FSM_state = THETA_UPDATE;
                        nxt_col       = 3'd1;
                    end
                end

                THETA_UPDATE: begin
                    if (col == 3'd4) begin
                        nxt_FSM_state = THETA_IDLE;
                        nxt_col       = 3'd0;
                    end else begin
                        nxt_col = col + 3'd1;
                    end
                end

                default: begin
                    nxt_FSM_state = THETA_IDLE;
                    nxt_col       = 3'd0;
                end
            endcase
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin: FSM_state_ff
        if (!rst_n) begin
            FSM_state <= THETA_IDLE;
            col       <= 3'd0;
        end else begin
            FSM_state <= nxt_FSM_state;
            col       <= nxt_col;
        end
    end

    always_comb begin
        lane_active = 25'd0;
        out_state   = in_state;

        if (open_c_tree) begin
            for (int y = 0; y < ROW_NUM; y++) begin
                lane_active[y * COL_NUM + 0] = 1'b1;
                out_state[0][y] = in_state[0][y] ^ D_comb[0];
            end
        end
        else if (FSM_state == THETA_UPDATE) begin
            for (int y = 0; y < ROW_NUM; y++) begin
                lane_active[y * COL_NUM + col] = 1'b1;
                out_state[col][y] = in_state[col][y] ^ D_use[col];
            end
        end
    end

    assign done = (FSM_state == THETA_UPDATE) && (col == 3'd4) && !replay;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int x = 1; x < COL_NUM; x++) begin
                D[x]      <= '0;
                D_code[x] <= '0;
            end
        end else if (latch_D) begin
            for (int x = 1; x < COL_NUM; x++) begin
                D[x]      <= D_comb[x];
                D_code[x] <= D_enc[x];
            end
        end
    end

endmodule
