// A counter dedicated to one RO. No clock multiplexer is used.
module ro_edge_counter #(
    parameter integer COUNT_W = 24,
    parameter integer DIV_LOG2 = 3
)(
    input wire ro_clk,
    input wire reset_n,
    output logic [COUNT_W-1:0] gray
);
    // Active-high synchronized reset drives divider CLR directly. An active-low
    // release register would insert an inverter in the 500 MHz recovery path.
    (* ASYNC_REG="TRUE", SHREG_EXTRACT="NO" *) logic [1:0] raw_reset;
    (* KEEP="TRUE", CLOCK_BUFFER_TYPE="NONE" *) logic [DIV_LOG2-1:0] divider;
    (* CLOCK_BUFFER_TYPE="NONE" *) wire divided_clk = divider[DIV_LOG2-1];
    (* ASYNC_REG="TRUE", SHREG_EXTRACT="NO" *) logic [1:0] divided_release;
    logic [COUNT_W-1:0] binary;
    wire [COUNT_W-1:0] next_binary = binary + 1'b1;

    always_ff @(posedge ro_clk or negedge reset_n)
        if (!reset_n) raw_reset <= 2'b11;
        else raw_reset <= {raw_reset[0], 1'b0};

    always_ff @(posedge ro_clk or posedge raw_reset[1])
        if (raw_reset[1]) divider <= 0;
        else divider <= divider + 1'b1;

    always_ff @(posedge divided_clk or negedge reset_n)
        if (!reset_n) divided_release <= 0;
        else divided_release <= {divided_release[0], 1'b1};

    always_ff @(posedge divided_clk or negedge divided_release[1]) begin
        if (!divided_release[1]) begin
            binary <= 0;
            gray <= 0;
        end else if (!(&binary)) begin
            // Saturate instead of wrapping. The controller rejects a saturated
            // endpoint so an out-of-range frequency cannot alias to a low count.
            binary <= next_binary;
            gray <= next_binary ^ (next_binary >> 1);
        end
    end
endmodule
