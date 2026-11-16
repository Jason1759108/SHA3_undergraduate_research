"""Original PYNQ 2.5 parser/DMA; mocked MMIO, allocation, clocks and download.

Mock hash computation tests software branches only. Real SHA3 is tested in xsim.
"""
import hashlib, importlib.util, json, os, sys, tempfile, types, zipfile
import xml.etree.ElementTree as ET
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/"python"))
import trng_pynq as d
import trng_sha3 as sha
import trng_health as health
from trng_collect import collect


def main():
    print("OFFLINE SOFTWARE MOCK TEST ONLY - NO FPGA/BOARD WAS USED",flush=True)
    hwh=ROOT/"build/trng_integrated/trng_integrated.gen/sources_1/bd/design_1/hw_handoff/design_1.hwh"
    spec=importlib.util.spec_from_file_location("prior_host",ROOT.parent/"stage1_sha3/sim/check_host.py")
    prior=importlib.util.module_from_spec(spec);spec.loader.exec_module(prior)
    pynq=types.ModuleType("pynq");ps=types.ModuleType("pynq.ps")
    ps.CPU_ARCH_IS_SUPPORTED=True;ps.CPU_ARCH=ps.ZYNQ_ARCH="armv7l";ps.ZU_ARCH="aarch64"
    x=types.ModuleType("pynq.xlnk");x.Xlnk=type("Xlnk",(),{"cma_mem_size":lambda _:512*1024*1024})
    sys.modules.update({"pynq":pynq,"pynq.ps":ps,"pynq.xlnk":x})
    cache=ROOT.parent/"stage1_sha3/build/pynq25_compat"
    ns={"__name__":"pynq.pl_server.hwh_parser"}
    exec(compile((cache/"hwh_parser.py").read_text(),"original-pynq25-parser","exec"),ns)
    parsed=ns["HWH"](str(hwh));desc=parsed.ip_dict["sha3/sha3_dma"]
    assert desc["phys_addr"]==0x40400000 and parsed.ip_dict["entropy_ip"]["phys_addr"]==0x43c00000
    assert parsed.clock_dict[0]=={"enable":1,"divisor0":8,"divisor1":5}
    print("PASS original PYNQ 2.5 parser: TWO IPs, DMA hierarchy and 25 MHz")
    class DMAHW(prior.Hardware):
        corrupt=False;bad_status=False;short=False;dma_error=False;changed_health=False
        def write(self,off,value):
            super().write(off,value)
            if off==0x28 and not self.transfer_stuck:
                rx=self.buffers[self.regs[0x48]]
                if self.corrupt:rx[1]^=1
                if self.bad_status:rx[0]=0x53480003
                if self.short:self.regs[0x58]=32
                if self.dma_error:self.regs[0x34]=0x12
                if self.changed_health:source.reg[8]=1023
    hw=DMAHW()
    class SourceHW:
        alarm=False;stuck=False;override=None;ram_reads=0;bad_word=False;change_during_read=False
        def reset(self):
            self.reg={4:0,8:0,12:1024,16:512,20:health.ID,32:0,36:1024,40:41,44:20000000,48:0,52:0,56:0,60:1024,64:0,68:1024,72:793,76:0}
        def read(self,off):
            if off>=4096:
                self.ram_reads+=1
                if self.change_during_read and off==8188:self.reg[8]=1023
                return 256 if self.bad_word else ((off-4096)//4*29+7)%256
            if off==4 and self.reg[4]&1 and not self.stuck:
                self.reg.update({4:6 if self.alarm else 194,8:0 if self.alarm else 1024,32:0,48:255 if self.alarm else 0,52:255 if self.alarm else 0,56:0,64:41 if self.alarm else 2048,76:0 if self.alarm else 1024})
                self.reg.update(self.override or {})
            return self.reg[off]
        def write(self,off,val):
            if off==16:self.reg[16]=val
            elif val==4:self.reg.update({4:0,8:0,48:0,52:0,56:0,64:0,76:0})
            elif val==1:self.reg.update({4:1,32:1})
            elif val==2:self.reg.update({4:10,32:0})
    source=SourceHW();source.reset()
    class DefaultIP:
        def __init__(self,description):self.mmio=hw
    pynq.DefaultIP=DefaultIP
    dn={"__name__":"pynq.lib.dma"};exec(compile((cache/"dma.py").read_text(),"original-pynq25-dma","exec"),dn)
    class Overlay:
        def __init__(self,path,download=False):
            assert not download
            self.sha3=self;self._dma=None
        def download(self):hw.downloads+=1;hw.reset();source.reset()
        @property
        def sha3_dma(self):
            if self._dma is None:self._dma=dn["DMA"](desc)
            return self._dma
    pynq.Overlay=Overlay;pynq.Clocks=types.SimpleNamespace(fclk0_mhz=25)
    pynq.MMIO=lambda base,size: source if base==0x43c00000 else hw
    pynq.allocate=lambda shape,dtype:prior.Buffer(hw,shape[0])
    sys.modules["numpy"]=types.SimpleNamespace(uint32=int)
    ticks=[0]
    def monotonic():ticks[0]+=.1;return ticks[0]
    timer=types.SimpleNamespace(monotonic=monotonic,sleep=lambda _:None)
    sha.time=health.time=timer
    checks=0
    def rejects(fn,typ=Exception):
        nonlocal checks
        try:fn()
        except typ:checks+=1
        else:raise AssertionError("Expected rejection")
    with tempfile.TemporaryDirectory() as tmp:
        out=Path(tmp);bit=out/"trng_sha3.bit"
        bit.write_bytes(b"MOCK SOFTWARE FIXTURE NEVER PROGRAM")
        bit.with_suffix(".hwh").write_bytes(hwh.read_bytes())
        for name in d.RELEASE_FILES-{"trng_sha3.bit","trng_sha3.hwh"}:
            (out/name).write_bytes((ROOT/"python"/name).read_bytes())
        def manifest():
            (out/"release_manifest.json").write_text(json.dumps({"build_id":"mock-only","mode":"physical_ro_health_ps_bridge_fpga_sha3","checks":{"mock":{"status":"PASS"}},"physical_audit":{"ro_gates":8,"ro_inverters":88,"synchronizer_flops":16,"wns_ns":1,"whs_ns":.01},"sha256":{n:hashlib.sha256((out/n).read_bytes()).hexdigest() for n in d.RELEASE_FILES}}))
        manifest();d.validate_artifacts(bit)
        s=d.TrngSession(bit);assert hw.downloads==1
        assert s.self_test()==34
        for _ in range(3):
            r=s.generate();assert r["digest"]==hashlib.sha3_256(r["raw"]).digest()
        assert hw.downloads==1
        print("PASS shared overlay downloaded ONCE; original DMA transfers; 34 KAT plus repeated generate")
        report=collect(s,"mock-board","2026-11-15",count=2,root=str(out/"results"))
        assert report["summary"]["status"]=="PASS_FUNCTIONAL"
        assert report["summary"]["raw_bytes"]==2048 and report["summary"]["digest_bytes"]==64
        for override in ({4:66},{8:1023},{64:2047},{76:1023},{52:1},{56:1}):
            source.override=override;before=len(hw.buffers);reads=source.ram_reads
            rejects(s.generate,health.HealthFailure)
            assert len(hw.buffers)==before and source.ram_reads==reads
            rejects(s.generate,RuntimeError);source.override=None;s.recover()
        source.alarm=True;before=len(hw.buffers);reads=source.ram_reads
        rejects(s.generate,health.HealthFailure);assert source.ram_reads==reads and len(hw.buffers)==before
        source.alarm=False;s.recover()
        source.stuck=True;rejects(s.generate,TimeoutError);assert source.reg[32]==0
        source.stuck=False;s.recover()
        source.bad_word=True;rejects(s.generate,RuntimeError);source.bad_word=False;s.recover()
        before=len(hw.buffers);source.change_during_read=True
        rejects(s.generate,RuntimeError);assert len(hw.buffers)==before
        source.change_during_read=False;s.recover()
        print("PASS invalid/startup/RCT/APT/count cases reject BEFORE RAM/DMA; capture timeout aborts")
        for flag in ("corrupt","bad_status","short","dma_error","transfer_stuck","changed_health"):
            setattr(hw,flag,True);rejects(s.generate);rejects(s.generate,RuntimeError)
            if flag in ("dma_error","transfer_stuck"):
                tx,rx=s.engine.tx,s.engine.rx
                assert s.engine.in_flight and not tx.freed and not rx.freed
                hw.stop_stuck=True;downloads=hw.downloads
                rejects(s.recover,TimeoutError)
                assert hw.downloads==downloads and not tx.freed and not rx.freed
                hw.stop_stuck=False
            setattr(hw,flag,False);s.recover();s.generate()
        print("PASS wrong digest/status/length/DMA error/timeout latch; stuck-stop NEVER frees/reloads; explicit recovery")
        # Half-allocation failure retains the first allocation for safe cleanup.
        real_allocate=pynq.allocate;alloc=[0]
        def failed_alloc(shape,dtype):
            alloc[0]+=1
            if alloc[0]==2:raise MemoryError("fixture")
            return real_allocate(shape,dtype)
        pynq.allocate=failed_alloc;rejects(s.generate,MemoryError)
        assert s.engine.tx is not None and not s.engine.tx.freed and not s.engine.in_flight
        pynq.allocate=real_allocate;s.recover();s.generate();s.close();rejects(s.generate,RuntimeError)
        downloads=hw.downloads
        (out/"trng_pynq.py").write_bytes(b"tampered");rejects(lambda:d.TrngSession(bit),RuntimeError)
        assert downloads==hw.downloads
        (out/"trng_pynq.py").write_bytes((ROOT/"python/trng_pynq.py").read_bytes());manifest()
        for module,pin in (("/entropy_ip","s_axi_aclk"),("/sha3/sha3_ip","axis_aresetn"),("/rst_ps7_0_25M","aux_reset_in")):
            tree=ET.parse(hwh);tree.find(".//MODULE[@FULLNAME='{}']/PORTS/PORT[@NAME='{}']".format(module,pin)).set("SIGNAME","broken")
            tree.write(bit.with_suffix(".hwh"));manifest();rejects(lambda:d.TrngSession(bit))
            assert downloads==hw.downloads
        for module,bus in (("/axi_control","M01_AXI"),("/sha3/sha3_ip","S_AXIS"),("/processing_system7_0","S_AXI_HP0")):
            tree=ET.parse(hwh);tree.find(".//MODULE[@FULLNAME='{}']/BUSINTERFACES/BUSINTERFACE[@NAME='{}']".format(module,bus)).set("BUSNAME","broken")
            tree.write(bit.with_suffix(".hwh"));manifest();rejects(lambda:d.TrngSession(bit))
            assert downloads==hw.downloads
        print("PASS allocation ownership, closed session, driver tamper and clock/reset rejection before download")
        bit.with_suffix(".hwh").write_bytes(hwh.read_bytes());manifest()
        s=d.TrngSession(bit);source.alarm=True
        rejects(lambda:collect(s,"mock-board","2026-11-16",count=2,root=str(out/"failed")),health.HealthFailure)
        failed=list((out/"failed").glob("*/summary.json"))
        assert len(failed)==1 and json.loads(failed[0].read_text())["status"]=="FAILED_STOPPED"
        assert json.loads(failed[0].read_text())["completed_batches"]==0
        assert len(list((out/"failed").glob("*.zip")))==1
        source.alarm=False;s.close()
        # Execute OUR authored notebook against mocks, including full 1000x1000 export.
        nb=json.loads((ROOT/"python/TRNG_Integrated_Bringup.ipynb").read_text(encoding="utf-8"))
        pynq.__version__="2.5";env={};old_cwd=os.getcwd()
        try:
            os.chdir(str(out))
            for cell in nb["cells"]:
                if cell["cell_type"]=="code":
                    code="".join(cell["source"]).replace('experiment_date = "請填實際日期 YYYY-MM-DD"','experiment_date = "2026-11-16"')
                    exec(compile(code,"authored-notebook-mock","exec"),env)
        finally:os.chdir(old_cwd)
        dataset=Path(env["campaign"]["archive"]).stem
        exports=out/"trng_results"/dataset/"datasets"
        assert (exports/"raw_joint_concat.bin").stat().st_size==1024000
        assert (exports/"restart_joint_1000x1000.bin").stat().st_size==1000000
        assert (exports/"conditioned_sha3_256.bin").stat().st_size==32000
        assert env["session"].closed
        spec=importlib.util.spec_from_file_location("review_capture",ROOT/"sim/review_board_capture.py")
        reviewer=importlib.util.module_from_spec(spec);spec.loader.exec_module(reviewer)
        archive=out/env["campaign"]["archive"]
        reviewed=reviewer.review(archive,out/"release_manifest.json")
        assert reviewed["batches"]==1000 and reviewed["duplicate_raw_batches"]==999
        bad=out/"corrupted_capture.zip"
        with zipfile.ZipFile(archive) as src,zipfile.ZipFile(bad,"w",zipfile.ZIP_DEFLATED) as dst:
            for name in src.namelist():
                data=src.read(name)
                if name=="batch_0000.bin":data=bytes([data[0]^1])+data[1:]
                dst.writestr(name,data)
        rejects(lambda:reviewer.review(bad,out/"release_manifest.json"),RuntimeError)
        print("PASS failed collection evidence and complete authored notebook with 1000-batch/restart export (MOCK)")
    result={"status":"PASS","expected_rejections":checks,"pynq":"2.5 original parser and DMA; MMIO/Overlay/allocate mocked","authored_notebook_execution":"MOCK ONLY, not board acceptance","hwh_sha256":hashlib.sha256(hwh.read_bytes()).hexdigest()}
    result["source_sha256"]={p.relative_to(ROOT).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(list((ROOT/"python").glob("*.py"))+[Path(__file__),ROOT/"python/TRNG_Integrated_Bringup.ipynb",ROOT/"sim/review_board_capture.py"])}
    (ROOT/"build/host_pass.json").write_text(json.dumps(result,indent=2)+"\n")
    print("SUCCESS INTEGRATED HOST",checks,"expected rejections")
if __name__=="__main__":main()
