// SECDED checker: clean, single-error correction and double-error detection cases.
`timescale 1ns/1ps
module PATTERN_PUF_ECC_SECDED(
    output logic[15:0] raw,
    output logic[4:0] helper,
    input logic[15:0] corrected,count,
    input logic[4:0] generated,
    input logic bad
);
    logic[15:0] reference_word;
    initial begin
        for(integer pattern=0;pattern<4;pattern++)begin
            case(pattern)0:reference_word=0;1:reference_word=16'hffff;2:reference_word=16'ha55a;default:reference_word=16'h5678;endcase
            raw=reference_word;helper=0;#1;helper=generated;#1;
            if(bad||count!=0||corrected!=reference_word)$fatal(1,"clean sketch failed");
            for(integer i=0;i<16;i++)begin
                raw=reference_word^(16'b1<<i);#1;
                if(bad||count!=1||corrected!=reference_word)$fatal(1,"single error at %0d",i);
                for(integer j=i+1;j<16;j++)begin
                    raw=reference_word^(16'b1<<i)^(16'b1<<j);#1;
                    if(!bad)$fatal(1,"double error not detected %0d,%0d",i,j);
                end
            end
        end
        $display("[SUCCESS] SECDED sketch: 4 clean, 64 single, 480 double error cases");$finish;
    end
endmodule
