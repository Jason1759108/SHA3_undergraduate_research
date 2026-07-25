package sha3_pkg;

    // 1. 定義 Keccak 的基本維度
    localparam int LANE_W = 64;
    localparam int ROW_NUM = 5;
    localparam int COL_NUM = 5;
    
    // 2. 定義 3D Array 型別，完美對應 25 個 Lane
    // 未來所有模組的 I/O 只要寫 input state_t data_in，就不怕接錯
    typedef logic [LANE_W-1:0] state_t [COL_NUM-1:0][ROW_NUM-1:0];
    
    // 3. 定義一整個 Row (5個 Lane, 共 320 bits)，Chi Unit 會用到
    typedef logic [LANE_W-1:0] row_t [COL_NUM-1:0];

    // 4. 定義一整個 Column (5個 Lane, 共 320 bits)，Theta Unit 會用到
    typedef logic [LANE_W-1:0] col_t [ROW_NUM-1:0];

    // 5. 定義大腦的狀態機 Enum (FSM States)
    typedef enum logic [2:0] {
        ST_IDLE      = 3'b000,
        ST_ABSORB    = 3'b001,
        ST_PAD       = 3'b010,
        ST_RUN_ROUND = 3'b011,
        ST_SQUEEZE   = 3'b100,
        ST_DONE      = 3'b101
    } top_fsm_state_e;

    // 6. 定義 24 個 Round Constants
    parameter logic [63:0] RC [0:23] = '{
        64'h0000000000000001, 64'h0000000000008082, 64'h800000000000808A, 64'h8000000080008000,
        64'h000000000000808B, 64'h0000000080000001, 64'h8000000080008081, 64'h8000000000008009,
        64'h000000000000008A, 64'h0000000000000088, 64'h0000000080008009, 64'h000000008000000A,
        64'h000000008000808B, 64'h800000000000008B, 64'h8000000000008089, 64'h8000000000008003,
        64'h8000000000008002, 64'h8000000000000080, 64'h000000000000800A, 64'h800000008000000A,
        64'h8000000080008081, 64'h8000000000008080, 64'h0000000080000001, 64'h8000000080008008
    };

endpackage : sha3_pkg