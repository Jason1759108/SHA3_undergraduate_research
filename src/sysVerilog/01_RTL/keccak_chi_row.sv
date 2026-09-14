module keccak_chi_row(
    input  sha3_pkg::state_t in_state,
    input  logic             clk,      
    input  logic             rst_n,    
    input  logic             start,   
    
    output sha3_pkg::state_t out_state,
    output logic             done,
    output logic [24:0]      lane_active
);
    import sha3_pkg::*;
    
    chi_state_e s, s_next;
    logic [2:0] cnt, cnt_next;

    sha3_pkg::state_t frozen_state;

    // =========================================================================
    // Block 1: 時序控制暫存器
    // =========================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s   <= CHI_IDLE;
            cnt <= 3'd0;
            frozen_state <= '{default: '0};
        end else begin
            s   <= s_next;
            cnt <= cnt_next;
            if (start) frozen_state <= in_state; // 啟動瞬間截取資料
        end 
    end

    // =========================================================================
    // Block 2: 下一個狀態與計數邏輯
    // =========================================================================
    always_comb begin 
        s_next   = s;
        cnt_next = cnt;

        case (s)
            CHI_IDLE: begin
                if (start) begin
                    s_next   = CHI_CALC; 
                    cnt_next = 3'd0;
                end
            end

            CHI_CALC: begin
                if (cnt == 3'd4) begin 
                    s_next   = CHI_IDLE;
                    cnt_next = 3'd0;
                end else begin
                    cnt_next = cnt + 3'd1;
                end
            end
            
            default: begin
                s_next   = CHI_IDLE;
                cnt_next = 3'd0;
            end
        endcase
    end

    // =========================================================================
    // Block 3: 純組合邏輯 (0 延遲, 0 暫存器)
    // =========================================================================
    always_comb begin
        lane_active = 25'd0;
        out_state   = in_state; 

        if (s == CHI_CALC) begin
            for (int x = 0; x < COL_NUM; x++) begin
                lane_active[cnt * COL_NUM + x] = 1'b1; 
                
                out_state[x][cnt] = frozen_state[x][cnt] ^ 
                                    ((~frozen_state[X_PLUS_1[x]][cnt]) & frozen_state[X_PLUS_2[x]][cnt]);
            end
        end
    end

    // =========================================================================
    // Block 4: Done 訊號 (維持不變)
    // =========================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) done <= 1'b0;
        else        done <= (s == CHI_CALC) && (cnt == 3'd4);
    end

endmodule