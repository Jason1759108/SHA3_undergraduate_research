"""PYNQ simple-mode DMA driver for the stage-one SHA3-256 overlay."""
import hashlib
import json
import time
import xml.etree.ElementTree as ET
from pathlib import Path

RATE_BYTES = 136
WORDS_PER_BLOCK = 35
REPLY_WORDS = 9
SUCCESS = 0x53480000
MAX_MESSAGE_BYTES = 1024 * 1024


def validate_reset_wiring(bitfile):
    """Reject the known held-reset connection before touching the FPGA."""
    hwh = Path(bitfile).with_suffix(".hwh")
    modules = ET.parse(str(hwh)).findall(".//MODULE")
    resets = [m for m in modules if m.get("VLNV", "").startswith("xilinx.com:ip:proc_sys_reset:")]
    if len(resets) != 1:
        raise RuntimeError("Expected one Processor System Reset in the stage-one HWH")
    parameters = {p.get("NAME"): p.get("VALUE") for p in resets[0].findall("./PARAMETERS/PARAMETER")}
    aux = resets[0].find("./PORTS/PORT[@NAME='aux_reset_in']")
    if aux is None or not aux.get("SIGNAME"):
        raise RuntimeError("Cannot verify aux_reset_in in the HWH")
    constants = [
        m for m in modules
        if m.get("VLNV", "").startswith("xilinx.com:ip:xlconstant:")
        and any(p.get("DIR") == "O" and p.get("SIGNAME") == aux.get("SIGNAME")
                for p in m.findall("./PORTS/PORT"))
    ]
    if len(constants) != 1:
        raise RuntimeError("Expected a constant inactive level for aux_reset_in")
    constant_parameters = {p.get("NAME"): p.get("VALUE")
                           for p in constants[0].findall("./PARAMETERS/PARAMETER")}
    active = int(parameters["C_AUX_RESET_HIGH"])
    value = int(constant_parameters["CONST_VAL"], 0)
    width = int(constant_parameters["CONST_WIDTH"])
    if width != 1 or value not in (0, 1) or value == active:
        raise RuntimeError(
            "Unsafe reset wiring: aux_reset_in active={} constant={}. "
            "Fix the Block Design and rebuild/export bit and hwh before loading.".format(active, value))


