"""Health-gated raw capture and FPGA SHA3, sharing exactly ONE loaded overlay.

This is a functional research generator. No certified entropy credit is assigned.
The PS enforces the sequence; this is not an autonomous RO-to-SHA3 hardware path.
"""
import hashlib
import json
import time
import xml.etree.ElementTree as ET
from pathlib import Path
from trng_sha3 import Sha3Transport, validate_artifacts as check_sha3, validation_messages
from trng_health import HealthTransport, inspect_hwh as check_health

RELEASE_FILES = {"trng_sha3.bit", "trng_sha3.hwh", "trng_sha3.py", "trng_health.py",
                 "trng_pynq.py", "trng_collect.py"}


def validate_artifacts(bitfile="trng_sha3.bit"):
    bit = Path(bitfile).resolve()
    manifest = json.loads((bit.parent / "release_manifest.json").read_text(encoding="utf-8"))
    if bit.name != "trng_sha3.bit" or set(manifest["sha256"]) != RELEASE_FILES:
        raise RuntimeError("Upload the complete matching integrated release")
    for name, digest in manifest["sha256"].items():
        if hashlib.sha256((bit.parent / name).read_bytes()).hexdigest() != digest:
            raise RuntimeError("Release hash mismatch: " + name)
    if manifest.get("mode") != "physical_ro_health_ps_bridge_fpga_sha3":
        raise RuntimeError("Unexpected generator mode")
    audit = manifest["physical_audit"]
    if any(audit[k] != v for k, v in {"ro_gates":8,"ro_inverters":88,"synchronizer_flops":16}.items()):
        raise RuntimeError("Missing physical source audit")
    if audit["wns_ns"] < 0 or audit["whs_ns"] < 0:
        raise RuntimeError("Timing did not pass")
    if not manifest.get("checks") or any(v["status"] != "PASS" for v in manifest["checks"].values()):
        raise RuntimeError("Incomplete release validation")
    check_sha3(bit)
    check_health(bit.with_suffix(".hwh"))
    modules = {m.get("FULLNAME"):m for m in ET.parse(str(bit.with_suffix(".hwh"))).findall(".//MODULE")}
    for module, expected in {
            "/axi_control":{"NUM_SI":1,"NUM_MI":2},
            "/axi_memory":{"NUM_SI":2,"NUM_MI":1},
            "/sha3/sha3_dma":{"c_include_mm2s_dre":0,"c_include_s2mm_dre":0,
                              "c_sg_length_width":26,"c_m_axi_mm2s_data_width":32,
                              "c_m_axi_s2mm_data_width":32}}.items():
        pars = {p.get("NAME"):p.get("VALUE") for p in modules[module].findall("./PARAMETERS/PARAMETER")}
        if any(int(pars[k]) != v for k,v in expected.items()):
            raise RuntimeError("Unexpected interconnect/DMA configuration: " + module)
    ranges = modules["/processing_system7_0"].findall(".//MEMRANGE[@INSTANCE='sha3_sha3_dma']")
    if not any(int(p.get("BASEVALUE"),0)==0x40400000 and int(p.get("HIGHVALUE"),0)==0x4040ffff for p in ranges):
        raise RuntimeError("Unexpected DMA address range")
    return {"build_id":manifest["build_id"], "clock_mhz":25,
            "entropy_credit_validated":False, "certified":False}


class HealthSource(HealthTransport):
    def __init__(self, mmio, release):
        self.mmio, self.release = mmio, release
        self.check_configuration()
        if self.snapshot()["status"] or self.mmio.read(32):
            raise RuntimeError("Unexpected initial health state")


class Sha3Engine(Sha3Transport):
    def __init__(self, overlay, mmio):
        self.tx = self.rx = None
        self.in_flight = False
        self._mmio = mmio
        self._mmio.write(0, 1)
        self._mmio.write(0x30, 1)
        self._wait_halted(False, 5.0)
        self.dma = overlay.sha3.sha3_dma

    def stop(self):
        # Do not free memory or reconfigure until BOTH channels confirm HALTED.
        self._mmio.write(0, 0)
        self._mmio.write(0x30, 0)
        self._wait_halted(True, 5.0)
        self.in_flight = False
        self.close()


class TrngSession:
    def __init__(self, bitfile="trng_sha3.bit"):
        self.bitfile = str(Path(bitfile).resolve())
        self.release = validate_artifacts(self.bitfile)
        self.fault = None
        self.closed = True
        self.source = self.engine = None
        self._load()

    def _load(self):
        from pynq import Clocks, MMIO, Overlay
        self.overlay = Overlay(self.bitfile, download=False)
        print("Verified release; downloading ONE integrated overlay (RO OFF)", flush=True)
        self.overlay.download()
        if abs(float(Clocks.fclk0_mhz) - 25) > .1:
            raise RuntimeError("Unexpected FCLK0; stop before MMIO")
        self.source = HealthSource(MMIO(0x43c00000, 65536), self.release)
        self.engine = Sha3Engine(self.overlay, MMIO(0x40400000, 65536))
        self.closed = False
        print("Health source and SHA3 ready at 25 MHz", flush=True)

    def _ready(self):
        if self.closed:
            raise RuntimeError("Session is closed")
        if self.fault is not None:
            raise RuntimeError("Fault latched; preserve diagnostics and explicitly recover(): " + self.fault)

    def hash_known(self, message):
        """Diagnostic hash only; do not label known messages as random output."""
        self._ready()
        try:
            if self.source.mmio.read(32):
                raise RuntimeError("RO must be OFF during SHA3")
            actual = self.engine.hash(message)
            if actual != hashlib.sha3_256(message).digest():
                raise RuntimeError("FPGA SHA3 does not match hashlib")
            return actual
        except Exception as exc:
            self.fault = str(exc)
            raise

    def generate(self, divider=512):
        self._ready()
        try:
            capture = self.source.capture(divider)
            # capture() checks exact healthy state BEFORE and AFTER reading RAM.
            raw = capture["raw"]
            if len(raw) != 1024 or capture["health"] != self.source.snapshot():
                raise RuntimeError("Invalid capture length/state")
            digest = self.hash_known(raw)
            if self.source.snapshot() != capture["health"]:
                raise RuntimeError("Health state changed during SHA3")
            return {"raw":raw, "digest":digest, "health":capture["health"],
                    "divider":divider, "build_id":self.release["build_id"],
                    "fpga_sha3_matches_python":True, "functional_valid":True,
                    "entropy_credit_validated":False, "entropy_certified":False}
        except Exception as exc:
            self.fault = str(exc)
            raise

    def self_test(self, rounds=2):
        if type(rounds) is not int or not 1 <= rounds <= 10:
            raise ValueError("rounds must be 1..10")
        count = 0
        for _ in range(rounds):
            for name, message in validation_messages():
                self.hash_known(message)
                count += 1
                print("PASS SHA3", name, len(message), flush=True)
        print("SUCCESS {} known-message FPGA SHA3 comparisons".format(count), flush=True)
        return count

    def recover(self):
        self._ready_for_recovery()
        validate_artifacts(self.bitfile)
        # A failed stop propagates: preserve buffers, do NOT reload the FPGA.
        self.source.close()
        self.engine.stop()
        self.closed = True
        self._load()
        self.fault = None

    def _ready_for_recovery(self):
        if self.closed or self.source is None or self.engine is None:
            raise RuntimeError("Create a new session only after safe shutdown")

    def close(self):
        if self.closed:
            return
        self.source.close()
        self.engine.stop()
        self.closed = True
