import sys,random,json,math
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'python'))
from health_model import Monitor
out=ROOT/'build/monitor';out.mkdir(parents=True,exist_ok=True)
for name,rct,window,apt in [('small',5,8,7),('default',41,1024,793)]:
    m=Monitor(rct,window,apt);events=[]
    def step(v=0,valid=True,clear=False):
        rf,af=m.step(v,valid,clear);packed=int(valid)|(int(clear)<<1)|(v<<8)|(rf<<16)|(af<<24)|(m.rct_mask<<32)|(m.apt_mask<<40);events.append(packed)
    def reset():step(clear=True)
    reset()
    for i in range(window*2):step(0x55 if i%2 else 0xaa)
    for channel in range(8):
        reset()
        for i in range(rct+2):step((0x55 if i%2 else 0xaa)&~(1<<channel))
        for i in range(5):step(0,valid=False)
    reset()
    for i in range(window+2):step(0xff if i%5==4 else 0)
    reset()
    # The first APT reference expires exactly at W; a run spanning W must not reset.
    for i in range(window-2):step(0x55 if i%2 else 0xaa)
    for i in range(rct):step(0)
    rng=random.Random(4271)
    reset()
    for i in range(3000):
        if i%117==0:reset()
        step(rng.randrange(256),valid=(i%7!=0))
    lines=['{:012x}'.format(v) for v in events]
    (out/(name+'.mem')).write_text('\n'.join(lines)+'\n')
    tb="""`timescale 1ns/1ps
module tb_monitor_NAME;
reg clk=0;always #5 clk=~clk;
reg resetn=0,clear=0,sample_valid=0;reg[7:0]sample_data=0;
wire[7:0]rct_fail_now,apt_fail_now,rct_fault,apt_fault;
entropy_health_monitor #(.RCT_C(RCT),.APT_WINDOW(WINDOW),.APT_C(APT)) dut(.*);
reg[47:0]vectors[0:LAST];reg[47:0]v;
initial begin
 $readmemh("NAME.mem",vectors);repeat(3)@(negedge clk);resetn=1;
 for(integer i=0;i<=LAST;i++)begin
  @(negedge clk);v=vectors[i];sample_valid=v[0];clear=v[1];sample_data=v[15:8];
  #1;if(rct_fail_now!==v[23:16] || apt_fail_now!==v[31:24])$fatal(1,"current fail mismatch NAME event %d",i);
  @(posedge clk);#1;if(rct_fault!==v[39:32] || apt_fault!==v[47:40])$fatal(1,"sticky mismatch NAME event %d",i);
 end
 $display("SUCCESS HEALTH MONITOR NAME EVENTS COUNT");$finish;
end
endmodule
""".replace('NAME',name).replace('RCT',str(rct)).replace('WINDOW',str(window)).replace('APT',str(apt)).replace('LAST',str(len(events)-1)).replace('COUNT',str(len(events)))
    tb_lines=tb.splitlines();tb_lines[5]='entropy_health_monitor #(.RCT_C({}),.APT_WINDOW({}),.APT_C({})) dut(.*);'.format(rct,window,apt);tb='\n'.join(tb_lines)+'\n'
    # Replace values without changing parameter identifiers.
    tb=tb.replace('.'+str(rct)+'_C(','.RCT_C(').replace('.'+str(window)+'(','.APT_WINDOW(').replace('.'+str(apt)+'_C(','.APT_C(')
    (out/('tb_monitor_'+name+'.sv')).write_text(tb)
print('Prepared monitor reference vectors')
