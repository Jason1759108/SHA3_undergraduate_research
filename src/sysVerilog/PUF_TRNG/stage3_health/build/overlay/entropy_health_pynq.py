"""Finite raw-RO capture. File checks run before any PYNQ/hardware access."""
import hashlib,json,time,xml.etree.ElementTree as ET
from pathlib import Path
ID=0x524f4832
BASE=0x43c00000

def inspect_hwh(path):
    modules={m.get("FULLNAME"):m for m in ET.parse(str(path)).findall(".//MODULE")}
    def pars(name):return {p.get("NAME"):p.get("VALUE") for p in modules[name].findall("./PARAMETERS/PARAMETER")}
    def net(name,pin):
        p=modules[name].find("./PORTS/PORT[@NAME='{}']".format(pin))
        if p is None or not p.get("SIGNAME"):raise RuntimeError("Missing pin "+name+"/"+pin)
        return p.get("SIGNAME")
    ps="/processing_system7_0";reset="/rst_ps7_0_25M";ent="/entropy_ip";ctrl="/axi_control"
    pp=pars(ps)
    if float(pp["PCW_ACT_FPGA0_PERIPHERAL_FREQMHZ"])!=25 or int(pp["PCW_USE_M_AXI_GP0"])!=1 or int(pp["PCW_USE_S_AXI_HP0"])!=0:raise RuntimeError("Expected 25 MHz GP0-only PS")
    for k,v in {"DEPTH":1024,"WARMUP":1024,"STARTUP_SAMPLES":1024,"RCT_C":41,"APT_WINDOW":1024,"APT_C":793,"WATCHDOG":20000000}.items():
        if int(pars(ent)[k])!=v:raise RuntimeError("Unexpected entropy parameter "+k)
    rp=pars(reset)
    if int(rp["C_EXT_RESET_HIGH"])!=0 or int(rp["C_AUX_RESET_HIGH"])!=0:raise RuntimeError("Reset polarity must be active-low")
    def constant(pin,value):
        signal=net(reset,pin)
        ds=[name for name,m in modules.items() if m.get("VLNV","").startswith("xilinx.com:ip:xlconstant:") and any(p.get("DIR")=="O" and p.get("SIGNAME")==signal for p in m.findall("./PORTS/PORT"))]
        if len(ds)!=1 or int(pars(ds[0])["CONST_VAL"],0)!=value or int(pars(ds[0])["CONST_WIDTH"])!=1:raise RuntimeError("Unsafe reset constant on "+pin)
    constant("aux_reset_in",1);constant("dcm_locked",1);constant("mb_debug_sys_rst",0)
    if net(reset,"ext_reset_in")!=net(ps,"FCLK_RESET0_N"):raise RuntimeError("PS reset connection")
    clk=net(ps,"FCLK_CLK0")
    for name,pins in [(ps,["M_AXI_GP0_ACLK"]),(reset,["slowest_sync_clk"]),(ent,["s_axi_aclk"]),(ctrl,["ACLK","S00_ACLK","M00_ACLK"])]:
        if any(net(name,p)!=clk for p in pins):raise RuntimeError("Clock mismatch "+name)
    if net(ent,"s_axi_aresetn")!=net(reset,"peripheral_aresetn"):raise RuntimeError("Entropy reset mismatch")
    for pin in ["ARESETN","S00_ARESETN","M00_ARESETN"]:
        if net(ctrl,pin)!=net(reset,"interconnect_aresetn"):raise RuntimeError("Interconnect reset mismatch")
    for a,ap,b,bp in [(ps,"M_AXI_GP0",ctrl,"S00_AXI"),(ctrl,"M00_AXI",ent,"s_axi")]:
        x=modules[a].find("./BUSINTERFACES/BUSINTERFACE[@NAME='{}']".format(ap));y=modules[b].find("./BUSINTERFACES/BUSINTERFACE[@NAME='{}']".format(bp))
        if x is None or y is None or x.get("BUSNAME") in (None,"__NOC__") or x.get("BUSNAME")!=y.get("BUSNAME"):raise RuntimeError("AXI mismatch")
    ranges=ps and modules[ps].findall(".//MEMRANGE[@INSTANCE='entropy_ip']")
    if not any(int(m.get("BASEVALUE"),0)==BASE and int(m.get("HIGHVALUE"),0)==BASE+65535 for m in ranges):raise RuntimeError("Expected entropy 64 KiB at 0x43C00000")
    return {"clock_mhz":25,"base":BASE,"capacity":1024,"channels":8}

def validate_artifacts(bitfile):
    bit=Path(bitfile).resolve();meta=inspect_hwh(bit.with_suffix(".hwh"))
    manifest=json.loads((bit.parent/"release_manifest.json").read_text(encoding="utf-8"))
    required={"entropy_health.bit","entropy_health.hwh","entropy_health_pynq.py","analyze_raw.py","entropy_characterize.py","entropy_campaign.py"}
    if set(manifest["sha256"])!=required or manifest.get("health_configuration")!={"startup_samples":1024,"rct_c":41,"apt_window":1024,"apt_c":793}:raise RuntimeError("Wrong health release configuration")
    for name,digest in manifest["sha256"].items():
        # Jupyter updates outputs, execution counts, trust and metadata on save.
        # Accept legacy manifests that listed the editable notebook as well.
        if name == "Entropy_Health_Bringup.ipynb":
            continue
        p=bit.parent/name
        if p.name!=name or hashlib.sha256(p.read_bytes()).hexdigest()!=digest:raise RuntimeError("Release hash mismatch: "+name)
    if manifest["hardware_mode"]!="physical_ro" or manifest["physical_audit"]["ro_gates"]!=8 or manifest["physical_audit"]["ro_inverters"]!=88:raise RuntimeError("Missing physical RO implementation audit")
    if bit.name not in manifest["sha256"] or bit.with_suffix(".hwh").name not in manifest["sha256"]:raise RuntimeError("Wrong hardware filenames")
    meta["build_id"]=manifest["build_id"];return meta

