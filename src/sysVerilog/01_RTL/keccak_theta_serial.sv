module keccak_theta_serial (
    input  sha3_pkg::state_t in_state,
    input  logic             clk,
    input  logic             rst_n,
    input  logic             start,
    
    output sha3_pkg::state_t out_state,
    output logic             done,
    output logic [24:0]      lane_active
);
    import sha3_pkg::*;

    logic [LANE_W-1:0] C [0 : COL_NUM-1];
    logic [LANE_W-1:0] D [0 : COL_NUM-1];
    
    localparam logic [2:0] left_table  [0 : COL_NUM-1] = '{3'b100, 3'b000, 3'b001, 3'b010, 3'b011};
    localparam logic [2:0] right_table [0 : COL_NUM-1] = '{3'b001, 3'b010, 3'b011, 3'b100, 3'b000};

    theta_state_e s, s_next;
    logic [2:0] cnt, cnt_next;

    // =========================================================================
    // Block 1: 時序控制暫存器
    // =========================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s   <= THETA_IDLE;
            cnt <= 3'd0;
        end else begin
            s   <= s_next;
            cnt <= cnt_next;
        end
    end

    // =========================================================================
    // Block 2: 下一個狀態與計數邏輯 
    // =========================================================================
    always_comb begin 
        s_next   = s;
        cnt_next = cnt;
        
        case (s)
            THETA_IDLE: begin
                if (start) begin
                    s_next   = THETA_CALC_C;
                    cnt_next = 3'd0;        
                end
            end

            THETA_CALC_C: begin
                if (cnt == 3'd4) begin
                    s_next   = THETA_CALC_D;
                    cnt_next = 3'd0;
                end else begin
                    cnt_next = cnt + 3'd1;
                end
            end

            THETA_CALC_D: begin
                s_next = THETA_UPDATE;
            end

            THETA_UPDATE: begin
                if (cnt == 3'd4) begin
                    s_next   = THETA_IDLE;
                    cnt_next = 3'd0;
                end else begin
                    cnt_next = cnt + 3'd1;
                end
            end
            
            default: begin
                s_next   = THETA_IDLE;
                cnt_next = 3'd0;
            end
        endcase
    end

    // =========================================================================
    // Block 3: 純組合邏輯 (0 延遲, 0 狀態暫存器)
    // =========================================================================
    always_comb begin
        lane_active = 25'd0;
        out_state   = in_state; // 預設 Pass-through

        if (s == THETA_UPDATE) begin
            for (int y = 0; y < ROW_NUM; y++) begin
                lane_active[y * COL_NUM + cnt] = 1'b1;
                
                out_state[cnt][y] = in_state[cnt][y] ^ D[cnt];
            end
        end
    end

    // =========================================================================
    // Block 4: 內部 Parity (C, D) 運算暫存與 Done 訊號
    // =========================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int x = 0; x < COL_NUM; x++) begin C[x] <= '0; D[x] <= '0; end
            done <= 1'b0;
        end else begin
            done <= (s == THETA_UPDATE) && (cnt == 3'd4); 

            case (s)
                THETA_CALC_C: begin
                    C[cnt] <= in_state[cnt][0] ^ 
                            in_state[cnt][1] ^ 
                            in_state[cnt][2] ^ 
                            in_state[cnt][3] ^ 
                            in_state[cnt][4];
                end
                
                THETA_CALC_D: begin
                    for (int x = 0; x < COL_NUM; x++) begin
                        D[x] <= C[left_table[x]] ^ {C[right_table[x]][LANE_W - 2 : 0], C[right_table[x]][LANE_W - 1]};
                    end
                end
            endcase
        end
    end

endmodule