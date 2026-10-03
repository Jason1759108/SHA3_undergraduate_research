import sha3_pkg::*;
module keccak_chi_row(
    input  state_t      in_state,
    input  logic        clk,
    input  logic        rst_n,
    input  logic        start,
    input  logic [4:0]  round_index,
    input  logic        replay,
    input  logic        hold,

    output logic [2:0]  cnt,
    output state_t      out_state,
    output logic        done,
    output logic [24:0] lane_active
);

    typedef enum logic {
        CHI_IDLE,
        CHI_CALC
    } chi_state_e;
    chi_state_e FSM_state, nxt_FSM_state;

    localparam int X_PLUS_1 [0:4] = '{1, 2, 3, 4, 0};
    localparam int X_PLUS_2 [0:4] = '{2, 3, 4, 0, 1};

    logic [2:0] cnt_next;

    logic [LANE_W-1:0] frozen_state [0:COL_NUM-1][1:4];
    logic [LANE_W-1:0] row0_snap [0:COL_NUM-1];
    logic [LANE_W-1:0] row0_src [0:COL_NUM-1];

    logic [LANE_W-1:0] chi_lane_00;
    logic [LANE_W-1:0] iota_lane_00;

    keccak_iota u_iota (
        .round_index(round_index),
        .in_lane    (chi_lane_00),
        .out_lane   (iota_lane_00)
    );

    always_comb begin: FSM_state_logic
        nxt_FSM_state = FSM_state;
        cnt_next      = cnt;

        if (hold) begin
            nxt_FSM_state = FSM_state;
            cnt_next      = cnt;
        end else if (replay) begin
            // 重寫當拍 row 後走成功拍的下一狀態，避免同一 row 再算一次。
            if (FSM_state == CHI_IDLE) begin
                nxt_FSM_state = CHI_CALC;
                cnt_next      = 3'd1;
            end else if (cnt == 3'd4) begin
                nxt_FSM_state = CHI_IDLE;
                cnt_next      = 3'd0;
            end else begin
                cnt_next = cnt + 3'd1;
            end
        end else begin
            case (FSM_state)
                CHI_IDLE: begin
                    if (start) begin
                        nxt_FSM_state = CHI_CALC;
                        cnt_next      = 3'd1;
                    end
                end

                CHI_CALC: begin
                    if (cnt == 3'd4) begin
                        nxt_FSM_state = CHI_IDLE;
                        cnt_next      = 3'd0;
                    end else begin
                        cnt_next = cnt + 3'd1;
                    end
                end

                default: begin
                    nxt_FSM_state = CHI_IDLE;
                    cnt_next      = 3'd0;
                end
            endcase
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin: FSM_state_ff
        if (!rst_n) begin
            FSM_state <= CHI_IDLE;
            cnt       <= 3'd0;
            for (int x = 0; x < COL_NUM; x++) begin
                row0_snap[x] <= '0;
                for (int y = 1; y < ROW_NUM; y++) begin
                    frozen_state[x][y] <= '0;
                end
            end
        end else begin
            FSM_state <= nxt_FSM_state;
            cnt       <= cnt_next;
            // start 當拍鎖 row0 與 frozen。hold 當拍 in_state 仍是原始 ρπ 結果。
            // replay 沒有 start，不可重鎖。
            if (start) begin
                for (int x = 0; x < COL_NUM; x++) begin
                    row0_snap[x] <= in_state[x][0];
                    for (int y = 1; y < ROW_NUM; y++) begin
                        frozen_state[x][y] <= in_state[x][y];
                    end
                end
            end
        end
    end

    always_comb begin
        for (int x = 0; x < COL_NUM; x++)
            row0_src[x] = start ? in_state[x][0] : row0_snap[x];
    end

    always_comb begin
        lane_active = 25'd0;
        out_state   = in_state;
        chi_lane_00 = '0;

        if ((FSM_state == CHI_IDLE) && (start || replay)) begin
            for (int x = 0; x < COL_NUM; x++) begin
                lane_active[0 * COL_NUM + x] = 1'b1;
                if (x == 0) begin
                    chi_lane_00 = row0_src[0] ^
                                   ((~row0_src[X_PLUS_1[0]]) & row0_src[X_PLUS_2[0]]);
                    out_state[0][0] = iota_lane_00;
                end else begin
                    out_state[x][0] = row0_src[x] ^
                                       ((~row0_src[X_PLUS_1[x]]) & row0_src[X_PLUS_2[x]]);
                end
            end
        end
        else if (FSM_state == CHI_CALC) begin
            for (int x = 0; x < COL_NUM; x++) begin
                lane_active[cnt * COL_NUM + x] = 1'b1;
                out_state[x][cnt] = frozen_state[x][cnt] ^
                                    ((~frozen_state[X_PLUS_1[x]][cnt]) &
                                     frozen_state[X_PLUS_2[x]][cnt]);
            end
        end
    end

    assign done = (FSM_state == CHI_CALC) && (cnt == 3'd4) && !hold;

endmodule