def validate_artifacts(bitfile):
    """Inspect this release using files only, before accessing board hardware."""
    bitfile = Path(bitfile).resolve()
    validate_reset_wiring(bitfile)
    manifest_path = bitfile.parent / "release_manifest.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    for path in (bitfile, bitfile.with_suffix(".hwh")):
        actual = hashlib.sha256(path.read_bytes()).hexdigest()
        if manifest["sha256"].get(path.name) != actual:
            raise RuntimeError("Release hash mismatch for {}. Upload the complete matching release.".format(path.name))
    modules = {m.get("FULLNAME"): m for m in ET.parse(str(bitfile.with_suffix(".hwh"))).findall(".//MODULE")}
    ps = modules["/processing_system7_0"]
    ps_params = {p.get("NAME"): p.get("VALUE") for p in ps.findall("./PARAMETERS/PARAMETER")}
    if (float(ps_params["PCW_ACT_FPGA0_PERIPHERAL_FREQMHZ"]) != 25.0 or
            int(ps_params["PCW_EN_CLK0_PORT"]) != 1 or
            int(ps_params["PCW_USE_M_AXI_GP0"]) != 1 or int(ps_params["PCW_USE_S_AXI_HP0"]) != 1):
        raise RuntimeError("Unexpected PS clock or GP0/HP0 configuration")
    clock_net = ps.find("./PORTS/PORT[@NAME='FCLK_CLK0']").get("SIGNAME")
    clock_ports = {
        "/processing_system7_0": ("M_AXI_GP0_ACLK", "S_AXI_HP0_ACLK"),
        "/sha3/sha3_dma": ("s_axi_lite_aclk", "m_axi_mm2s_aclk", "m_axi_s2mm_aclk"),
        "/sha3/sha3_ip": ("axis_aclk",),
        "/rst_ps7_0_25M": ("slowest_sync_clk",),
        "/axi_control": ("ACLK", "S00_ACLK", "M00_ACLK"),
        "/axi_memory": ("ACLK", "S00_ACLK", "S01_ACLK", "M00_ACLK"),
    }
    for name, ports in clock_ports.items():
        for port in ports:
            pin = modules[name].find("./PORTS/PORT[@NAME='{}']".format(port))
            if pin is None or pin.get("SIGNAME") != clock_net:
                raise RuntimeError("Unexpected clock connection {} {}".format(name, port))
    reset = modules["/rst_ps7_0_25M"]
    reset_params = {p.get("NAME"): p.get("VALUE") for p in reset.findall("./PARAMETERS/PARAMETER")}
    if int(reset_params["C_EXT_RESET_HIGH"]) != 0:
        raise RuntimeError("External reset must match active-low PS FCLK_RESET0_N")
    ext_net = reset.find("./PORTS/PORT[@NAME='ext_reset_in']").get("SIGNAME")
    if ext_net != ps.find("./PORTS/PORT[@NAME='FCLK_RESET0_N']").get("SIGNAME"):
        raise RuntimeError("External reset is not connected to the PS reset")
    for pin_name, value in (("dcm_locked", 1), ("mb_debug_sys_rst", 0)):
        signal = reset.find("./PORTS/PORT[@NAME='{}']".format(pin_name)).get("SIGNAME")
        drivers = [m for m in modules.values()
                   if m.get("VLNV", "").startswith("xilinx.com:ip:xlconstant:")
                   and any(p.get("DIR") == "O" and p.get("SIGNAME") == signal
                           for p in m.findall("./PORTS/PORT"))]
        if len(drivers) != 1:
            raise RuntimeError("Unexpected reset source for {}".format(pin_name))
        constant = drivers[0].find("./PARAMETERS/PARAMETER[@NAME='CONST_VAL']")
        if int(constant.get("VALUE"), 0) != value:
            raise RuntimeError("Incorrect constant on {}".format(pin_name))
    peripheral_net = reset.find("./PORTS/PORT[@NAME='peripheral_aresetn']").get("SIGNAME")
    interconnect_net = reset.find("./PORTS/PORT[@NAME='interconnect_aresetn']").get("SIGNAME")
    reset_ports = {
        "/sha3/sha3_dma": (("axi_resetn",), peripheral_net),
        "/sha3/sha3_ip": (("axis_aresetn",), peripheral_net),
        "/axi_control": (("ARESETN", "S00_ARESETN", "M00_ARESETN"), interconnect_net),
        "/axi_memory": (("ARESETN", "S00_ARESETN", "S01_ARESETN", "M00_ARESETN"), interconnect_net),
    }
    for name, (ports, expected) in reset_ports.items():
        for port in ports:
            pin = modules[name].find("./PORTS/PORT[@NAME='{}']".format(port))
            if pin is None or pin.get("SIGNAME") != expected:
                raise RuntimeError("Unexpected reset connection {} {}".format(name, port))
    bus_pairs = (
        ("/sha3/sha3_dma", "M_AXIS_MM2S", "/sha3/sha3_ip", "S_AXIS"),
        ("/sha3/sha3_ip", "M_AXIS", "/sha3/sha3_dma", "S_AXIS_S2MM"),
        ("/processing_system7_0", "M_AXI_GP0", "/axi_control", "S00_AXI"),
        ("/axi_control", "M00_AXI", "/sha3/sha3_dma", "S_AXI_LITE"),
        ("/sha3/sha3_dma", "M_AXI_MM2S", "/axi_memory", "S00_AXI"),
        ("/sha3/sha3_dma", "M_AXI_S2MM", "/axi_memory", "S01_AXI"),
        ("/axi_memory", "M00_AXI", "/processing_system7_0", "S_AXI_HP0"),
    )
    for first, first_port, second, second_port in bus_pairs:
        a = modules[first].find("./BUSINTERFACES/BUSINTERFACE[@NAME='{}']".format(first_port))
        b = modules[second].find("./BUSINTERFACES/BUSINTERFACE[@NAME='{}']".format(second_port))
        if a is None or b is None or a.get("BUSNAME") in (None, "__NOC__") or a.get("BUSNAME") != b.get("BUSNAME"):
            raise RuntimeError("AXI connection mismatch {} to {}".format(first_port, second_port))
    dma_params = {p.get("NAME"): p.get("VALUE") for p in modules["/sha3/sha3_dma"].findall("./PARAMETERS/PARAMETER")}
    expected_params = {"c_include_sg": 0, "c_addr_width": 32,
                       "c_include_mm2s": 1, "c_include_s2mm": 1,
                       "c_m_axis_mm2s_tdata_width": 32, "c_s_axis_s2mm_tdata_width": 32}
    if any(int(dma_params[name]) != value for name, value in expected_params.items()):
        raise RuntimeError("Unexpected simple-mode DMA parameters")
    address = ps.find(".//MEMRANGE[@INSTANCE='sha3_sha3_dma'][@SLAVEBUSINTERFACE='S_AXI_LITE']")
    if address is None or int(address.get("BASEVALUE"), 0) != 0x40400000:
        raise RuntimeError("Unexpected DMA control address mapping")
    return {"build_id": manifest["build_id"], "clock_mhz": 25, "dma_base": "0x40400000", "reset": "inactive"}


