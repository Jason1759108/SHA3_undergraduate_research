"""Create a focused, lossless subset of the AXI/measurement VCD signals."""
from pathlib import Path


def compact(source, target):
    scopes = []
    header = []
    keep = set()
    accepted = {'TESTBED_PUF_AXI_RO', 'TESTBED_PUF_AXI_RO.dut', 'TESTBED_PUF_AXI_RO.dut.u_measure', 'TESTBED_PUF_AXI_RO.pattern', 'TESTBED_PUF_AXI_RO.dut.u_device', 'TESTBED_PUF_AXI_RO.dut.u_device.sampler', 'TESTBED_PUF_AXI_RO.dut.u_device.sketch'}
    with Path(source).open('r', encoding='ascii') as src:
        for line in src:
            fields = line.split()
            if fields and fields[0] == '$scope':
                scopes.append(fields[2])
            elif fields and fields[0] == '$upscope':
                scopes.pop()
            if fields and fields[0] == '$var':
                name = fields[4]
                if '.'.join(scopes) in accepted and name != 'ro_clocks' and not name.startswith(('source_gray[', 'gray_meta[', 'gray_sync[')):
                    keep.add(fields[3])
            header.append(line)
            if fields and fields[0] == '$enddefinitions':
                break
        with Path(target).open('w', encoding='ascii', newline='\n') as dst:
            for line in header:
                fields = line.split()
                if not fields or fields[0] != '$var' or fields[3] in keep:
                    dst.write(line)
            timestamp = None
            for line in src:
                if line.startswith('#'):
                    timestamp = line
                elif line[:1] in ('0', '1', 'x', 'X', 'z', 'Z', 'b', 'B', 'r', 'R'):
                    symbol = line.rstrip().split()[-1] if line[:1] in ('b', 'B', 'r', 'R') else line[1:].strip()
                    if symbol in keep:
                        if timestamp is not None:
                            dst.write(timestamp)
                            timestamp = None
                        dst.write(line)
                elif line.startswith('$'):
                    dst.write(line)
    return len(keep)


if __name__ == '__main__':
    import argparse
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('source', type=Path)
    p.add_argument('target', type=Path)
    a = p.parse_args()
    print('Retained {} signal identifiers'.format(compact(a.source, a.target)))
