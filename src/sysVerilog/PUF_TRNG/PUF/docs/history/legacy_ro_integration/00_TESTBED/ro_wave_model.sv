`timescale 1ps/1ps
// SIMULATION ONLY oscillator; HALF_PERIOD_PS encodes artificial process delay.
module ro_wave_model #(parameter integer HALF_PERIOD_PS=2000)(
    input logic enable,output logic ro
);
    initial ro=0;
    always #(HALF_PERIOD_PS) if(enable)ro=~ro;else ro=0;
endmodule
