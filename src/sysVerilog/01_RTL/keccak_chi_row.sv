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
    
    logic [2:0] cnt, cnt_next;
    state_t frozen_state;

    always_comb begin: FSM_state_logic
        nxt_FSM_state = FSM_state;
        cnt_next = cnt;

        case (FSM_state)
            CHI_IDLE: begin
                if (start) begin
                    nxt_FSM_state   = CHI_CALC; 
                    cnt_next        = 3'd0;
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
            FSM_state   <= CHI_IDLE;
            cnt         <= 3'd0;
            frozen_state <= '{default: '0};
        end else begin
            FSM_state   <= nxt_FSM_state;
            cnt         <= cnt_next;
            if (start) frozen_state <= in_state; // 啟動瞬間截取資料
        end 
    end

    always_comb begin
        lane_active = 25'd0;
        out_state   = in_state; 

        if (FSM_state == CHI_CALC) begin
            for (int x = 0; x < COL_NUM; x++) begin
                lane_active[cnt * COL_NUM + x] = 1'b1; 
                
                out_state[x][cnt] = frozen_state[x][cnt] ^ 
                                    ((~frozen_state[X_PLUS_1[x]][cnt]) & frozen_state[X_PLUS_2[x]][cnt]);
            end
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) done <= 1'b0;
        else        done <= (FSM_state == CHI_CALC) && (cnt == 3'd4);
    end

endmodule