`timescale 1ns/1ps
// Original research scaffold. Deterministic simulation model IS NOT entropy.
(* KEEP_HIERARCHY = "TRUE" *)
module ro_cell #(parameter integer STAGES=5)(input wire enable, output wire sample_async);
`ifdef SYNTHESIS
    // A NAND + an even number of inverters is an enabled odd-inversion ring.
    (* KEEP="TRUE", ALLOW_COMBINATORIAL_LOOPS="TRUE" *) wire [STAGES-1:0] ring;
    (* DONT_TOUCH="TRUE" *) LUT2 #(.INIT(4'h7)) u_gate(.I0(enable),.I1(ring[STAGES-1]),.O(ring[0]));
    for(genvar j=1;j<STAGES;j=j+1) begin:g_inv
        (* DONT_TOUCH="TRUE" *) LUT1 #(.INIT(2'b01)) u_inv(.I0(ring[j-1]),.O(ring[j]));
    end
    assign sample_async=ring[STAGES-1];
`else
    reg model=0;
    reg [31:0] seed;
    initial begin
        seed=32'h9e3779b9 ^ STAGES;
        forever begin
            #(STAGES+3+(seed & 7));
            seed={seed[30:0],seed[31]^seed[21]^seed[1]^seed[0]};
            if(enable) model=~model; else model=0;
        end
    end
    assign sample_async=model;
`endif
endmodule
