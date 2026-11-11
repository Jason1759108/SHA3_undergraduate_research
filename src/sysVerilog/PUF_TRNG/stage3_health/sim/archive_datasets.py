"""Restore only the verified dataset exports from the retained raw capture ZIP."""
import hashlib
import json
import zipfile
from pathlib import Path, PurePosixPath

ROOT = Path(__file__).resolve().parents[1]
CAPTURE = ROOT / 'captures/board_21600/health_20261111'
ARCHIVE = CAPTURE / 'entropy_health_2026-11-11_20261110T192024Z_c6d5135c.zip'
PREFIX = 'health_assessment/2026-11-11_20261110T192028Z_7e1391ad/datasets/'


def dataset_folder():
    """The ZIP remains the canonical evidence; extracted files are disposable."""
    output = ROOT / 'build/analysis_input/health_20261111/datasets'
    with zipfile.ZipFile(ARCHIVE) as z:
        manifest_bytes = z.read(PREFIX + 'dataset_manifest.json')
        manifest = json.loads(manifest_bytes)
        expected = {'raw_joint_concat.bin', 'restart_joint_rows.bin'}
        expected.update('channel_{}_concat.bin'.format(k) for k in range(8))
        if set(manifest['files']) != expected:
            raise ValueError('Unexpected dataset export set')
        verified = {}
        for name, record in manifest['files'].items():
            if PurePosixPath(name).name != name or '\\' in name or ':' in name:
                raise ValueError('Unexpected archive path')
            data = z.read(PREFIX + name)
            if len(data) != record['bytes'] or hashlib.sha256(data).hexdigest() != record['sha256']:
                raise ValueError('Dataset checksum mismatch: ' + name)
            verified[name] = data
    output.mkdir(parents=True, exist_ok=True)
    for name, data in verified.items():
        target = output / name
        if not target.exists() or target.read_bytes() != data:
            target.write_bytes(data)
    (output / 'dataset_manifest.json').write_bytes(manifest_bytes)
    return output
