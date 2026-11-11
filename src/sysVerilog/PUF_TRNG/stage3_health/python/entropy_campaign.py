"""Bounded batch acquisition and auditable dataset export; no entropy claim."""
import hashlib
import json
import uuid
from datetime import datetime, timezone
from pathlib import Path
from entropy_characterize import collect


def _sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _write(path, value):
    tmp = path.with_suffix('.tmp')
    tmp.write_text(json.dumps(value, indent=2) + '\n', encoding='utf-8')
    tmp.replace(path)


def _child(folder, name):
    path = Path(name)
    if path.is_absolute() or '..' in path.parts or '\\' in name or ':' in name:
        raise ValueError('Unexpected relative data path')
    resolved = (folder / path).resolve()
    resolved.relative_to(folder.resolve())
    return resolved


def collect_campaign(session, board_id, experiment_date,
                     output_root='entropy_assessment', target_batches=1000):
    """Use divider 512 provisionally; each acquisition stays at 1024 samples."""
    if not isinstance(board_id, str) or not board_id.strip():
        raise ValueError('Record the actual board ID')
    datetime.strptime(experiment_date, '%Y-%m-%d')
    if type(target_batches) is not int or not 1 <= target_batches <= 1000:
        raise ValueError('target_batches must be 1..1000')
    run_id = datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ') + '_' + uuid.uuid4().hex[:8]
    folder = Path(output_root) / (experiment_date + '_' + run_id)
    folder.mkdir(parents=True, exist_ok=False)
    manifest = {
        'schema': 1, 'board_id': board_id, 'experiment_date': experiment_date,
        'board_system_utc_unverified': datetime.now(timezone.utc).isoformat(),
        'build_id': session.release['build_id'], 'divider': 512,
        'target_batches': target_batches, 'completed_batches': 0,
        'samples_per_batch': 1024, 'segments': [], 'status': 'running',
        'ro_off_confirmed': False, 'physical_entropy_certified': False,
        'helper_sha256': _sha(Path(__file__)),
        'acquisition': 'RO startup-test 1024 then payload 1024, stops/restarts per batch; NOT continuous',
        'purpose': 'Provisional raw-data assessment; restart definition/model still requires review'
    }
    mp = folder / 'campaign_manifest.json'
    _write(mp, manifest)
    print('Campaign folder:', str(folder), flush=True)
    try:
        while manifest['completed_batches'] < target_batches:
            count = min(16, target_batches - manifest['completed_batches'])
            run = collect(session, board_id, experiment_date,
                          output_root=str(folder / 'segments'), dividers=(512,), rounds=count)
            segment_folder = Path(run['folder'])
            manifest['segments'].append({
                'folder': segment_folder.relative_to(folder).as_posix(),
                'manifest_sha256': _sha(segment_folder / 'run_manifest.json'),
                'batches': run['batches'], 'status': run['status']
            })
            manifest['completed_batches'] += run['batches']
            _write(mp, manifest)
            print('CAMPAIGN {}/{} batches saved; RO OFF={}'.format(
                manifest['completed_batches'], target_batches, run['ro_off_confirmed']), flush=True)
            if run['status'] != 'complete' or not run['ro_off_confirmed']:
                manifest['status'] = 'stopped_on_fault'
                break
        else:
            manifest['status'] = 'complete'
    except BaseException as exc:
        manifest['status'] = 'interrupted' if isinstance(exc, KeyboardInterrupt) else 'error'
        manifest['reason'] = repr(exc)
        if hasattr(exc, 'snapshot'):manifest['fault_snapshot'] = exc.snapshot
        # A segment interrupted inside collect remains on disk even if not yet indexed.
        manifest['note'] = 'Preserve entire folder, including any unindexed interrupted segment'
        raise
    finally:
        try:
            session.close()
            manifest['ro_off_confirmed'] = True
        except BaseException as exc:
            manifest['cleanup_error'] = repr(exc)
            if manifest['status'] == 'complete':
                manifest['status'] = 'cleanup_failed'
        _write(mp, manifest)
    return {'folder': str(folder), 'status': manifest['status'],
            'batches': manifest['completed_batches'],
            'ro_off_confirmed': manifest['ro_off_confirmed']}


