"""Offline host checks using the official PYNQ 2.5 parser and DMA driver.

The hardware memory-size query, MMIO, allocation and Overlay download are mocked.
The parser and _DMAChannel implementations are loaded without source edits.
"""
import hashlib
import json
import sys
import tempfile
import types
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "python"))
import sha3_pynq as driver


class Buffer(list):
    def __init__(self, hardware, size):
        super().__init__([0] * size)
        self.hardware = hardware
        self.nbytes = size * 4
        self.physical_address = hardware.next_address
        hardware.next_address += 0x10000
        hardware.buffers[self.physical_address] = self
        self.freed = False

    def __setitem__(self, key, value):
        if isinstance(key, slice) and isinstance(value, int):
            value = [value] * len(range(*key.indices(len(self))))
        super().__setitem__(key, value)

    def flush(self):
        pass

    def invalidate(self):
        pass

    def freebuffer(self):
        assert not self.hardware.transfer_live, "Freed buffer during live DMA"
        self.freed = True


class Hardware:
    def __init__(self):
        self.buffers = {}
        self.next_address = 0x10000000
        self.downloads = 0
        self.start_stuck = self.stop_stuck = self.transfer_stuck = False
        self.reset()

    def reset(self):
        self.regs = {4: 1, 0x34: 1}
        self.transfer_live = False

    def read(self, offset):
        return self.regs.get(offset, 0)

    def write(self, offset, value):
        self.regs[offset] = int(value)
        if offset in (0, 0x30):
            if value & 1:
                self.regs[offset + 4] = 1 if self.start_stuck else 0
            elif not self.stop_stuck:
                self.regs[offset + 4] = 1
                if self.regs.get(4) == self.regs.get(0x34) == 1:
                    self.transfer_live = False
        if offset == 0x28:
            self.transfer_live = True
            self.regs[4] = self.regs[0x34] = 0
            if not self.transfer_stuck:
                tx = self.buffers[self.regs[0x18]]
                rx = self.buffers[self.regs[0x48]]
                message = b""
                for index in range(0, len(tx), 35):
                    block = b"".join(int(w).to_bytes(4, "little") for w in tx[index+1:index+35])
                    message += block[:tx[index] & 255]
                digest = hashlib.sha3_256(message).digest()
                rx[:] = [driver.SUCCESS] + [int.from_bytes(digest[i:i+4], "little") for i in range(0, 32, 4)]
                self.regs[4] = self.regs[0x34] = 2
                self.regs[0x58] = 36
                self.transfer_live = False


