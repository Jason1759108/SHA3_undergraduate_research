// Physical array TEMPLATE. No simulated per-chip identity is baked into RTL.
module ro_array #(parameter integer CANDIDATES=320,STAGES=5)(
    input logic[2*CANDIDATES-1:0] enable,
    output wire[2*CANDIDATES-1:0] ro
);
    for(genvar k=0;k<2*CANDIDATES;k++)begin : cell_array
        ro_cell #(.STAGES(STAGES)) oscillator(.enable(enable[k]),.ro(ro[k]));
    end
endmodule
