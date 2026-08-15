module sha3_low_power_gating (
    input  logic               clk,
    input  logic [24:0]        sleep_en,
    output logic [24:0]        gated_clk
);
    logic [24:0] gate_en_latched;

    // sleep_en is active-high. Capture its inverse only while clk is low so
    // gate_en_latched cannot change during the high phase of clk.
    always_latch begin
        if (!clk) begin
            gate_en_latched <= ~sleep_en;
        end
    end

    assign gated_clk = {25{clk}} & gate_en_latched;

endmodule
