package puf_types;
    typedef enum logic [1:0] {
        REGISTRATION  = 2'd0,
        CERTIFICATION = 2'd1
    } puf_command_t;
    typedef enum logic {
        PUF_NO_ERROR = 1'b0,
        PUF_ERROR    = 1'b1
    } puf_error_t;
    typedef enum logic [7:0] {
        PUF_OK                = 8'd0,
        PUF_BAD_COMMAND       = 8'd1,
        PUF_MEASURE_TIMEOUT   = 8'd2,
        PUF_WEAK_PAIR         = 8'd4,
        PUF_ECC_UNCORRECTABLE = 8'd5,
        PUF_MISSING_HELPER    = 8'd6,
        PUF_BAD_BITMAP        = 8'd7
    } puf_status_t;
    function automatic logic [255:0] puf_status_ascii(input puf_status_t s);
        case(s)
            PUF_OK:return "PUF_OK                          ";
            PUF_BAD_COMMAND:return "PUF_BAD_COMMAND                 ";
            PUF_MEASURE_TIMEOUT:return "PUF_MEASURE_TIMEOUT             ";
            PUF_WEAK_PAIR:return "PUF_WEAK_PAIR                   ";
            PUF_ECC_UNCORRECTABLE:return "PUF_ECC_UNCORRECTABLE           ";
            PUF_MISSING_HELPER:return "PUF_MISSING_HELPER              ";
            PUF_BAD_BITMAP:return "PUF_BAD_BITMAP                  ";
            default:return "PUF_STATUS_UNKNOWN              ";
        endcase
    endfunction
    function automatic logic [255:0] puf_error_ascii(input puf_error_t e);
        case(e)
            PUF_NO_ERROR:return "PUF_NO_ERROR                    ";
            PUF_ERROR:return "PUF_ERROR                       ";
            default:return "PUF_ERROR_UNKNOWN               ";
        endcase
    endfunction
    function automatic logic [255:0] puf_command_ascii(input puf_command_t c);
        case(c)
            REGISTRATION:return "REGISTRATION                    ";
            CERTIFICATION:return "CERTIFICATION                   ";
            default:return "INVALID_COMMAND                 ";
        endcase
    endfunction
endpackage
