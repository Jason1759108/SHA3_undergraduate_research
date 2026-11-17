`timescale 1ns/1ps
// Only artificial oscillator waveforms; all counts/ECC/control are real RTL.
module ro_wave_model #(parameter integer PAIRS=320)(
    input wire [2*PAIRS-1:0] enable,stop_mask,fast_mask,
    input wire [PAIRS-1:0] flip_mask,tie_mask,
    output logic [2*PAIRS-1:0] ro
);
    for(genvar i=0;i<2*PAIRS;i++)begin:g_wave
        localparam integer P=i/2;
        localparam bit POLARITY=((P*13+7)%11)<6;
        real half_period;
        initial begin
            ro[i]=0;
            forever begin
                wait(enable[i] && !stop_mask[i]);
                while(enable[i] && !stop_mask[i])begin
                    half_period=tie_mask[P]?2.0:(((POLARITY^flip_mask[P])==(i%2==0))?2.0:3.0);
                    #(fast_mask[i]?0.5:half_period+0.002*(P%16));
                    if(enable[i] && !stop_mask[i])ro[i]=!ro[i];else ro[i]=0;
                end
                ro[i]=0;
            end
        end
    end
endmodule
