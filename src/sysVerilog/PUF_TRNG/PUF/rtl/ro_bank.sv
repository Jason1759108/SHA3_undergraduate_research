(* KEEP_HIERARCHY="yes" *)
module ro_bank #(parameter integer PAIRS=320)(
    input wire [2*PAIRS-1:0] enable,
    output wire [2*PAIRS-1:0] ro
);
    for(genvar i=0;i<2*PAIRS;i=i+1) begin : g_ro
        ro_lut_cell u_ro(.enable(enable[i]),.ro(ro[i]));
    end
endmodule