class HealthFailure(RuntimeError):
    def __init__(self,message,snapshot):
        super().__init__(message);self.snapshot=snapshot

class EntropySession:
    def __init__(self,bitfile):
        self.bitfile=str(Path(bitfile).resolve());self.release=validate_artifacts(self.bitfile)
        from pynq import Clocks,MMIO,Overlay
        print("1/4 health release and clock/reset/AXI wiring checked",flush=True)
        self.overlay=Overlay(self.bitfile,download=False)
        print("2/4 HWH parsed; downloading health overlay (RO OFF)",flush=True)
        self.overlay.download()
        if abs(float(Clocks.fclk0_mhz)-25)>0.1:raise RuntimeError("Unexpected FCLK0; stop before MMIO")
        print("3/4 25 MHz verified; checking bounded register interface",flush=True)
        self.mmio=MMIO(BASE,65536)
        self.check_configuration()
        if self.mmio.read(32)!=0 or self.mmio.read(4)!=0:raise RuntimeError("Unexpected health startup state")
        print("4/4 health ID/config verified; RO OFF; ready",flush=True)
    def check_configuration(self):
        for off,value in {20:ID,12:1024,36:1024,40:41,44:20000000,60:1024,68:1024,72:793}.items():
            if self.mmio.read(off)!=value:raise RuntimeError("Health register mismatch at "+hex(off))
    def snapshot(self):
        return {name:self.mmio.read(off) for name,off in {"status":4,"count":8,"ro_enable":32,"fault_mask":48,"rct_mask":52,"apt_mask":56,"observed":64,"startup_seen":76}.items()}
    def abort(self,timeout=1.0):
        self.mmio.write(0,2);deadline=time.monotonic()+timeout
        while self.mmio.read(4)&1:
            if time.monotonic()>deadline:raise TimeoutError("Abort did not finish")
            time.sleep(.001)
        if self.mmio.read(32)!=0:raise RuntimeError("RO still enabled")
    def acknowledge_fault(self):
        if self.mmio.read(4)&1:raise RuntimeError("Abort before acknowledging a fault")
        self.mmio.write(0,4)
        if self.mmio.read(4)!=0 or self.mmio.read(48)!=0:raise RuntimeError("Fault did not clear")
    def capture(self,divider=512,timeout=2.0):
        if type(divider) is not int or not 16<=divider<=4096:raise ValueError("divider must be 16..4096")
        self.check_configuration()
        status=self.mmio.read(4)
        if status&1:raise RuntimeError("Capture already busy")
        if status&0x1c or self.mmio.read(48):raise HealthFailure("Fault is latched; preserve diagnostics before explicit acknowledgement",self.snapshot())
        self.mmio.write(0,4);self.mmio.write(16,divider)
        if self.mmio.read(16)!=divider:raise RuntimeError("Divider did not take effect")
        self.mmio.write(0,1);deadline=time.monotonic()+timeout
        while self.mmio.read(4)&1:
            if time.monotonic()>deadline:
                self.abort();raise TimeoutError("Capture timeout; abort completed; stop and inspect")
            time.sleep(.001)
        state=self.snapshot()
        if state!={"status":194,"count":1024,"ro_enable":0,"fault_mask":0,"rct_mask":0,"apt_mask":0,"observed":2048,"startup_seen":1024}:
            raise HealthFailure("Batch invalid; no sample RAM was read",state)
        raw=bytearray()
        for i in range(1024):
            word=self.mmio.read(4096+4*i)
            if word>>8:raise RuntimeError("Invalid raw sample word")
            raw.append(word)
        if self.snapshot()!=state:raise RuntimeError("Capture state changed during readback")
        return {"raw":bytes(raw),"count":1024,"status":194,"alarm":False,"fault_mask":0,"divider":divider,"clock_mhz":25,"build_id":self.release["build_id"],"health":state,"entropy_certified":False}
    def close(self):
        if self.mmio.read(4)&1:self.abort()
        if self.mmio.read(32)!=0:raise RuntimeError("RO not off at close")

def save_capture(capture,prefix,board_id):
    if not board_id.strip():raise ValueError("Record the actual board ID")
    p=Path(prefix);raw=capture["raw"];meta={k:v for k,v in capture.items() if k!="raw"}
    meta.update({"board_id":board_id,"sha256":hashlib.sha256(raw).hexdigest(),"format":"one byte per sampling instant, bit k = RO k; unconditioned raw data","entropy_certified":False})
    p.with_suffix(".bin").write_bytes(raw);p.with_suffix(".json").write_text(json.dumps(meta,indent=2)+"\n",encoding="utf-8")
    return str(p.with_suffix(".bin"))
