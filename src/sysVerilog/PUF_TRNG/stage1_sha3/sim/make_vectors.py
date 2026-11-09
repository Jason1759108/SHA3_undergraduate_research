"""Generate AXI vectors and expected replies using Python's SHA3-256."""
import hashlib
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "python"))
from sha3_pynq import encode_message, validation_messages


def main():
    vectors = ROOT / "sim" / "vectors"
    vectors.mkdir(exist_ok=True)
    tx, rx, cases = [], [], []
    for _ in range(2):
        for name, message in validation_messages():
            words = encode_message(message)
            cases.append((len(tx), len(words)))
            tx.extend(words)
            digest = hashlib.sha3_256(message).digest()
            rx.extend([0x53480000] + [int.from_bytes(digest[i:i+4], "little") for i in range(0, 32, 4)])
    (vectors / "tx.hex").write_text("".join("{:08x}\n".format(w) for w in tx), encoding="ascii")
    (vectors / "rx.hex").write_text("".join("{:08x}\n".format(w) for w in rx), encoding="ascii")
    (vectors / "cases.hex").write_text("".join("{:08x}{:08x}\n".format(a, b) for a, b in cases), encoding="ascii")
    (vectors / "sizes.svh").write_text(
        "localparam integer CASES = {};\nlocalparam integer TX_WORDS = {};\n".format(len(cases), len(tx)), encoding="ascii")
    print("Generated {} cases, {} input words".format(len(cases), len(tx)))


if __name__ == "__main__":
    main()
