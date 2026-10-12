import sha3_pkg::*;
module keccak_hamming64(
    input  logic [63:0] data_in,
    output logic [71:0] code_out,

    input  logic [71:0] code_in,
    output logic [63:0] data_out,
    output logic [6:0]  syndrome,
    output logic        ext_fail,
    output ft_status_e  status
);

    logic [FT_CODE_W-1:0] enc_word;
    always_comb begin: Encoder
        enc_word = '0;

        for (int d = 0; d < FT_DATA_W; d++) begin
            enc_word[FT_DATA_POS[d]-1] = data_in[d];
        end

        for (int p = 0; p < FT_HAM_P; p++) begin
            // FT_HAM_POS[p] = 1, 2, 4, 8, 16, 32, 64
            for (int j = 1; j <= FT_DATA_W + FT_HAM_P; j++) begin
                if (((j & FT_HAM_POS[p]) != 0) && (j != FT_HAM_POS[p])) begin
                    enc_word[FT_HAM_POS[p]-1] = enc_word[FT_HAM_POS[p]-1] ^ enc_word[j-1];
                end
            end
        end

        enc_word[FT_CODE_W-1] = ^enc_word[FT_CODE_W-2:0];
        code_out = enc_word;
    end

    logic [FT_CODE_W-1:0] corrected_code;
    always_comb begin: Decoder
        syndrome = '0;
            
        for (int p = 0; p < FT_HAM_P; p++) begin
            for (int j = 1; j <= FT_DATA_W + FT_HAM_P; j++) begin
                if ((j & FT_HAM_POS[p]) != 0) begin
                    syndrome[p] = syndrome[p] ^ code_in[j-1];
                end
            end
        end
        ext_fail = ^code_in;

        if (syndrome == '0 && ext_fail == 0) begin
            status = FT_ST_OK;
        end else if (syndrome <= 'd71 && ext_fail == 1) begin
            status = FT_ST_CORRECTED;  
        end else if (syndrome >= 'd1 && syndrome <= 'd71 &&  ext_fail == 0) begin
            status = FT_ST_UNCORR;
        end else begin
            status = FT_ST_UNCORR;
        end

        corrected_code = code_in;
        if (status == FT_ST_CORRECTED) begin
            if (syndrome == 0)
                corrected_code[FT_CODE_W-1] = ~code_in[FT_CODE_W-1];
            else
                corrected_code[syndrome-1] = ~code_in[syndrome-1];
        end

        data_out = '0;
        for (int d = 0; d < FT_DATA_W; d++) begin
            data_out[d] = corrected_code[FT_DATA_POS[d]-1];        
    end
    end
endmodule   