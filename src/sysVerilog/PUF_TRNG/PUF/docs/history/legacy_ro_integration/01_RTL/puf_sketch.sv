// Extended Hamming syndrome secure sketch on arbitrary 16-bit PUF words.
// Positions 1..15 carry binary syndrome columns; position 16 has column zero.
// Five public syndrome bits per word. One error corrected, two detected.
// >=3 errors can miscorrect. This standalone design has no key confirmation.
module puf_sketch #(parameter integer RAW_BITS=256)(
    input logic [RAW_BITS-1:0] raw,
    input logic [RAW_BITS/16*5-1:0] helper,
    output logic [RAW_BITS/16*5-1:0] generated_helper,
    output logic [RAW_BITS-1:0] corrected,
    output logic uncorrectable,
    output logic [15:0] corrected_words
);
    function automatic logic [4:0] syndrome(input logic [15:0] word_data);
        logic [4:0] s;
        begin
            s='0;
            for (integer k=0;k<16;k++) begin
                if (word_data[k]) begin
                    s[4]=!s[4];
                    if(k<15) s[3:0]=s[3:0]^4'(k+1);
                end
            end
            return s;
        end
    endfunction
    logic [4:0] delta;
    always_comb begin
        generated_helper='0; corrected=raw; uncorrectable=0; corrected_words=0;
        delta='0;
        for(integer w=0;w<RAW_BITS/16;w++) begin
            generated_helper[w*5+:5]=syndrome(raw[w*16+:16]);
            delta=syndrome(raw[w*16+:16])^helper[w*5+:5];
            if(delta[4]) begin
                if(delta[3:0]==0) corrected[w*16+15]=!raw[w*16+15];
                else corrected[w*16+integer'(delta[3:0])-1]=!raw[w*16+integer'(delta[3:0])-1];
                corrected_words=corrected_words+1'b1;
            end else if(delta[3:0]!=0) uncorrectable=1;
        end
    end
endmodule
