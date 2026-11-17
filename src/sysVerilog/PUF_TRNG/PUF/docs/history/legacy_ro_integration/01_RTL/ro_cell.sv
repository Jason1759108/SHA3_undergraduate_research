// Structural technology-neutral RO TEMPLATE. Never use in zero-delay RTL sim.
// Must be mapped/preserved/placed with the actual FPGA primitives or ASIC cells.
// Functional simulation uses ro_array_model, not this combinational loop.
(* keep_hierarchy="yes", dont_touch="true" *)
module ro_cell #(parameter integer STAGES=5)(input logic enable,output wire ro);
    (* keep="true", dont_touch="true" *) wire[STAGES-1:0] ring;
    assign ring[0]=enable ? ~ring[STAGES-1] : 1'b0;
    for(genvar k=1;k<STAGES;k++)begin : stage
        assign ring[k]=~ring[k-1];
    end
    assign ro=ring[STAGES-1];
    // synthesis translate_off
    initial if(STAGES<3||STAGES%2==0)$fatal(1,"Odd STAGES>=3 required");
    // synthesis translate_on
endmodule
