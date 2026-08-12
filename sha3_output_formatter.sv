module sha3_output_formatter (
    input  logic             clk,
    input  logic             rst_n,
    input  logic             start,     // 來自 Control FSM 的啟動訊號
    input  sha3_pkg::state_t in_state,  // 運算完成的 1600-bit State
    output logic [31:0]      out_data,  // 32-bit 匯流排輸出
    output logic             out_valid, // 資料有效訊號
    output logic             done       // 8 個 Cycles 輸出完畢脈衝
);
    import sha3_pkg::*;

    // 若 sha3_pkg.sv 未包含此 Enum，可直接在此定義
    typedef enum logic [1:0] {
        SQZ_IDLE = 2'b00,
        SQZ_RUN  = 2'b01,
        SQZ_DONE = 2'b10
    } sqz_state_e;

    sqz_state_e s, s_next;
    logic [2:0] cnt, cnt_next; // 3-bit 計數器 (0 ~ 7) 對應 8 個 Cycles

    // =========================================================================
    // Block 1: 時序控制暫存器
    // =========================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s   <= SQZ_IDLE;
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
            SQZ_IDLE: begin
                if (start) begin
                    s_next   = SQZ_RUN;
                    cnt_next = 3'd0;        
                end
            end

            SQZ_RUN: begin
                if (cnt == 3'd7) begin
                    s_next   = SQZ_DONE;
                    cnt_next = 3'd0;
                end else begin
                    cnt_next = cnt + 3'd1;
                end
            end

            SQZ_DONE: begin
                s_next = SQZ_IDLE;
            end
            
            default: begin
                s_next   = SQZ_IDLE;
                cnt_next = 3'd0;
            end
        endcase
    end

    // =========================================================================
    // Block 3: 資料路徑與輸出運算
    // =========================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            out_data  <= 32'd0;
            out_valid <= 1'b0;
            done      <= 1'b0;
        end else begin
            out_valid <= 1'b0;  
            done      <= 1'b0;
            case (s)
                SQZ_RUN: begin
                    out_valid <= 1'b1;

                    // cnt[2:1] 代表 x (00=0, 01=1, 10=2, 11=3)
                    // cnt[0]   代表 高低半部 (0=低32, 1=高32)
                    if (cnt[0] == 1'b0) begin
                        out_data <= in_state[cnt[2:1]][0][31:0];
                    end else begin
                        out_data <= in_state[cnt[2:1]][0][63:32];
                    end
                end

                SQZ_DONE: begin
                    out_valid <= 1'b0;
                    done <= 1'b1;
                end
            endcase
        end
    end
endmodule