def main():
    cache = ROOT / "build/pynq25_compat"
    cache.mkdir(parents=True, exist_ok=True)
    for name, relative in (("hwh_parser.py", "pl_server/hwh_parser.py"), ("dma.py", "lib/dma.py")):
        path = cache / name
        if not path.exists():
            url = "https://raw.githubusercontent.com/Xilinx/PYNQ/v2.5/pynq/" + relative
            path.write_bytes(urllib.request.urlopen(url, timeout=30).read())
    pynq = types.ModuleType("pynq")
    ps = types.ModuleType("pynq.ps")
    ps.CPU_ARCH_IS_SUPPORTED = True
    ps.CPU_ARCH = ps.ZYNQ_ARCH = "armv7l"
    ps.ZU_ARCH = "aarch64"
    xlnk = types.ModuleType("pynq.xlnk")
    xlnk.Xlnk = type("Xlnk", (), {"cma_mem_size": lambda _: 512 * 1024 * 1024})
    sys.modules.update({"pynq": pynq, "pynq.ps": ps, "pynq.xlnk": xlnk})
    parser_ns = {"__name__": "pynq.pl_server.hwh_parser"}
    exec(compile((cache / "hwh_parser.py").read_text(), "PYNQ-v2.5-hwh_parser.py", "exec"), parser_ns)
    hwh_path = ROOT / "build/sha3_pynq/sha3_pynq.gen/sources_1/bd/design_1/hw_handoff/design_1.hwh"
    parsed = parser_ns["HWH"](str(hwh_path))
    desc = parsed.ip_dict["sha3/sha3_dma"]
    assert desc["phys_addr"] == 0x40400000
    assert parsed.clock_dict[0] == {"enable": 1, "divisor0": 8, "divisor1": 5}
    assert "sha3" in parsed.hierarchy_dict
    print("PASS unmodified PYNQ 2.5 HWH parser: DMA address, clocks and hierarchy")

    hardware = Hardware()

    class DefaultIP:
        def __init__(self, description):
            self.mmio = hardware

    pynq.DefaultIP = DefaultIP
    dma_ns = {"__name__": "pynq.lib.dma"}
    exec(compile((cache / "dma.py").read_text(), "PYNQ-v2.5-dma.py", "exec"), dma_ns)

    class Overlay:
        def __init__(self, bitfile, download=True):
            self.ip_dict = {"sha3/sha3_dma": desc}
            self.sha3 = self
            self._dma = None
            if download:
                self.download()

        def download(self):
            hardware.downloads += 1
            hardware.reset()

        @property
        def sha3_dma(self):
            if self._dma is None:
                self._dma = dma_ns["DMA"](desc)
            return self._dma

    pynq.Overlay = Overlay
    pynq.Clocks = types.SimpleNamespace(fclk0_mhz=25.0)
    pynq.MMIO = lambda address, length: hardware
    pynq.allocate = lambda shape, dtype: Buffer(hardware, shape[0])
    sys.modules["numpy"] = types.SimpleNamespace(uint32=int)
    ticks = [0]

    def monotonic():
        ticks[0] += 0.1
        return ticks[0]

    driver.time = types.SimpleNamespace(monotonic=monotonic, sleep=lambda _: None)
    with tempfile.TemporaryDirectory(dir=str(cache)) as tmp:
        folder = Path(tmp)
        bit = folder / "sha3_pynq.bit"
        bit.write_bytes(b"MOCK BITSTREAM - NEVER PROGRAM HARDWARE")
        hwh = bit.with_suffix(".hwh")
        hwh.write_bytes(hwh_path.read_bytes())
        manifest = {"build_id": "offline-test", "sha256": {
            p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in (bit, hwh)}}
        (folder / "release_manifest.json").write_text(json.dumps(manifest))
        driver.validate_artifacts(bit)
        session = driver.Sha3Session(bit)
        for _, message in driver.validation_messages():
            assert session.hash(message) == hashlib.sha3_256(message).digest()
        print("PASS driver transfers with original PYNQ 2.5 DMA channel implementation")
        hardware.transfer_stuck = True
        try:
            session.hash(b"timeout", timeout=0.3)
        except TimeoutError:
            pass
        else:
            raise AssertionError("Missing transfer timeout")
        tx, rx = session.tx, session.rx
        assert session.in_flight and not tx.freed and not rx.freed
        hardware.stop_stuck = True
        count = hardware.downloads
        try:
            session.reset()
        except TimeoutError:
            pass
        else:
            raise AssertionError("Missing stop timeout")
        assert hardware.downloads == count and not tx.freed and not rx.freed
        print("PASS failed DMA stop retains buffers and prevents PL reconfiguration")
        hardware.stop_stuck = hardware.transfer_stuck = False
        session.reset()
        assert tx.freed and rx.freed
        assert session.hash(b"after recovery") == hashlib.sha3_256(b"after recovery").digest()
        session.close()
        print("PASS graceful halt, reload, DMA driver recreation and reuse")
        hardware.start_stuck = True
        try:
            driver.Sha3Session(bit)
        except TimeoutError:
            pass
        else:
            raise AssertionError("Missing startup timeout")
        print("PASS bounded startup while MMIO responds but DMA remains halted")
        bit.write_bytes(b"mismatched hardware")
        count = hardware.downloads
        try:
            driver.Sha3Session(bit)
        except RuntimeError as exc:
            assert "hash mismatch" in str(exc)
        else:
            raise AssertionError("Mismatched hardware accepted")
        assert hardware.downloads == count
        print("PASS mismatched release rejected before hardware access")
    (cache / "host_checks_passed.json").write_text(json.dumps({
        "status": "PASS", "pynq": "2.5", "hardware": "mocked",
        "driver_sha256": hashlib.sha256((ROOT / "python/sha3_pynq.py").read_bytes()).hexdigest(),
        "parser_source_sha256": hashlib.sha256((cache / "hwh_parser.py").read_bytes()).hexdigest(),
        "dma_source_sha256": hashlib.sha256((cache / "dma.py").read_bytes()).hexdigest(),
    }, indent=2))


if __name__ == "__main__":
    main()
