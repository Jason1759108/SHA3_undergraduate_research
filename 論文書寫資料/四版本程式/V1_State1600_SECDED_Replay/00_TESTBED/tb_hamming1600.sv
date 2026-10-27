`timescale 1ns/1ps
import sha3_pkg::*;
module tb_hamming1600;
    logic [1599:0] data_in='0, data_out;
    logic [1611:0] encoded, received='0;
    logic [10:0] syndrome;
    logic ext_fail;
    ft_status_e status;
    int checks=0;
    keccak_hamming1600 dut(.data_in(data_in),.code_out(encoded),.code_in(received),
                         .data_out(data_out),.syndrome(syndrome),.ext_fail(ext_fail),.status(status));
    task automatic check_case(input int a,b);
        received=encoded;
        if(a>=0) received[a]=~received[a];
        if(b>=0) received[b]=~received[b];
        #1;
        if(b>=0) begin
            if(status!==FT_ST_UNCORR) $fatal(1,"[FAIL] 1600 double bits=%0d,%0d status=%0d",a,b,status);
        end else begin
            if(status!==((a<0)?FT_ST_OK:FT_ST_CORRECTED) || data_out!==data_in)
                $fatal(1,"[FAIL] 1600 single/no-error bit=%0d status=%0d",a,status);
        end
        checks++;
    endtask
    initial begin
        for(int pattern=0;pattern<3;pattern++) begin
            for(int b=0;b<1600;b++)
                data_in[b]=(pattern==0)?1'b0:((pattern==1)?1'b1:((b%7)<3));
            #1;
            check_case(-1,-1);
            for(int b=0;b<1612;b++) begin
                check_case(b,-1);
                check_case(b,(b+1)%1612);
                if(b<1611) check_case(b,1611);
            end
            $display("[PASS] hamming1600 pattern=%0d all single positions and representative double pairs",pattern);
        end
        $display("[SUCCESS] All %0d Hamming1600 checks passed!",checks);
        $finish;
    end
endmodule
