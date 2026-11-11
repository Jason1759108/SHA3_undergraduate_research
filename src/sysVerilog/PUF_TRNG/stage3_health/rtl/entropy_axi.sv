`timescale 1ns/1ps
// Register bus always responds independently of RO activity. No DDR bus master.
module entropy_axi #(
    parameter integer DEPTH=1024,
    parameter integer WARMUP=1024,
    parameter integer STARTUP_SAMPLES=1024,
    parameter integer RCT_C=41,
    parameter integer APT_WINDOW=1024,
    parameter integer APT_C=793,
    parameter integer WATCHDOG=20000000
)(
    (* X_INTERFACE_INFO="xilinx.com:signal:clock:1.0 s_axi_aclk CLK",
       X_INTERFACE_PARAMETER="XIL_INTERFACENAME s_axi_aclk, ASSOCIATED_BUSIF s_axi, ASSOCIATED_RESET s_axi_aresetn" *)
    input wire s_axi_aclk,
    (* X_INTERFACE_INFO="xilinx.com:signal:reset:1.0 s_axi_aresetn RST",
       X_INTERFACE_PARAMETER="XIL_INTERFACENAME s_axi_aresetn, POLARITY ACTIVE_LOW" *)
    input wire s_axi_aresetn,
    input wire [15:0] s_axi_awaddr,
    input wire [2:0] s_axi_awprot,
    input wire s_axi_awvalid, output wire s_axi_awready,
    input wire [31:0] s_axi_wdata, input wire [3:0] s_axi_wstrb,
    input wire s_axi_wvalid, output wire s_axi_wready,
    output reg [1:0] s_axi_bresp, output reg s_axi_bvalid, input wire s_axi_bready,
    input wire [15:0] s_axi_araddr, input wire [2:0] s_axi_arprot,
    input wire s_axi_arvalid, output wire s_axi_arready,
    output reg [31:0] s_axi_rdata, output reg [1:0] s_axi_rresp,
    output reg s_axi_rvalid, input wire s_axi_rready
);
    reg aw_pending,w_pending;
    reg [15:0] awaddr;
    reg [31:0] wdata;
    reg [3:0] wstrb;
    reg [15:0] divider;
    reg busy,done,alarm,aborted,watchdog_fault;
    reg [31:0] count,warm_count,ticks,elapsed;
    reg startup_ok;
    reg [31:0] startup_seen,observed;
    wire commit_write=aw_pending && w_pending && !s_axi_bvalid;
    wire command_byte=commit_write && awaddr==0 && wstrb[0];
    wire start_allowed=!busy && !alarm && !aborted && !watchdog_fault;
    wire start_cmd=command_byte && wdata[7:0]==1 && start_allowed;
    wire abort_cmd=command_byte && wdata[7:0]==2;
    wire clear_cmd=command_byte && wdata[7:0]==4 && !busy;
    (* ASYNC_REG="TRUE" *) reg [7:0] sync_meta,sync_data;
    wire [7:0] fault_mask;
    wire [7:0] rct_mask,apt_mask,rct_fail_now,apt_fail_now;
    wire [7:0] fail_now=rct_fail_now|apt_fail_now;
    wire batch_valid=done && !busy && !alarm && !aborted && !watchdog_fault && startup_ok && count==DEPTH;
    wire sample_tick=busy && !abort_cmd && elapsed<WATCHDOG-1 && warm_count>=WARMUP && ticks==divider-1;
    assign fault_mask=rct_mask|apt_mask;
    entropy_health_monitor #(.CHANNELS(8),.RCT_C(RCT_C),.APT_WINDOW(APT_WINDOW),.APT_C(APT_C)) u_health(
        .clk(s_axi_aclk),.resetn(s_axi_aresetn),.clear(start_cmd|clear_cmd),
        .sample_valid(sample_tick),.sample_data(sync_data),
        .rct_fail_now(rct_fail_now),.apt_fail_now(apt_fail_now),
        .rct_fault(rct_mask),.apt_fault(apt_mask));
    (* ram_style="distributed" *) reg [31:0] samples [0:DEPTH-1];
    wire [7:0] raw_async;
    wire ro_enable=busy && s_axi_aresetn;
    ro_bank u_bank(.enable(ro_enable),.raw_async(raw_async));
    always @(posedge s_axi_aclk) begin
        if(!s_axi_aresetn) begin sync_meta<=0;sync_data<=0;end
        else begin sync_meta<=raw_async;sync_data<=sync_meta;end
    end
    assign s_axi_awready=s_axi_aresetn && !aw_pending && !s_axi_bvalid;
    assign s_axi_wready=s_axi_aresetn && !w_pending && !s_axi_bvalid;
    assign s_axi_arready=s_axi_aresetn && !s_axi_rvalid;

    // Independent AW and W buffering: address/data may arrive in either order.
    always @(posedge s_axi_aclk) begin
        if(!s_axi_aresetn) begin
            aw_pending<=0;w_pending<=0;s_axi_bvalid<=0;s_axi_bresp<=0;
            divider<=512;
            awaddr<=0;wdata<=0;wstrb<=0;
        end else begin
            if(s_axi_bvalid && s_axi_bready) s_axi_bvalid<=0;
            if(s_axi_awvalid && s_axi_awready) begin aw_pending<=1;awaddr<=s_axi_awaddr;end
            if(s_axi_wvalid && s_axi_wready) begin w_pending<=1;wdata<=s_axi_wdata;wstrb<=s_axi_wstrb;end
            if(aw_pending && w_pending && !s_axi_bvalid) begin
                aw_pending<=0;w_pending<=0;s_axi_bvalid<=1;s_axi_bresp<=0;
                if(awaddr==16'h0000) begin
                    if(wstrb[0]) begin
                        if(wdata[7:0]!=0 && !start_cmd && !abort_cmd && !clear_cmd) s_axi_bresp<=2;
                    end
                end else if(awaddr==16'h0010 && !busy) begin
                    // Divider is a complete 16-bit setting; partial writes reject.
                    if(wstrb[1:0]==2'b11 && wdata[31:16]==0 && wdata[15:0]>=16 && wdata[15:0]<=4096)
                        divider<=wdata[15:0];
                    else s_axi_bresp<=2;
                end else s_axi_bresp<=2;
            end
        end
    end

    // Registered control read from local LUTRAM; unfilled/busy samples are rejected.
    always @(posedge s_axi_aclk) begin
        if(!s_axi_aresetn) begin s_axi_rvalid<=0;s_axi_rdata<=0;s_axi_rresp<=0;end
        else begin
            if(s_axi_rvalid && s_axi_rready) s_axi_rvalid<=0;
            if(s_axi_arvalid && s_axi_arready) begin
                s_axi_rvalid<=1;s_axi_rresp<=0;s_axi_rdata<=0;
                if(s_axi_araddr[1:0]!=0) s_axi_rresp<=2;
                else if(s_axi_araddr>=16'h1000 && s_axi_araddr<16'h1000+DEPTH*4) begin
                    if(batch_valid && ((s_axi_araddr-16'h1000)>>2)<count)
                        s_axi_rdata<=samples[(s_axi_araddr-16'h1000)>>2];
                    else s_axi_rresp<=2;
                end else case(s_axi_araddr)
                    16'h0000:s_axi_rdata<=0;
                    16'h0004:s_axi_rdata<={24'b0,batch_valid,startup_ok,(busy && !startup_ok),watchdog_fault,aborted,alarm,done,busy};
                    16'h0008:s_axi_rdata<=count;
                    16'h000c:s_axi_rdata<=DEPTH;
                    16'h0010:s_axi_rdata<={16'b0,divider};
                    16'h0014:s_axi_rdata<=32'h524f4832;
                    16'h0018:s_axi_rdata<=32'h00020000;
                    16'h001c:s_axi_rdata<=32'h00000508;
                    16'h0020:s_axi_rdata<={31'b0,ro_enable};
                    16'h0024:s_axi_rdata<=WARMUP;
                    16'h0028:s_axi_rdata<=RCT_C;
                    16'h002c:s_axi_rdata<=WATCHDOG;
                    16'h0030:s_axi_rdata<={24'b0,fault_mask};
                    16'h0034:s_axi_rdata<={24'b0,rct_mask};
                    16'h0038:s_axi_rdata<={24'b0,apt_mask};
                    16'h003c:s_axi_rdata<=STARTUP_SAMPLES;
                    16'h0040:s_axi_rdata<=observed;
                    16'h0044:s_axi_rdata<=APT_WINDOW;
                    16'h0048:s_axi_rdata<=APT_C;
                    16'h004c:s_axi_rdata<=startup_seen;
                    default:s_axi_rresp<=2;
                endcase
            end
        end
    end

    // No sample is readable until startup AND the whole payload batch pass.
    // Monitors continue without resetting across startup/payload boundary.
    always @(posedge s_axi_aclk) begin
        if(!s_axi_aresetn) begin
            busy<=0;done<=0;alarm<=0;aborted<=0;watchdog_fault<=0;
            count<=0;warm_count<=0;ticks<=0;elapsed<=0;
            startup_ok<=0;startup_seen<=0;observed<=0;
        end else if(start_cmd) begin
            busy<=1;done<=0;alarm<=0;aborted<=0;watchdog_fault<=0;
            count<=0;warm_count<=0;ticks<=0;elapsed<=0;
            startup_ok<=0;startup_seen<=0;observed<=0;
        end else if(abort_cmd && busy) begin busy<=0;done<=1;aborted<=1;end
        else if(clear_cmd) begin
            done<=0;alarm<=0;aborted<=0;watchdog_fault<=0;count<=0;
            startup_ok<=0;startup_seen<=0;observed<=0;
        end else if(busy) begin
            elapsed<=elapsed+1;
            if(elapsed>=WATCHDOG-1) begin busy<=0;done<=1;alarm<=1;watchdog_fault<=1;end
            else if(warm_count<WARMUP) warm_count<=warm_count+1;
            else if(sample_tick) begin
                ticks<=0;observed<=observed+1;
                // Current-sample failure has priority even at the last startup/payload sample.
                if(|fail_now) begin busy<=0;done<=1;alarm<=1;end
                else if(!startup_ok) begin
                    startup_seen<=startup_seen+1;
                    if(startup_seen==STARTUP_SAMPLES-1) startup_ok<=1;
                end else begin
                    samples[count]<={24'b0,sync_data};count<=count+1;
                    if(count==DEPTH-1) begin busy<=0;done<=1;end
                end
            end else ticks<=ticks+1;
        end
    end
endmodule