def encode_message(message):
    """Return little-endian 32-bit words, including headers and fixed-size tails."""
    message = bytes(message)
    if len(message) > MAX_MESSAGE_BYTES:
        raise ValueError("The bring-up driver accepts at most 1 MiB per message")
    blocks = [message[i:i + RATE_BYTES] for i in range(0, len(message), RATE_BYTES)] or [b""]
    words = []
    for index, block in enumerate(blocks):
        final = index == len(blocks) - 1
        words.append(len(block) | (int(final) << 8))
        padded = block.ljust(RATE_BYTES, b"\x00")
        words.extend(int.from_bytes(padded[i:i + 4], "little") for i in range(0, RATE_BYTES, 4))
    return words


def decode_reply(words):
    if len(words) != REPLY_WORDS:
        raise RuntimeError("Expected one status word and eight digest words")
    if int(words[0]) != SUCCESS:
        raise RuntimeError("SHA-3 hardware status 0x{:08x}".format(int(words[0])))
    return b"".join(int(word).to_bytes(4, "little") for word in words[1:])


def validation_messages():
    yield "empty", b""
    yield "abc", b"abc"
    for length in (1, 3, 4, 7, 31, 32, 64, 135, 136, 137, 271, 272, 273, 1000, 4096):
        yield "pattern_{}".format(length), bytes((i * 29 + 7) % 256 for i in range(length))


