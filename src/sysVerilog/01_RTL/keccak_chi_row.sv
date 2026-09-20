import sha3_pkg::*;
module keccak_chi_row(
    input  state_t      in_state,
    input  logic        clk,      
    input  logic        rst_n,    
    input  logic        start,   
    
    output state_t      out_state,
    output logic        done,
    output logic [24:0] lane_active
);
    
    typedef enum logic {
        CHI_IDLE,
        CHI_CALC
    } chi_state_e;
    chi_state_e FSM_state, nxt_FSM_state;

    localparam int X_PLUS_1 [0:4] = '{1, 2, 3, 4, 0}; // (x + 1) % 5
    localparam int X_PLUS_2 [0:4] = '{2, 3, 4, 0, 1}; // (x + 2) % 5
    
    logic [2:0] cnt, cnt_next;

    // Snapshot 只存 row1~row4。row0 的 χ 已經在 start 那一拍用 in_state
    // 算完，frozen 的 row0 從來沒被讀過，不必再佔 320-bit FF。
    // row1~4 仍讀凍結值，Pi 跨 row 的髒資料保護維持不變。
    logic [LANE_W-1:0] frozen_state [0:COL_NUM-1][1:4];

    always_comb begin: FSM_state_logic
        nxt_FSM_state = FSM_state;
        cnt_next = cnt;

        case (FSM_state)
            CHI_IDLE: begin
                if (start) begin
                    nxt_FSM_state   = CHI_CALC; 
                    // row0 已經在「這個 start cycle」做掉了，CHI_CALC 只需要
                    // 再跑 row1~row4，所以從 cnt=1 開始，不是 0。
                    cnt_next        = 3'd1;
                end
            end

            CHI_CALC: begin
                if (cnt == 3'd4) begin 
                    nxt_FSM_state   = CHI_IDLE;
                    cnt_next        = 3'd0;
                end else begin
                    cnt_next = cnt + 3'd1;
                end
            end
            
            default: begin
                nxt_FSM_state   = CHI_IDLE;
                cnt_next        = 3'd0;
            end
        endcase
    end

    always_ff @(posedge clk or negedge rst_n) begin: FSM_state_ff
        if (!rst_n) begin
            FSM_state <= CHI_IDLE;
            cnt       <= 3'd0;
            for (int x = 0; x < COL_NUM; x++) begin
                for (int y = 1; y < ROW_NUM; y++) begin
                    frozen_state[x][y] <= '0;
                end
            end
        end else begin
            FSM_state <= nxt_FSM_state;
            cnt       <= cnt_next;
            // 啟動瞬間截取資料，供 row1~4 用 (row0 這個 cycle 直接用 in_state)。
            if (start) begin
                for (int x = 0; x < COL_NUM; x++) begin
                    for (int y = 1; y < ROW_NUM; y++) begin
                        frozen_state[x][y] <= in_state[x][y];
                    end
                end
            end
        end 
    end

    always_comb begin
        lane_active = 25'd0;
        out_state   = in_state; 

        if ((FSM_state == CHI_IDLE) && start) begin
            // row0：直接用 in_state，frozen_state 這個 cycle「還沒」鎖存好
            // (鎖存跟這個 cycle 的運算是同一個 edge 完成)，但數值上
            // in_state 跟「frozen_state 鎖存後會拿到的值」完全相同，
            // 所以提早用 in_state 算 row0 是安全的。
            for (int x = 0; x < COL_NUM; x++) begin
                lane_active[0 * COL_NUM + x] = 1'b1;
                out_state[x][0] = in_state[x][0] ^
                                   ((~in_state[X_PLUS_1[x]][0]) & in_state[X_PLUS_2[x]][0]);
            end
        end
        else if (FSM_state == CHI_CALC) begin
            // row1~row4：讀凍結快照，避免 Pi 跨 row 搬動造成髒資料。
            for (int x = 0; x < COL_NUM; x++) begin
                lane_active[cnt * COL_NUM + x] = 1'b1; 
                
                out_state[x][cnt] = frozen_state[x][cnt] ^ 
                                    ((~frozen_state[X_PLUS_1[x]][cnt]) & frozen_state[X_PLUS_2[x]][cnt]);
            end
        end
    end

    assign done = (FSM_state == CHI_CALC) && (cnt == 3'd4);

endmodule