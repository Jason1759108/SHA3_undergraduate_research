module sha3_low_power_gating (
    input  logic        clk,
    input  logic        rst_n,
    input  logic [24:0] sleep_en,
    output logic [24:0] gated_clk
);

    logic [24:0] gate_en_ff;

    always_ff @(negedge clk or negedge rst_n) begin
        if (!rst_n) begin
            gate_en_ff <= 25'd0;
        end
        else begin
            gate_en_ff <= ~sleep_en;
        end
    end

    assign gated_clk = {25{clk}} & gate_en_ff;

endmodule