class Sha3Session:
    """Keep buffers alive across a failed DMA operation until hardware reset."""

    def __init__(self, bitfile):
        self.bitfile = str(Path(bitfile).resolve())
        self.tx = None
        self.rx = None
        self.in_flight = False
        self._load_overlay()

    def _load_overlay(self):
        validate_artifacts(self.bitfile)
        from pynq import Clocks, MMIO, Overlay

        print("1/4 release hashes and hardware wiring checked", flush=True)
        self.overlay = Overlay(self.bitfile, download=False)
        print("2/4 HWH parsed; downloading overlay", flush=True)
        self.overlay.download()
        clock_mhz = float(Clocks.fclk0_mhz)
        if abs(clock_mhz - 25.0) > 0.1:
            raise RuntimeError("PS reports FCLK0={} MHz; expected 25 MHz".format(clock_mhz))
        print("3/4 overlay downloaded; FCLK0={:.3f} MHz; checking DMA startup".format(clock_mhz), flush=True)
        description = self.overlay.ip_dict["sha3/sha3_dma"]
        self._mmio = MMIO(description["phys_addr"], description["addr_range"])
        self._mmio.write(0x00, 1)
        self._mmio.write(0x30, 1)
        self._wait_halted(False, 5.0)
        self.dma = self.overlay.sha3.sha3_dma
        print("4/4 DMA channels started", flush=True)

    def _wait_halted(self, halted, timeout):
        deadline = time.monotonic() + timeout
        while True:
            tx_status = self._mmio.read(0x04)
            rx_status = self._mmio.read(0x34)
            if not halted and (tx_status | rx_status) & 0x70:
                raise RuntimeError("DMA startup error TX=0x{:x} RX=0x{:x}".format(tx_status, rx_status))
            if bool(tx_status & 1) == halted and bool(rx_status & 1) == halted:
                return
            if time.monotonic() >= deadline:
                raise TimeoutError("DMA {} timeout TX=0x{:x} RX=0x{:x}; board recovery may be required".format(
                    "stop" if halted else "start", tx_status, rx_status))
            time.sleep(0.001)

    def hash(self, message, timeout=5.0):
        import numpy as np
        from pynq import allocate

        words = encode_message(message)
        if self.in_flight:
            raise RuntimeError("Reset this session after the failed transfer")
        self.close()
        # Store both buffers on the session before starting hardware.
        self.tx = allocate(shape=(len(words),), dtype=np.uint32)
        self.rx = allocate(shape=(REPLY_WORDS,), dtype=np.uint32)
        self.tx[:] = words
        self.rx[:] = 0
        self.rx.flush()
        self.in_flight = True
        self.dma.recvchannel.transfer(self.rx)
        self.dma.sendchannel.transfer(self.tx)
        deadline = time.monotonic() + timeout
        while True:
            tx_status = self.dma.mmio.read(0x04)
            rx_status = self.dma.mmio.read(0x34)
            if (tx_status | rx_status) & 0x71:
                raise RuntimeError("DMA halted/error TX=0x{:x} RX=0x{:x}".format(tx_status, rx_status))
            if tx_status & rx_status & 2:
                break
            if time.monotonic() >= deadline:
                raise TimeoutError("DMA timeout TX=0x{:x} RX=0x{:x}".format(tx_status, rx_status))
            time.sleep(0.001)
        self.dma.sendchannel.wait()
        self.dma.recvchannel.wait()
        self.in_flight = False
        if self.dma.mmio.read(0x58) != REPLY_WORDS * 4:
            raise RuntimeError("DMA received an incomplete SHA-3 reply")
        return decode_reply(self.rx)

    def reset(self):
        validate_artifacts(self.bitfile)
        # Complete outstanding AXI transactions before reconfiguring the PL.
        # A stop timeout leaves buffers mapped and propagates to the caller.
        self._mmio.write(0x00, 0)
        self._mmio.write(0x30, 0)
        self._wait_halted(True, 5.0)
        self.in_flight = False
        self.close()
        self._load_overlay()

    def close(self):
        if self.in_flight:
            raise RuntimeError("Call reset() before releasing a failed transfer's buffers")
        for name in ("tx", "rx"):
            buffer = getattr(self, name)
            if buffer is not None:
                buffer.freebuffer()
                setattr(self, name, None)


def self_test(session, rounds=2):
    count = 0
    for round_index in range(rounds):
        for name, message in validation_messages():
            actual = session.hash(message)
            expected = hashlib.sha3_256(message).digest()
            if actual != expected:
                raise AssertionError("{} round {} expected {} got {}".format(
                    name, round_index, expected.hex(), actual.hex()))
            print("PASS round={} case={} bytes={}".format(round_index, name, len(message)))
            count += 1
    print("SUCCESS {} FPGA SHA3-256 comparisons".format(count))
    return count
