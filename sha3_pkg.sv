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

    // 9. 新增：Chi 多週期微狀態機 Enum (支援 Row-Serial 排程)
    typedef enum logic [1:0] {
        CHI_IDLE = 2'b00,      // 等待 start 訊號
        CHI_ROW_0_1 = 2'b01,   // 處理 Row 0 與 Row 1
        CHI_ROW_2_3 = 2'b10,   // 處理 Row 2 與 Row 3
        CHI_ROW_4   = 2'b11    // 處理 Row 4 並拉高 done
    } chi_state_e;
    
    // 10. 新增：微週期交握排程器 Enum (Round Scheduler)
    typedef enum logic [1:0] {
        SCHED_IDLE  = 2'b00,   // 等待頂層 FSM 的 start_process
        SCHED_THETA = 2'b01,   // 啟動 Theta 並等待 theta_done
        SCHED_RHO_PI = 2'b10,  // (0 Cycle) 純連線過渡狀態
        SCHED_CHI   = 2'b11    // 啟動 Chi 並等待 chi_done
    } round_sched_state_e;

    // 11. 新增：Output Formatter (Squeeze) 多週期微狀態機 Enum
    // 對應 sha3_output_formatter.sv，負責把 25 個 Lane 中屬於 rate 區段
    // 的部分，依 Keccak lane 線性化順序 (z = x + 5y) 逐 word 輸出。
    typedef enum logic [1:0] {
        SQZ_IDLE = 2'b00,  // 等待 ctrl_fsm 的 start (squeeze_en)
        SQZ_LO   = 2'b01,  // 輸出目前 Lane 的低 32 bits
        SQZ_HI   = 2'b10,  // 輸出目前 Lane 的高 32 bits，Lane index + 1
        SQZ_DONE = 2'b11   // OUT_LANE_NUM 個 Lane 輸出完畢，拉高 done
    } squeeze_state_e;

    // 12. 新增：SHA3-256 Squeeze 輸出相關參數
    // 目前僅支援 SHA3-256 固定長度輸出（§13 建議規格：SHA3-256 first）。
    // 未來若要擴充 SHAKE，OUT_BITS 需改為可變長度並新增對應暫存器。
    localparam int OUT_BITS     = 256;                // SHA3-256 輸出長度
    localparam int OUT_LANE_NUM = OUT_BITS / LANE_W;  // 需輸出的 Lane 數 = 4
    localparam int OUT_WORD_W   = 32;                 // 輸出介面寬度 (32-bit)，對齊 8/32-bit streaming interface

    // 13. 新增：效能計數器 (sha3_perf_counter.sv) 相關參數
    // 純觀測用途，不可回寫 state 或影響 FSM 判斷；用來量化極低瞬間功耗的證據
    // （對應 cycles_per_block / active_lane_banks_per_round 等量測指標）。
    localparam int PERF_CNT_W = 32;  // cycle_count、lane_toggle_count 計數器寬度
    localparam int PERM_CNT_W = 16;  // perm_count（完整 24-round permutation 次數）計數器寬度

endpackage : sha3_pkg