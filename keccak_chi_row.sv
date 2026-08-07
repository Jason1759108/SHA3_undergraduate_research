module keccak_chi_row(
    input  sha3_pkg::state_t in_state,
    input  logic             clk,      
    input  logic             rst_n,    
    input  logic             start,   
    
    output sha3_pkg::state_t out_state,
    output logic             done      
);
    import sha3_pkg::*;
    
    chi_state_e s, s_next;
    logic [2:0] cnt, cnt_next; // 計數器：0 ~ 4 代表 5 個 Row

    // =========================================================================
    // Block 1: 時序控制暫存器
    // =========================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s   <= CHI_IDLE;
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
    // Block 3: 資料路徑與輸出運算
    // =========================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            out_state <= '{default: '0};
            done      <= 1 meb0;
        end else begin
            case (s)
                CHI_IDLE: begin
                    done <= 1'b0;
                end

                CHI_CALC: begin
                    for (int x = 0; x < 5; x++) begin
                        out_state[x][cnt] <= in_state[x][cnt] ^ 
                                             ((~in_state[X_PLUS_1[x]][cnt]) & in_state[X_PLUS_2[x]][cnt]);    
                    end

                    if (cnt == 3'd4) begin
                        done <= 1'b1;
                    end
                end
            endcase
        end
    end

endmodule