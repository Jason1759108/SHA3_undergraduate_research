// Independent PUF256 AXI4-Lite interface; one controller and one outstanding AXI response.
module puf_axi #(
    parameter integer REPEATS=5, MIN_MARGIN=8, MEASURE_TIMEOUT=1100128
)(
    input wire s_axi_aclk, s_axi_aresetn,
    input wire [11:0] s_axi_awaddr,
    input wire [2:0] s_axi_awprot,
    input wire s_axi_awvalid,
    output wire s_axi_awready,
    input wire [31:0] s_axi_wdata,
    input wire [3:0] s_axi_wstrb,
    input wire s_axi_wvalid,
    output wire s_axi_wready,
    output logic [1:0] s_axi_bresp,
    output logic s_axi_bvalid,
    input wire s_axi_bready,
    input wire [11:0] s_axi_araddr,
    input wire [2:0] s_axi_arprot,
    input wire s_axi_arvalid,
    output wire s_axi_arready,
    output logic [31:0] s_axi_rdata,
    output logic [1:0] s_axi_rresp,
    output logic s_axi_rvalid,
    input wire s_axi_rready,
    input wire [639:0] ro_clocks,
    output wire [639:0] ro_enable
);
    import puf_types::*;
    logic aw_pending,w_pending;
    logic [11:0] write_addr;
    logic [31:0] write_data;
    logic [3:0] write_strobe;
    logic [31:0] command_cfg,window_cfg,warmup_cfg,raw_pair_cfg;
    logic [319:0] bitmap_cfg;
    logic [79:0] helper_cfg;
    logic helper_input_valid;
    logic dev_start,consume_pulse,abort_pulse,raw_start,raw_active,raw_done,rejected;
    logic [31:0] sequence_number,raw_sequence,result_command;
    logic [31:0] raw_a,raw_b,raw_pair,raw_window,raw_warmup;
    logic [3:0] raw_status;
    wire dev_ready,dev_busy,dev_done,dev_valid,key_valid,helper_valid;
    wire [255:0] key_data;
    wire [79:0] helper_out;
    wire [15:0] corrected_words;
    puf_error_t error;
    puf_status_t status_code,measure_status;
    wire measure_req,measure_ready,measure_valid;
    wire [8:0] pair_index;
    wire measure_busy,measure_done;
    wire [31:0] count_a,count_b,result_pair,result_window,result_warmup;
    wire [3:0] result_status;
    wire device_reset_n=s_axi_aresetn && !abort_pulse;
    wire locked=!dev_ready && !dev_busy && !dev_valid;
    wire active=!dev_ready || dev_start || raw_active || raw_start || measure_busy || measure_done || abort_pulse;
    wire command_ready=!active;
    puf_command_t command_value;
    assign command_value=(command_cfg<=1)?puf_command_t'(command_cfg[1:0]):puf_command_t'(2'd3);
    assign measure_ready=!raw_active && !raw_start && !measure_busy && !measure_done && !abort_pulse;
    assign measure_valid=measure_done && !raw_active;
    always_comb begin
        case(result_status)
            0:measure_status=PUF_OK;
            2:measure_status=PUF_BAD_WINDOW;
            3:measure_status=PUF_BAD_WARMUP;
            4:measure_status=PUF_RO_STOPPED;
            5:measure_status=PUF_RO_SATURATED;
            default:measure_status=PUF_BACKEND_FAULT;
        endcase
    end
    puf_device #(.REPEATS(REPEATS),.MIN_MARGIN(MIN_MARGIN),.MEASURE_TIMEOUT(MEASURE_TIMEOUT)) u_device(
        .clk(s_axi_aclk),.rst_n(device_reset_n),.start(dev_start),.command(command_value),
        .bitmap_in(bitmap_cfg),.helper_in(helper_cfg),.helper_in_valid(helper_input_valid),
        .ready(dev_ready),.busy(dev_busy),.done(dev_done),.result_valid(dev_valid),.result_ready(consume_pulse),
        .key_valid,.helper_valid,.key_data,.helper_out,.error,.status_code,.corrected_words,
        .measure_req,.measure_ready,.measure_valid,.measure_status,.pair_index,
        .count_a(count_a[15:0]),.count_b(count_b[15:0]));
    // Keep the proven RO320 per-oscillator counter/CDC architecture and hierarchy.
    (* KEEP_HIERARCHY="yes" *) ro_measure u_measure(
        .clk(s_axi_aclk),.reset_n(device_reset_n),
        .start(raw_start || (measure_req && measure_ready)),
        .pair_cfg(raw_active ? raw_pair_cfg : {23'd0,pair_index}),.window_cfg,.warmup_cfg,
        .ro_clocks,.ro_enable,.busy(measure_busy),.done(measure_done),.count_a,.count_b,
        .result_pair,.result_window,.result_warmup,.result_status);
    assign s_axi_awready=!aw_pending && !s_axi_bvalid;
    assign s_axi_wready=!w_pending && !s_axi_bvalid;
    assign s_axi_arready=!s_axi_rvalid;
    function automatic [31:0] merge_bytes(input logic [31:0] old_value,new_value,input logic [3:0] strobe);
        logic [31:0] merged;
        merged=old_value;
        for(integer i=0;i<4;i++)if(strobe[i])merged[8*i+:8]=new_value[8*i+:8];
        return merged;
    endfunction
    always_ff @(posedge s_axi_aclk or negedge s_axi_aresetn) begin
        if(!s_axi_aresetn)begin
            aw_pending<=0;w_pending<=0;write_addr<=0;write_data<=0;write_strobe<=0;
            s_axi_bvalid<=0;s_axi_bresp<=0;s_axi_rvalid<=0;s_axi_rdata<=0;s_axi_rresp<=0;
            command_cfg<=0;window_cfg<=100000;warmup_cfg<=1024;bitmap_cfg<=0;helper_cfg<=0;helper_input_valid<=0;
            dev_start<=0;consume_pulse<=0;abort_pulse<=0;raw_start<=0;raw_active<=0;raw_done<=0;rejected<=0;
            sequence_number<=0;raw_sequence<=0;result_command<=0;raw_pair_cfg<=0;
            raw_a<=0;raw_b<=0;raw_status<=0;raw_pair<=0;raw_window<=0;raw_warmup<=0;
        end else begin
            dev_start<=0;consume_pulse<=0;abort_pulse<=0;raw_start<=0;
            if(s_axi_bvalid && s_axi_bready)s_axi_bvalid<=0;
            if(s_axi_rvalid && s_axi_rready)s_axi_rvalid<=0;
            if(s_axi_awvalid && s_axi_awready)begin aw_pending<=1;write_addr<=s_axi_awaddr;end
            if(s_axi_wvalid && s_axi_wready)begin w_pending<=1;write_data<=s_axi_wdata;write_strobe<=s_axi_wstrb;end
            if(dev_done)sequence_number<=sequence_number+1;
            if(measure_done && raw_active)begin
                raw_active<=0;raw_done<=1;raw_sequence<=raw_sequence+1;
                raw_a<=count_a;raw_b<=count_b;raw_status<=result_status;
                raw_pair<=result_pair;raw_window<=result_window;raw_warmup<=result_warmup;
            end
            if(aw_pending && w_pending && !s_axi_bvalid)begin
                aw_pending<=0;w_pending<=0;s_axi_bvalid<=1;s_axi_bresp<=0;
                case(write_addr)
                    12'h008:if(write_strobe[0])begin
                        if(write_data[31:5]!=0 || ((write_data[3:0] & (write_data[3:0]-4'd1))!=0))s_axi_bresp<=2;
                        else begin
                            if(write_data[4])rejected<=0;
                            case(write_data[3:0])
                                4'h1:if(!command_ready)rejected<=1;
                                     else begin dev_start<=1;result_command<=command_cfg;raw_done<=0;end
                                4'h2:if(dev_valid)consume_pulse<=1;else rejected<=1;
                                4'h4:begin
                                    abort_pulse<=1;dev_start<=0;consume_pulse<=0;raw_start<=0;
                                    raw_active<=0;raw_done<=0;rejected<=0;
                                    raw_a<=0;raw_b<=0;raw_status<=0;
                                end
                                4'h8:if(!command_ready)rejected<=1;
                                     else begin raw_active<=1;raw_start<=1;raw_done<=0;end
                                default:begin end
                            endcase
                        end
                    end
                    12'h010:if(active && |write_strobe)s_axi_bresp<=2;else command_cfg<=merge_bytes(command_cfg,write_data,write_strobe);
                    12'h014:if(active && |write_strobe)s_axi_bresp<=2;else window_cfg<=merge_bytes(window_cfg,write_data,write_strobe);
                    12'h018:if(active && |write_strobe)s_axi_bresp<=2;else warmup_cfg<=merge_bytes(warmup_cfg,write_data,write_strobe);
                    12'h200:if(active && |write_strobe)s_axi_bresp<=2;else raw_pair_cfg<=merge_bytes(raw_pair_cfg,write_data,write_strobe);
                    12'h030:if(active && |write_strobe)s_axi_bresp<=2;else if(write_strobe[0])helper_input_valid<=write_data[0];
                    12'h100:if(active && |write_strobe)s_axi_bresp<=2;else bitmap_cfg[0+:32]<=merge_bytes(bitmap_cfg[0+:32],write_data,write_strobe);
                    12'h104:if(active && |write_strobe)s_axi_bresp<=2;else bitmap_cfg[32+:32]<=merge_bytes(bitmap_cfg[32+:32],write_data,write_strobe);
                    12'h108:if(active && |write_strobe)s_axi_bresp<=2;else bitmap_cfg[64+:32]<=merge_bytes(bitmap_cfg[64+:32],write_data,write_strobe);
                    12'h10c:if(active && |write_strobe)s_axi_bresp<=2;else bitmap_cfg[96+:32]<=merge_bytes(bitmap_cfg[96+:32],write_data,write_strobe);
                    12'h110:if(active && |write_strobe)s_axi_bresp<=2;else bitmap_cfg[128+:32]<=merge_bytes(bitmap_cfg[128+:32],write_data,write_strobe);
                    12'h114:if(active && |write_strobe)s_axi_bresp<=2;else bitmap_cfg[160+:32]<=merge_bytes(bitmap_cfg[160+:32],write_data,write_strobe);
                    12'h118:if(active && |write_strobe)s_axi_bresp<=2;else bitmap_cfg[192+:32]<=merge_bytes(bitmap_cfg[192+:32],write_data,write_strobe);
                    12'h11c:if(active && |write_strobe)s_axi_bresp<=2;else bitmap_cfg[224+:32]<=merge_bytes(bitmap_cfg[224+:32],write_data,write_strobe);
                    12'h120:if(active && |write_strobe)s_axi_bresp<=2;else bitmap_cfg[256+:32]<=merge_bytes(bitmap_cfg[256+:32],write_data,write_strobe);
                    12'h124:if(active && |write_strobe)s_axi_bresp<=2;else bitmap_cfg[288+:32]<=merge_bytes(bitmap_cfg[288+:32],write_data,write_strobe);
                    12'h140:if(active && |write_strobe)s_axi_bresp<=2;else helper_cfg[0+:32]<=merge_bytes(helper_cfg[0+:32],write_data,write_strobe);
                    12'h144:if(active && |write_strobe)s_axi_bresp<=2;else helper_cfg[32+:32]<=merge_bytes(helper_cfg[32+:32],write_data,write_strobe);
                    12'h148:if(active && |write_strobe)s_axi_bresp<=2;else helper_cfg[79:64]<=16'(merge_bytes({16'd0,helper_cfg[79:64]},write_data,write_strobe));
                    default:s_axi_bresp<=2;
                endcase
            end
            if(s_axi_arvalid && s_axi_arready)begin
                s_axi_rvalid<=1;s_axi_rresp<=0;
                case(s_axi_araddr)
                    12'h000:s_axi_rdata<=32'h50554631;
                    12'h004:s_axi_rdata<=32'h00010000;
                    12'h008:s_axi_rdata<=0;
                    12'h00c:s_axi_rdata<={23'd0,raw_done,raw_active,locked,rejected,helper_valid,key_valid,dev_valid,(dev_busy || dev_start || raw_active || raw_start || abort_pulse),command_ready};
                    12'h010:s_axi_rdata<=command_cfg;
                    12'h014:s_axi_rdata<=window_cfg;
                    12'h018:s_axi_rdata<=warmup_cfg;
                    12'h01c:s_axi_rdata<={23'd0,error,status_code};
                    12'h020:s_axi_rdata<={16'd0,corrected_words};
                    12'h024:s_axi_rdata<=sequence_number;
                    12'h028:s_axi_rdata<=result_command;
                    12'h02c:s_axi_rdata<={23'd0,pair_index};
                    12'h030:s_axi_rdata<={31'd0,helper_input_valid};
                    12'h034:s_axi_rdata<=100000000;
                    12'h038:s_axi_rdata<=320;
                    12'h03c:s_axi_rdata<=256;
                    12'h040:s_axi_rdata<=80;
                    12'h044:s_axi_rdata<=REPEATS;
                    12'h048:s_axi_rdata<=MIN_MARGIN;
                    12'h04c:s_axi_rdata<=MEASURE_TIMEOUT;
                    12'h100:s_axi_rdata<=bitmap_cfg[0+:32];
                    12'h104:s_axi_rdata<=bitmap_cfg[32+:32];
                    12'h108:s_axi_rdata<=bitmap_cfg[64+:32];
                    12'h10c:s_axi_rdata<=bitmap_cfg[96+:32];
                    12'h110:s_axi_rdata<=bitmap_cfg[128+:32];
                    12'h114:s_axi_rdata<=bitmap_cfg[160+:32];
                    12'h118:s_axi_rdata<=bitmap_cfg[192+:32];
                    12'h11c:s_axi_rdata<=bitmap_cfg[224+:32];
                    12'h120:s_axi_rdata<=bitmap_cfg[256+:32];
                    12'h124:s_axi_rdata<=bitmap_cfg[288+:32];
                    12'h140:s_axi_rdata<=helper_cfg[0+:32];
                    12'h144:s_axi_rdata<=helper_cfg[32+:32];
                    12'h148:s_axi_rdata<={16'd0,helper_cfg[79:64]};
                    12'h180:s_axi_rdata<=key_data[0+:32];
                    12'h184:s_axi_rdata<=key_data[32+:32];
                    12'h188:s_axi_rdata<=key_data[64+:32];
                    12'h18c:s_axi_rdata<=key_data[96+:32];
                    12'h190:s_axi_rdata<=key_data[128+:32];
                    12'h194:s_axi_rdata<=key_data[160+:32];
                    12'h198:s_axi_rdata<=key_data[192+:32];
                    12'h19c:s_axi_rdata<=key_data[224+:32];
                    12'h1c0:s_axi_rdata<=helper_out[0+:32];
                    12'h1c4:s_axi_rdata<=helper_out[32+:32];
                    12'h1c8:s_axi_rdata<={16'd0,helper_out[79:64]};
                    12'h200:s_axi_rdata<=raw_pair_cfg;
                    12'h204:s_axi_rdata<=raw_a;
                    12'h208:s_axi_rdata<=raw_b;
                    12'h20c:s_axi_rdata<={28'd0,raw_status};
                    12'h210:s_axi_rdata<=raw_sequence;
                    12'h214:s_axi_rdata<=raw_pair;
                    12'h218:s_axi_rdata<=raw_window;
                    12'h21c:s_axi_rdata<=raw_warmup;
                    default:begin s_axi_rdata<=0;s_axi_rresp<=2;end
                endcase
            end
        end
    end
    wire unused_prot=^{s_axi_awprot,s_axi_arprot};
endmodule
