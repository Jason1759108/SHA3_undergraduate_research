"""Reconstruct using an existing enrollment. Never enroll or choose new pairs."""
import argparse
import json
from pathlib import Path
from puf256 import Puf256
from board_validation import sha256


def main():
    from pynq import Overlay, Clocks
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--enrollment',type=Path,required=True)
    parser.add_argument('--bitfile',type=Path,default=Path('puf256.bit'))
    args=parser.parse_args()
    saved=json.loads(args.enrollment.read_text(encoding='utf-8'))
    for path,key in [(args.bitfile,'bitstream_sha256'),(args.bitfile.with_suffix('.hwh'),'hwh_sha256')]:
        if sha256(path)!=saved[key]:raise RuntimeError('Enrollment does not match overlay: '+str(path))
    overlay=Overlay(str(args.bitfile.resolve()),download=True)
    if abs(float(Clocks.fclk0_mhz)-100.0)>.1:raise RuntimeError('FCLK0 must be 100 MHz')
    device=Puf256(overlay.puf256_0)
    result=device.reconstruct(int(saved['bitmap_hex'],16),int(saved['helper_hex'],16),
                              window_cycles=saved['window_cycles'],warmup_cycles=saved['warmup_cycles'])
    print(json.dumps(dict(ok=result['ok'],status=result['status_name'],
          puf_data_hex=format(result['key'],'064x') if result['ok'] else None,
          corrected_words=result['corrected_words']),indent=2))
    if not result['ok']:raise SystemExit(1)


if __name__=='__main__':main()
