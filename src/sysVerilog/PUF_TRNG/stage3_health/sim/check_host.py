"""PYNQ 2.5 parser is original; MMIO/Overlay/clock are mocked, never hardware."""
import hashlib,json,sys,tempfile,types,urllib.request
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/"python"))
import entropy_health_pynq as d
from analyze_raw import analyze

def main():
    folder=Path((ROOT/"build/system_sim_path.txt").read_text().strip());project=folder.parents[3]
    hwh=list(project.glob("*.gen/sources_1/bd/design_1/hw_handoff/design_1.hwh"))[0]
    d.inspect_hwh(hwh)
    cache=ROOT/"build/pynq25";cache.mkdir(parents=True,exist_ok=True);source=cache/"hwh_parser.py"
    if not source.exists():
        old=ROOT.parent/"stage1_sha3/build/pynq25_compat/hwh_parser.py"
        source.write_bytes(old.read_bytes() if old.exists() else urllib.request.urlopen("https://raw.githubusercontent.com/Xilinx/PYNQ/v2.5/pynq/pl_server/hwh_parser.py",timeout=30).read())
    pynq=types.ModuleType("pynq");ps=types.ModuleType("pynq.ps");ps.CPU_ARCH_IS_SUPPORTED=True;ps.CPU_ARCH=ps.ZYNQ_ARCH="armv7l";ps.ZU_ARCH="aarch64"
    x=types.ModuleType("pynq.xlnk");x.Xlnk=type("Xlnk",(),{"cma_mem_size":lambda _:512*1024*1024})
    sys.modules.update({"pynq":pynq,"pynq.ps":ps,"pynq.xlnk":x})
    ns={"__name__":"pynq.pl_server.hwh_parser"};exec(compile(source.read_text(),str(source),"exec"),ns)
    parsed=ns["HWH"](str(hwh));assert parsed.ip_dict["entropy_ip"]["phys_addr"]==d.BASE;assert parsed.ip_dict["entropy_ip"]["addr_range"]==65536
    print("PASS original PYNQ 2.5 HWH parser, custom peripheral base and range")
    class HW:
        def __init__(self):self.downloads=0;self.mmios=0;self.stuck=False;self.alarm=False;self.badid=False;self.ram_reads=0;self.override={};self.reg={4:0,8:0,12:1024,16:512,20:d.ID,32:0,36:1024,40:41,44:20000000,48:0,52:0,56:0,60:1024,64:0,68:1024,72:793,76:0}
        def read(self,off):
            if off==20 and self.badid:return 0
            if off>=4096:self.ram_reads+=1;return ((off-4096)//4*29+7)%256
            if off==4 and self.reg[4]&1 and not self.stuck:
                self.reg.update({4:6 if self.alarm else 194,8:0 if self.alarm else 1024,32:0,48:255 if self.alarm else 0,52:255 if self.alarm else 0,56:0,64:41 if self.alarm else 2048,76:0 if self.alarm else 1024})
                self.reg.update(self.override)
            return self.reg[off]
        def write(self,off,val):
            if off==16:self.reg[16]=val
            elif val==4:self.reg.update({4:0,8:0,48:0,52:0,56:0,64:0,76:0})
            elif val==1:self.reg.update({4:1,32:1})
            elif val==2:self.reg.update({4:10,32:0})
    hw=HW()
    class Overlay:
        def __init__(self,path,download=False):assert not download
        def download(self):hw.downloads+=1
    def mmio(base,size):assert base==d.BASE and size==65536;hw.mmios+=1;return hw
    pynq.Overlay=Overlay;pynq.MMIO=mmio;pynq.Clocks=types.SimpleNamespace(fclk0_mhz=25)
    with tempfile.TemporaryDirectory() as tmp:
        out=Path(tmp);bit=out/"entropy_health.bit";bit.write_bytes(b"software-test-fixture-only");h=bit.with_suffix(".hwh");h.write_bytes(hwh.read_bytes())
        notebook=out/"Entropy_Health_Bringup.ipynb";notebook.write_text(json.dumps({"cells":[],"metadata":{},"nbformat":4,"nbformat_minor":2}))
        driver_copy=out/"entropy_health_pynq.py";driver_copy.write_bytes((ROOT/"python/entropy_health_pynq.py").read_bytes())
        analyzer_copy=out/"analyze_raw.py";analyzer_copy.write_bytes((ROOT/"python/analyze_raw.py").read_bytes())
        extras=[]
        for name in ["entropy_characterize.py","entropy_campaign.py"]:
            copy=out/name;copy.write_bytes((ROOT/"python"/name).read_bytes());extras.append(copy)
        def manifest():
            (out/"release_manifest.json").write_text(json.dumps({"build_id":"mock-test-only","hardware_mode":"physical_ro","health_configuration":{"startup_samples":1024,"rct_c":41,"apt_window":1024,"apt_c":793},"physical_audit":{"ro_gates":8,"ro_inverters":88},"sha256":{p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in [bit,h,driver_copy,analyzer_copy]+extras}}))
        manifest()
        saved=json.loads(notebook.read_text());saved["metadata"]={"trusted":True};saved["cells"]=[{"cell_type":"code","source":["print('kernel OK')"],"metadata":{},"execution_count":1,"outputs":[{"output_type":"stream","name":"stdout","text":["kernel OK\n"]}]}]
        notebook.write_text(json.dumps(saved));d.validate_artifacts(bit)
        count=hw.downloads;driver_copy.write_bytes(b"changed driver")
        try:d.EntropySession(bit)
        except RuntimeError as exc:assert "entropy_health_pynq.py" in str(exc)
        else:raise AssertionError("Changed immutable driver accepted")
        assert hw.downloads==count
        driver_copy.write_bytes((ROOT/"python/entropy_health_pynq.py").read_bytes())
        print("PASS notebook auto-save accepted; changed driver still rejected before download")
        session=d.EntropySession(bit);c=session.capture();assert c["count"]==1024 and not c["alarm"] and c["raw"]==bytes((i*29+7)%256 for i in range(1024));session.close()
        for broken in [{4:66},{8:1023},{64:2047},{76:1023},{52:1},{56:1}]:
            hw.override=broken;reads=hw.ram_reads
            try:session.capture()
            except d.HealthFailure:pass
            else:raise AssertionError('Invalid health state returned data: '+str(broken))
            assert hw.ram_reads==reads
            hw.override={};session.acknowledge_fault()
        print('PASS missing batch-valid, incomplete counts/startup, RCT/APT masks reject before RAM')
        hw.alarm=True;reads=hw.ram_reads
        try:session.capture()
        except d.HealthFailure as exc:assert exc.snapshot['rct_mask']==255
        else:raise AssertionError('Fault returned data')
        assert hw.ram_reads==reads and hw.reg[32]==0
        try:session.capture()
        except d.HealthFailure:pass
        else:raise AssertionError('Latched fault auto-cleared')
        session.acknowledge_fault();hw.alarm=False;hw.stuck=True
        try:session.capture(timeout=-1)
        except TimeoutError:pass
        else:raise AssertionError('Missing capture timeout')
        assert hw.reg[32]==0 and hw.reg[4]==10
        hw.stuck=False;session.acknowledge_fault();session.capture();session.close()
        print('PASS valid-only readback, no RAM access on health fault, sticky acknowledgement, timeout abort, recovery')
        count=hw.downloads;bit.write_bytes(b"tampered")
        try:d.EntropySession(bit)
        except RuntimeError:pass
        else:raise AssertionError("Hash mismatch accepted")
        assert count==hw.downloads
        # Mutate real HWH to the previous reset fault, and also break the clock.
        import xml.etree.ElementTree as E
        for pin in ["aux_reset_in","s_axi_aclk"]:
            t=E.parse(hwh)
            if pin=="aux_reset_in":
                reset=t.find(".//MODULE[@FULLNAME='/rst_ps7_0_25M']");zero=t.find(".//MODULE[@FULLNAME='/constant_zero']/PORTS/PORT[@NAME='dout']");reset.find("./PORTS/PORT[@NAME='aux_reset_in']").set("SIGNAME",zero.get("SIGNAME"))
            else:t.find(".//MODULE[@FULLNAME='/entropy_ip']/PORTS/PORT[@NAME='s_axi_aclk']").set("SIGNAME","wrong_clock")
            t.write(h);manifest()
            try:d.EntropySession(bit)
            except RuntimeError:pass
            else:raise AssertionError("Unsafe wiring accepted: "+pin)
            assert count==hw.downloads
        h.write_bytes(hwh.read_bytes());manifest();pynq.Clocks.fclk0_mhz=50;mmios=hw.mmios
        try:d.EntropySession(bit)
        except RuntimeError:pass
        else:raise AssertionError("Wrong hardware clock accepted")
        assert hw.mmios==mmios
        print("PASS mismatched release, active aux reset, wrong AXI clock rejected before download; wrong FCLK rejected before MMIO")
    assert all(c["stuck"] for c in analyze(bytes(128))["channels"])
    result={"status":"PASS","hardware":"mocked","pynq":"2.5 parser unchanged","parser_sha256":hashlib.sha256(source.read_bytes()).hexdigest(),"source_sha256":{p.relative_to(ROOT).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in [ROOT/"python/entropy_health_pynq.py",ROOT/"python/analyze_raw.py",ROOT/"sim/check_host.py"]}}
    (ROOT/"build/host_pass.json").write_text(json.dumps(result,indent=2)+"\n")
if __name__=="__main__":main()
