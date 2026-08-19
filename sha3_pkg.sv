package sha3_pkg;

    // 1. 定義 Keccak 的基本維度
    localparam int LANE_W  = 64;
    localparam int ROW_NUM = 5;
    localparam int COL_NUM = 5;
    
    // 2. 定義 3D Array 型別，完美對應 25 個 Lane
    // 採用 [0 : COL_NUM-1] 正向索引，方便寫 (x+1) mod 5 等模除運算
    // 未來所有模組的 I/O 只要宣告 state_t，即可防止腳位長度接錯
    typedef logic [LANE_W-1:0] state_t [0 : COL_NUM-1][0 : ROW_NUM-1];
    
    // 3. 定義一整個 Row (5個 Lane, 共 320 bits)，Chi Unit 會用到
    typedef logic [LANE_W-1:0] row_t [0 : COL_NUM-1];

    // 4. 定義一整個 Column (5個 Lane, 共 320 bits)，Theta Unit 會用到
    typedef logic [LANE_W-1:0] col_t [0 : ROW_NUM-1];

    // 5. 定義大腦的狀態機 Enum (FSM States)
    typedef enum logic [2:0] {
        ST_IDLE      = 3'b000,
        ST_ABSORB    = 3'b001,
        ST_PAD       = 3'b010,
        ST_RUN_ROUND = 3'b011,
        ST_SQUEEZE   = 3'b100,
        ST_DONE      = 3'b101
    } top_fsm_state_e;

    // 6. 定義 24 個 Round Constants (FIPS 202 標準規範，Iota 步驟使用)
    parameter logic [63:0] RC [0:23] = '{
        64'h0000000000000001, 64'h0000000000008082, 64'h800000000000808A, 64'h8000000080008000,
        64'h000000000000808B, 64'h0000000080000001, 64'h8000000080008081, 64'h8000000000008009,
        64'h000000000000008A, 64'h0000000000000088, 64'h0000000080008009, 64'h000000008000000A,
        64'h000000008000808B, 64'h800000000000008B, 64'h8000000000008089, 64'h8000000000008003,
        64'h8000000000008002, 64'h8000000000000080, 64'h000000000000808A, 64'h800000008000000A,
        64'h8000000080008081, 64'h8000000000008080, 64'h0000000080000001, 64'h8000000080008088
    };

    // 7. 定義 Rho 步驟專用的 25 個位移偏移量 (Rotation Offsets) [x][y]
    // 根據 FIPS 202 規範，代表各個 Lane 向左循環位移 (Circular Shift) 的位數
    parameter int RHO_OFFSET [0:4][0:4] = '{
        // y=0    y=1    y=2    y=3    y=4
        '{   0,    36,     3,    41,    18}, // x=0
        '{   1,    44,    10,    45,     2}, // x=1
        '{  62,     6,    43,    15,    61}, // x=2
        '{  28,    55,    25,    21,    56}, // x=3
        '{  27,    20,    39,     8,    14}  // x=4
    };

    parameter int PI_Y_MAP [0:4][0:4] = '{
        // y=0    y=1    y=2    y=3    y=4
        '{   0,     3,     1,     4,     2}, // x=0
        '{   1,     4,     2,     0,     3}, // x=1
        '{   2,     0,     3,     1,     4}, // x=2
        '{   3,     1,     4,     2,     0}, // x=3
        '{   4,     2,     0,     3,     1}  // x=4
    };

    localparam int X_PLUS_1 [0:4] = '{1, 2, 3, 4, 0}; // (x + 1) % 5
    localparam int X_PLUS_2 [0:4] = '{2, 3, 4, 0, 1}; // (x + 2) % 5

    // 8. 新增：Theta 多週期微狀態機 Enum (支援 Lane-Serial 多週期排程)
    typedef enum logic [1:0] {
        THETA_IDLE   = 2'b00,  // 等待 start 訊號
        THETA_CALC_C = 2'b01,  // Cycle 1~5: 計算並快取 5 個 Column 的 Parity (C)
        THETA_CALC_D = 2'b10,  // Cycle 6: 計算 D 
        THETA_UPDATE = 2'b11   // Cycle 7~11: 逐列更新 State 並在最後拉高 done
    } theta_state_e;

    // 9. 新增：Chi 狀態機 (搭配 cnt 進行精準 5 週期 Row-Serial 排程)
    typedef enum logic {
        CHI_IDLE = 1'b0,  // 等待 start 訊號
        CHI_CALC = 1'b1   // 進行 5 個周期的 Row 計算 (cnt = 0 ~ 4)
    } chi_state_e;
    
    // 10. 新增：微週期交握排程器 Enum (Round Scheduler)
    typedef enum logic [2:0] {
        SCHED_IDLE         = 3'b000,   // 等待頂層 FSM 的 start_process
        SCHED_THETA_START  = 3'b001,   // 啟動 Theta 並等待 theta_done
        SCHED_THETA_WAIT   = 3'b010,   // (0 Cycle) 
        SCHED_RHO_PI_START = 3'b011,   // 啟動 Rho & Pi 並等待 theta_done
        SCHED_RHO_PI_WAIT  = 3'b100,   // (0 Cycle)
        SCHED_CHI_START    = 3'b101,   // 啟動 Chi 並等待 chi_done
        SCHED_CHI_WAIT     = 3'b110,   // (0 Cycle)
        SCHED_DONE         = 3'b111    // 拉高 process_done，回到 SCHED_IDLE
    } round_sched_state_e;

    // 11. 擠出階段
    typedef enum logic [1:0] {
        SQZ_IDLE = 2'b00,
        SQZ_RUN  = 2'b01,
        SQZ_DONE = 2'b10
    } sqz_state_e;
endpackage : sha3_pkg