// Counts are divided-clock ticks, NOT individual RO edges. Multiply by DIVISOR.
module ro_measure #(
    parameter integer PAIRS=320, COUNT_W=16, DIV_LOG2=3
)(
    input wire clk, reset_n, start,
    input wire [31:0] pair_cfg, window_cfg, warmup_cfg,
    input wire [2*PAIRS-1:0] ro_clocks,
    output logic [2*PAIRS-1:0] ro_enable,
    output wire busy,
    output logic done,
    output logic [31:0] count_a, count_b,
    output logic [31:0] result_pair, result_window, result_warmup,
    output logic [3:0] result_status
);
    typedef enum logic [1:0] {IDLE, WARMUP, MEASURE} state_t;
    typedef enum logic [3:0] {
        OK=0, BAD_PAIR=1, BAD_WINDOW=2, BAD_WARMUP=3, ZERO_COUNT=4, COUNT_SATURATED=5
    } status_t;
    state_t state;
    status_t status;
    localparam integer INDEX_W=$clog2(2*PAIRS);
    logic [INDEX_W-1:0] index_a;
    logic [31:0] elapsed;
    logic [COUNT_W-1:0] baseline_a, baseline_b;
    logic [COUNT_W-1:0] selected_a, selected_b;
    // Registered RO-domain reset source avoids combinational logic before CDC
    // reset synchronizers. It releases one system cycle after RO enable.
    logic [2*PAIRS-1:0] counter_reset_n;
    always_ff @(posedge clk or negedge reset_n)
        if (!reset_n) counter_reset_n<=0;
        else counter_reset_n<=ro_enable;
    wire [COUNT_W-1:0] source_gray [0:2*PAIRS-1];
    (* ASYNC_REG="TRUE", SHREG_EXTRACT="NO" *) logic [COUNT_W-1:0] gray_meta [0:2*PAIRS-1];
    (* ASYNC_REG="TRUE", SHREG_EXTRACT="NO" *) logic [COUNT_W-1:0] gray_sync [0:2*PAIRS-1];

    function automatic [COUNT_W-1:0] gray_to_binary(input logic [COUNT_W-1:0] g);
        logic [COUNT_W-1:0] b;
        b[COUNT_W-1]=g[COUNT_W-1];
        for (integer j=COUNT_W-2; j>=0; j=j-1) b[j]=b[j+1]^g[j];
        return b;
    endfunction

    for (genvar i=0; i<2*PAIRS; i=i+1) begin : g_counter
        (* KEEP_HIERARCHY="yes" *) ro_edge_counter #(.COUNT_W(COUNT_W),.DIV_LOG2(DIV_LOG2)) u_counter(
            .ro_clk(ro_clocks[i]), .reset_n(counter_reset_n[i]), .gray(source_gray[i]));
        always_ff @(posedge clk or negedge reset_n)
            if (!reset_n) begin
                gray_meta[i] <= 0;
                gray_sync[i] <= 0;
            end else begin
                gray_meta[i] <= source_gray[i];
                gray_sync[i] <= gray_meta[i];
            end
    end

    // Select data only; every RO keeps its own counter and clock domain.
    // Ten banks of 32 pairs bound the mux depth before Gray decoding. Each
    // endpoint sees the same three system-clock pipeline stages, preserving
    // the exact window spacing. The minimum warmup settles all stages.
    localparam integer BANK_PAIRS=32, BANK_ROS=2*BANK_PAIRS;
    localparam integer BANKS=PAIRS/BANK_PAIRS;
    localparam integer BANK_INDEX_W=(BANKS>1)?$clog2(BANKS):1;
    logic [COUNT_W-1:0] bank_a [0:BANKS-1], bank_b [0:BANKS-1];
    logic [COUNT_W-1:0] selected_gray_a, selected_gray_b;
    wire [BANK_INDEX_W-1:0] bank_index=BANK_INDEX_W'(index_a >> 6);
    for (genvar bank=0; bank<BANKS; bank=bank+1) begin : g_read_bank
        wire [COUNT_W-1:0] sources [0:BANK_ROS-1];
        for (genvar slot=0; slot<BANK_ROS; slot=slot+1) begin : g_source
            assign sources[slot]=gray_sync[bank*BANK_ROS+slot];
        end
        always_ff @(posedge clk or negedge reset_n)
            if (!reset_n) begin bank_a[bank]<=0; bank_b[bank]<=0; end
            else begin
                bank_a[bank]<=sources[index_a[5:0]];
                bank_b[bank]<=sources[index_a[5:0]+6'd1];
            end
    end
    always_ff @(posedge clk or negedge reset_n)
        if (!reset_n) begin
            selected_gray_a<=0; selected_gray_b<=0;
            selected_a<=0; selected_b<=0;
        end
        else begin
            selected_gray_a<=bank_a[bank_index];
            selected_gray_b<=bank_b[bank_index];
            selected_a<=gray_to_binary(selected_gray_a);
            selected_b<=gray_to_binary(selected_gray_b);
        end
    wire [COUNT_W-1:0] delta_a=selected_a-baseline_a;
    wire [COUNT_W-1:0] delta_b=selected_b-baseline_b;
    assign busy=(state!=IDLE);
    assign result_status=status;

    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            state<=IDLE; status<=OK; done<=0; ro_enable<=0; elapsed<=0; index_a<=0;
            count_a<=0; count_b<=0; baseline_a<=0; baseline_b<=0;
            result_pair<=0; result_window<=0; result_warmup<=0;
        end else begin
            done<=0;
            case (state)
                IDLE: if (start) begin
                    result_pair<=pair_cfg; result_window<=window_cfg; result_warmup<=warmup_cfg;
                    count_a<=0; count_b<=0; status<=OK; elapsed<=0;
                    if (pair_cfg>=PAIRS) begin status<=BAD_PAIR; done<=1; end
                    else if (window_cfg<16 || window_cfg>100000) begin status<=BAD_WINDOW; done<=1; end
                    else if (warmup_cfg<64 || warmup_cfg>1000000) begin status<=BAD_WARMUP; done<=1; end
                    else begin
                        index_a<=INDEX_W'(pair_cfg*2);
                        ro_enable<={{(2*PAIRS-2){1'b0}},2'b11} << (pair_cfg*2);
                        state<=WARMUP;
                    end
                end
                WARMUP: if (elapsed==result_warmup-1) begin
                    baseline_a<=selected_a;
                    baseline_b<=selected_b;
                    elapsed<=0; state<=MEASURE;
                end else elapsed<=elapsed+1;
                MEASURE: if (elapsed==result_window-1) begin
                    count_a<={{(32-COUNT_W){1'b0}},delta_a};
                    count_b<={{(32-COUNT_W){1'b0}},delta_b};
                    if ((&selected_a) || (&selected_b) || (&baseline_a) || (&baseline_b)) status<=COUNT_SATURATED;
                    else if (delta_a==0 || delta_b==0) status<=ZERO_COUNT;
                    ro_enable<=0; done<=1; state<=IDLE;
                end else elapsed<=elapsed+1;
                default: begin state<=IDLE; ro_enable<=0; end
            endcase
        end
    end
endmodule
