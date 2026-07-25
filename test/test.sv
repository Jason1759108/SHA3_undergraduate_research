`timescale 1ns/1ps
import sha3_pkg::*; // 引入你的 SHA3 封裝檔

module test (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        in_valid,
    input  logic [63:0] in_data,
    input  logic [63:0] in_state,
    output logic        out_valid,
    output logic [63:0] out_state
);

    // 時序邏輯：Keccak 吸收階段的 XOR 運算
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            out_valid <= 1'b0;
            out_state <= 64'b0;
        end else if (in_valid) begin
            out_valid <= 1'b1;
            // SHA-3 核心運算：State = State XOR Data
            out_state <= in_state ^ in_data; 
        end else begin
            out_valid <= 1'b0;
            out_state <= out_state;
        end
    end

endmodule