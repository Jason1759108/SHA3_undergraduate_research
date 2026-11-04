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
        ST_RUN_ROUND = 3'b010,
        ST_WAIT_BLOCK= 3'b011,
        ST_SQUEEZE   = 3'b100,
        ST_DONE      = 3'b101
    } top_fsm_state_e;

    // 6. 定義 24 個 Round Constants (FIPS 202 標準規範，Iota 步驟使用)
    parameter logic [63:0] RC [0:23] = '{
        64'h0000000000000001, 64'h0000000000008082, 64'h800000000000808A, 64'h8000000080008000,
        64'h000000000000808B, 64'h0000000080000001, 64'h8000000080008081, 64'h8000000000008009,
        64'h000000000000008A, 64'h0000000000000088, 64'h0000000080008009, 64'h000000008000000A,
        64'h000000008000808B, 64'h800000000000008B, 64'h8000000000008089, 64'h8000000000008003,
        64'h8000000000008002, 64'h8000000000000080, 64'h000000000000800A, 64'h800000008000000A,
        64'h8000000080008081, 64'h8000000000008080, 64'h0000000080000001, 64'h8000000080008008
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

    // 8. 擠出階段
    typedef enum logic [1:0] {
        SQZ_IDLE = 2'b00,
        SQZ_RUN  = 2'b01,
        SQZ_DONE = 2'b10
    } sqz_state_e;

    // 9. Lane Hamming SECDED 合約（(72,64)；位置 1-indexed，與課堂 (7,4) 同一套）
    //
    // code[k] ↔ 位置 (k+1)，因此：
    //   code[71] = 位置 72 = P_ext（全體 even parity，XOR 位置 1..71）
    //   code[70:0] = 位置 71 .. 位置 1
    // 位置 1,2,4,8,16,32,64 = Hamming 校驗 P1..P64
    // 其餘 64 個位置（3,5,6,...,71）依編號由小到大塞 data[0]..data[63]
    // Hamming / TB 必須用下面的 FT_DATA_POS / function，禁止各寫一份對照表。
    localparam int FT_DATA_W = 64;
    localparam int FT_HAM_P  = 7;
    localparam int FT_EXT_P  = 1;
    localparam int FT_CODE_W = FT_DATA_W + FT_HAM_P + FT_EXT_P; // 72
    localparam int FT_EXT_POS = 72;

    parameter int FT_HAM_POS [0:6] = '{1, 2, 4, 8, 16, 32, 64};

    parameter int FT_DATA_POS [0:63] = '{
        3,  5,  6,  7,  9, 10, 11, 12, 13, 14, 15, 17, 18, 19, 20, 21,
        22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 33, 34, 35, 36, 37, 38,
        39, 40, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, 52, 53, 54,
        55, 56, 57, 58, 59, 60, 61, 62, 63, 65, 66, 67, 68, 69, 70, 71
    };

    typedef enum logic [1:0] {
        FT_ST_OK        = 2'd0,
        FT_ST_CORRECTED = 2'd1,
        FT_ST_UNCORR    = 2'd2
    } ft_status_e;

    typedef enum logic [2:0] {
        FT_SRC_NONE,
        FT_SRC_THETA,
        FT_SRC_CHI
    } ft_src_e;

    typedef enum logic [2:0] {
        FT_REPLAY_NONE,
        FT_REPLAY_THETA_COL,
        FT_REPLAY_THETA_CD,
        FT_REPLAY_THETA_FROM0,
        FT_REPLAY_CHI_ROW
    } ft_replay_e;

    function automatic int ft_data_pos(input int d);
        return FT_DATA_POS[d];
    endfunction

    function automatic logic ft_pos_is_ham_p(input int p);
        return (p == 1) || (p == 2) || (p == 4) || (p == 8) ||
               (p == 16) || (p == 32) || (p == 64);
    endfunction

    // 1-indexed 位置 pos∈[1,72] 對應 code[pos-1]
    function automatic logic ft_code_bit(input logic [FT_CODE_W-1:0] code, input int pos);
        return code[pos-1];
    endfunction
endpackage : sha3_pkg
