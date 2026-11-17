`timescale 1ps/1ps
// Logical 640-RO bank, simulated with two active waveform processes.
// Disabled oscillators are zero. Pair selection occurs only with counters reset.
// No count values are generated here: only delay-based clock edges.
/* verilator tracing_off */
module ro_array_model #(parameter integer CANDIDATES=320,
    parameter logic[31:0] CHIP_SEED=32'h13579bdf)(
    input logic[2*CANDIDATES-1:0] enable,
    input logic[CANDIDATES-1:0] flip_mask,unstable_mask,
    input logic[2*CANDIDATES-1:0] stop_mask,
    output logic[2*CANDIDATES-1:0] ro
);
    logic active,fast_wave=0,slow_wave=0,direction;
    integer selected,fast_half,slow_half;
    logic[31:0] h;
    function automatic logic[31:0] mix(input logic[31:0] value);
        logic[31:0] x;
        begin x=value;x=(x^(x>>16))*32'h7feb352d;
            x=(x^(x>>15))*32'h846ca68b;return x^(x>>16);end
    endfunction
    // Sensitivity is to enable only; this scan is not repeated at every RO edge.
    always_comb begin
        active=0;selected=0;
        for(integer i=0;i<CANDIDATES;i++)if(enable[2*i]||enable[2*i+1])begin active=1;selected=i;end
        h=mix(CHIP_SEED^(32'(selected)*32'h9e3779b9));
        fast_half=1500+integer'((h>>1)%201);
        slow_half=2500+integer'((h>>9)%201);
    end
    initial forever begin
        wait(active);
        while(active)begin #(fast_half);if(active)fast_wave=~fast_wave;else fast_wave=0;end
        fast_wave=0;
    end
    initial forever begin
        wait(active);
        while(active)begin #(slow_half);if(active)slow_wave=~slow_wave;else slow_wave=0;end
        slow_wave=0;
    end
    always_comb begin
        ro='0;direction=h[0]^flip_mask[selected];
        if(active)begin
            if(enable[2*selected]&&!stop_mask[2*selected])
                ro[2*selected]=direction?fast_wave:slow_wave;
            if(enable[2*selected+1]&&!stop_mask[2*selected+1])
                ro[2*selected+1]=(selected%19==0||unstable_mask[selected]) ?
                    (direction?fast_wave:slow_wave) : (direction?slow_wave:fast_wave);
        end
    end
endmodule
/* verilator tracing_on */
