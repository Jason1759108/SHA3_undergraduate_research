import sha3_pkg::*;
module keccak_theta_serial (
    input  state_t      in_state,
    input  logic        clk,
    input  logic        rst_n,
    input  logic        start,
    
    output state_t      out_state,
    output logic        done,
    output logic [24:0] lane_active
);

    typedef enum logic [1:0] {
        THETA_IDLE,  
        THETA_CALC_C,
        THETA_CALC_D,
        THETA_UPDATE
    } theta_state_e;
    theta_state_e FSM_state, nxt_FSM_state;

    localparam logic [2:0] X_PLUS_4  [0 : COL_NUM-1] = '{3'd4, 3'd0, 3'd1, 3'd2, 3'd3};
    localparam logic [2:0] X_PLUS_1  [0 : COL_NUM-1] = '{3'd1, 3'd2, 3'd3, 3'd4, 3'd0};

    logic [LANE_W-1:0] C [0 : COL_NUM-1];
    logic [LANE_W-1:0] D [0 : COL_NUM-1];
    logic [2:0] col, nxt_col;

    always_comb begin: FSM_state_logic
        nxt_FSM_state = FSM_state;
        nxt_col       = col;
        
        case (FSM_state)
            THETA_IDLE: begin
                if (start) nxt_FSM_state = THETA_CALC_C;
            end

            THETA_CALC_C: begin
                nxt_FSM_state = THETA_CALC_D;
            end

            THETA_CALC_D: begin
                nxt_FSM_state = THETA_UPDATE;
                nxt_col       = 3'd0;        
            end

            THETA_UPDATE: begin
                if (col == 3'd4) begin
                    nxt_FSM_state   = THETA_IDLE;
                    nxt_col         = 3'd0;
                end else begin
                    nxt_col = col + 3'd1;
                end
            end
            
            default: begin
                nxt_FSM_state   = THETA_IDLE;
                nxt_col         = 3'd0;
            end
        endcase
    end

    always_ff @(posedge clk or negedge rst_n) begin: FSM_state_ff
        if (!rst_n) begin
            FSM_state   <= THETA_IDLE;
            col         <= 3'd0;
        end else begin
            FSM_state   <= nxt_FSM_state;
            col         <= nxt_col;
        end
    end

    always_comb begin
        lane_active = 25'd0;
        out_state   = in_state; 

        if (FSM_state == THETA_UPDATE) begin
            for (int y = 0; y < ROW_NUM; y++) begin
                lane_active[y * COL_NUM + col] = 1'b1;
                out_state[col][y] = in_state[col][y] ^ D[col];
            end
        end
    end

    assign done = (FSM_state == THETA_UPDATE) && (col == 3'd4);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int x = 0; x < COL_NUM; x++) begin 
                C[x] <= '0; 
                D[x] <= '0; 
            end

        end else begin
            case (FSM_state)
                THETA_CALC_C: begin
                    for (int x = 0; x < COL_NUM; x++) begin
                        C[x] <= in_state[x][0] ^ 
                                in_state[x][1] ^ 
                                in_state[x][2] ^ 
                                in_state[x][3] ^ 
                                in_state[x][4];
                    end
                end
                
                THETA_CALC_D: begin
                    for (int x = 0; x < COL_NUM; x++) begin
                        D[x] <= C[X_PLUS_4[x]] ^ {C[X_PLUS_1[x]][LANE_W - 2 : 0], C[X_PLUS_1[x]][LANE_W - 1]};
                    end
                end
            endcase
        end
    end

endmodule
