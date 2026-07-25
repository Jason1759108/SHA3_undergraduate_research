`timescale 1ns/1ps

module TESTBED;

    // 宣告連接 DUT 與 PATTERN 的線路
    logic        clk;
    logic        rst_n;
    logic        in_valid;
    logic [63:0] in_data;
    logic [63:0] in_state;
    logic        out_valid;
    logic [63:0] out_state;

    // 實體化待測模組 (Design Under Test)
    test u_test (
        .clk(clk),
        .rst_n(rst_n),
        .in_valid(in_valid),
        .in_data(in_data),
        .in_state(in_state),
        .out_valid(out_valid),
        .out_state(out_state)
    );

    // 實體化測試程式 (Pattern)
    PATTERN u_PATTERN (
        .clk(clk),
        .rst_n(rst_n),
        .in_valid(in_valid),
        .in_data(in_data),
        .in_state(in_state),
        .out_valid(out_valid),
        .out_state(out_state)
    );

    // 產生 FSDB 波形檔供 Verdi 觀看
    initial begin
        // $fsdbDumpfile("test.fsdb");
        // $fsdbDumpvars(0, TESTBED, "+mda"); // +mda 用於 dump multi-dimensional arrays (若 package 內有定義陣列的話)
    end

endmodule