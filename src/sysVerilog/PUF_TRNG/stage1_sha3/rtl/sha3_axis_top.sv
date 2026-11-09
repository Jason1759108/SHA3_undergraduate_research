`timescale 1ns/1ps
// One message is a single AXI packet containing one or more 35-word blocks.
// Block header: bits [7:0] byte count, bit [8] final block, bits [31:9] zero.
// Each header is followed by exactly 34 data words, including zero-filled tail.
module sha3_axis_top (
    (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 axis_aclk CLK",
       X_INTERFACE_PARAMETER = "XIL_INTERFACENAME axis_aclk, ASSOCIATED_BUSIF S_AXIS:M_AXIS, ASSOCIATED_RESET axis_aresetn" *)
    input wire axis_aclk,
    (* X_INTERFACE_INFO = "xilinx.com:signal:reset:1.0 axis_aresetn RST",
       X_INTERFACE_PARAMETER = "XIL_INTERFACENAME axis_aresetn, POLARITY ACTIVE_LOW" *)
    input wire axis_aresetn,
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 S_AXIS TDATA" *)
    input wire [31:0] s_axis_tdata,
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 S_AXIS TKEEP" *)
    input wire [3:0] s_axis_tkeep,
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 S_AXIS TVALID" *)
    input wire s_axis_tvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 S_AXIS TREADY" *)
    output wire s_axis_tready,
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 S_AXIS TLAST" *)
    input wire s_axis_tlast,
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 M_AXIS TDATA" *)
    output wire [31:0] m_axis_tdata,
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 M_AXIS TKEEP" *)
    output wire [3:0] m_axis_tkeep,
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 M_AXIS TVALID" *)
    output wire m_axis_tvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 M_AXIS TREADY" *)
    input wire m_axis_tready,
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 M_AXIS TLAST" *)
    output wire m_axis_tlast
);
    typedef enum logic [2:0] {HEADER, PAYLOAD, SUBMIT, HASH_WAIT, REPLY, DRAIN} state_t;
    state_t state;
    logic [1087:0] block_data;
    logic [7:0] block_length;
    logic block_last;
    logic [5:0] input_index;
    logic [3:0] digest_count, output_index;
    logic [31:0] digest [0:7];
    logic [15:0] error_code;
    wire core_ready, core_valid, core_done;
    wire [31:0] core_data;
    wire core_rst_n = axis_aresetn && (error_code == 0);
    wire input_fire = s_axis_tvalid && s_axis_tready;
    wire header_bad = (s_axis_tdata[31:9] != 0) ||
                      (s_axis_tdata[7:0] > 136) ||
                      (!s_axis_tdata[8] && s_axis_tdata[7:0] != 136);

    assign s_axis_tready = axis_aresetn &&
                          ((state == HEADER) || (state == PAYLOAD) || (state == DRAIN));
    assign m_axis_tvalid = axis_aresetn && (state == REPLY);
    assign m_axis_tkeep = 4'hf;
    assign m_axis_tlast = m_axis_tvalid && (output_index == 8);
    assign m_axis_tdata = (output_index == 0) ? {16'h5348, error_code} :
                         (error_code != 0) ? 32'b0 : digest[output_index-1];

    sha3_ultra_low_power_top #(.FT_ENABLE(1'b1)) u_core (
        .clk(axis_aclk), .rst_n(core_rst_n),
        .in_valid(state == SUBMIT), .in_ready(core_ready),
        .msg_in(block_data), .msg_length(block_length), .in_last(block_last),
        .out_data(core_data), .out_valid(core_valid), .hash_done(core_done),
        .ft_inject_valid(1'b0), .ft_inject_lane(5'b0), .ft_inject_mask(64'b0),
        .ft_c_inject_valid(1'b0), .ft_c_inject_col(3'b0), .ft_c_inject_mask(64'b0),
        .ft_d_inject_valid(1'b0), .ft_d_inject_col(3'b0), .ft_d_inject_mask(64'b0)
    );

    always_ff @(posedge axis_aclk) begin
        if (!axis_aresetn) begin
            state <= HEADER;
            block_data <= '0;
            block_length <= 0;
            block_last <= 0;
            input_index <= 0;
            digest_count <= 0;
            output_index <= 0;
            error_code <= 0;
        end else begin
            // The core has no output-ready input. Capture all eight words first.
            if (core_valid && error_code == 0 && digest_count < 8) begin
                digest[digest_count] <= core_data;
                digest_count <= digest_count + 1'b1;
            end
            case (state)
                HEADER: if (input_fire) begin
                    block_length <= s_axis_tdata[7:0];
                    block_last <= s_axis_tdata[8];
                    input_index <= 0;
                    if (header_bad || s_axis_tkeep != 4'hf || s_axis_tlast) begin
                        error_code <= 1;
                        state <= s_axis_tlast ? REPLY : DRAIN;
                    end else state <= PAYLOAD;
                end
                PAYLOAD: if (input_fire) begin
                    block_data[input_index*32 +: 32] <= s_axis_tdata;
                    if (s_axis_tkeep != 4'hf ||
                        s_axis_tlast != (block_last && input_index == 33)) begin
                        error_code <= 2;
                        state <= s_axis_tlast ? REPLY : DRAIN;
                    end else if (input_index == 33) state <= SUBMIT;
                    else input_index <= input_index + 1'b1;
                end
                SUBMIT: if (core_ready) state <= block_last ? HASH_WAIT : HEADER;
                HASH_WAIT: if (core_done) begin
                    if (digest_count != 8) error_code <= 3;
                    state <= REPLY;
                end
                REPLY: if (m_axis_tready) begin
                    if (output_index == 8) begin
                        output_index <= 0;
                        digest_count <= 0;
                        error_code <= 0;
                        state <= HEADER;
                    end else output_index <= output_index + 1'b1;
                end
                DRAIN: if (input_fire && s_axis_tlast) state <= REPLY;
                default: state <= HEADER;
            endcase
        end
    end
endmodule
