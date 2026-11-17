// Hardware only. LUT primitives and physical delay form the oscillator.
// Do not execute this feedback loop in zero-delay RTL simulation.
(* KEEP_HIERARCHY="yes", DONT_TOUCH="TRUE" *)
module ro_lut_cell(input wire enable, output wire ro);
    (* KEEP="TRUE", DONT_TOUCH="TRUE" *) wire [4:0] ring;
    // INIT[ {enable, feedback} ]: 0,0,1,0 -> enable & ~feedback.
    (* DONT_TOUCH="TRUE" *) LUT2 #(.INIT(4'h4)) u_gate(.I0(ring[4]),.I1(enable),.O(ring[0]));
    for(genvar k=1;k<5;k=k+1) begin : g_inv
        (* DONT_TOUCH="TRUE" *) LUT1 #(.INIT(2'h1)) u_inv(.I0(ring[k-1]),.O(ring[k]));
    end
    assign ro=ring[4];
endmodule