def export_datasets(folder):
    """Preserve joint symbols; also export individual channels, never sum their entropy."""
    folder = Path(folder).resolve()
    campaign = json.loads((folder / 'campaign_manifest.json').read_text(encoding='utf-8'))
    if campaign['status'] != 'complete' or not campaign['ro_off_confirmed']:
        raise ValueError('Only export completed campaigns with RO OFF; preserve partial raw files')
    joint = bytearray()
    restart = bytearray()
    sources = []
    for entry in campaign['segments']:
        segment = _child(folder, entry['folder'])
        mp = segment / 'run_manifest.json'
        if _sha(mp) != entry['manifest_sha256']:
            raise ValueError('Segment manifest changed')
        m = json.loads(mp.read_text(encoding='utf-8'))
        if (m['status'] != 'complete' or not m['ro_off_confirmed'] or
                m['board_id'] != campaign['board_id'] or m['build_id'] != campaign['build_id'] or
                m['dividers'] != [512] or len(m['batches']) != entry['batches']):
            raise ValueError('Segment settings/state mismatch')
        if 'release_manifest_sha256' in m:
            if _sha(segment / 'release_manifest.json') != m['release_manifest_sha256']:
                raise ValueError('Release snapshot changed')
        for batch in m['batches']:
            raw_path = _child(segment, batch['bin'])
            meta = json.loads(_child(segment, batch['json']).read_text(encoding='utf-8'))
            raw = raw_path.read_bytes()
            digest = hashlib.sha256(raw).hexdigest()
            if (len(raw) != 1024 or batch['count'] != 1024 or meta['count'] != 1024 or
                    digest != batch['sha256'] or digest != meta['sha256'] or
                    batch['status'] != 194 or meta['status'] != 194 or meta['alarm'] or
                    meta['fault_mask'] != 0 or not batch['ro_off'] or
                    batch['divider'] != 512 or meta['divider'] != 512 or
                    meta['board_id'] != campaign['board_id'] or meta['build_id'] != campaign['build_id'] or
                    meta.get('health') != {'status':194,'count':1024,'ro_enable':0,'fault_mask':0,'rct_mask':0,'apt_mask':0,'observed':2048,'startup_seen':1024}):
                raise ValueError('Invalid/mismatched capture: ' + str(raw_path))
            sources.append({'bin': raw_path.relative_to(folder).as_posix(), 'sha256': digest,
                            'samples': 1024, 'concat_offset': len(joint),
                            'restart_offset': len(restart)})
            joint.extend(raw)
            restart.extend(raw[:1000])
    if len(sources) != campaign['target_batches'] or len(sources) != campaign['completed_batches']:
        raise ValueError('Batch total mismatch')
    output = folder / 'datasets'
    output.mkdir(exist_ok=True)
    files = {}
    data = {'raw_joint_concat.bin': joint, 'restart_joint_rows.bin': restart}
    for ch in range(8):
        data['channel_{}_concat.bin'.format(ch)] = bytes((b >> ch) & 1 for b in joint)
    for name, raw in data.items():
        path = output / name
        path.write_bytes(raw)
        files[name] = {'bytes': len(raw), 'sha256': _sha(path)}
    result = {'schema': 1, 'integrity': 'PASS', 'board_id': campaign['board_id'],
              'build_id': campaign['build_id'], 'divider': 512,
              'batches': len(sources), 'total_samples': len(joint),
              'restart_rows': len(sources), 'restart_columns': 1000,
              'files': files, 'sources': sources,
              'joint_format': 'one byte per time point; bits 0..7 = simultaneous RO channels',
              'channel_format': 'one byte per sample, value 0 or 1; NOT packed bits',
              'restart_format': 'row-major; first 1000 PAYLOAD samples after 1024 startup health samples per RO restart',
              'continuous': False, 'entropy_estimate': None, 'physical_entropy_certified': False,
              'limitations': 'No entropy estimate/certification. RO batch restart is not board power cycling. '
                             'Do not sum channel entropy. Preserve all batch boundaries and source records.'}
    _write(output / 'dataset_manifest.json', result)
    return {k: v for k, v in result.items() if k not in ('sources', 'files')}
