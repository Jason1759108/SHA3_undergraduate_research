`timescale 1ns/1ps
(* KEEP_HIERARCHY="TRUE" *)
module ro_bank(input wire enable, output wire [7:0] raw_async);
    for(genvar k=0;k<8;k=k+1) begin:g_ro
        (* DONT_TOUCH="TRUE" *) ro_cell #(.STAGES(5+2*k)) u_ro(.enable(enable),.sample_async(raw_async[k]));
    end
endmodule
