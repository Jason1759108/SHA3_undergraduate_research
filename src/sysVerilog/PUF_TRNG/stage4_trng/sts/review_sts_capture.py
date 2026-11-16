"""Verify pilot evidence without executing the attached notebook; optionally run STS."""
import argparse,hashlib,json,zipfile
from pathlib import Path
from run_sts import run
ROOT=Path(__file__).resolve().parent
HEALTH={"status":194,"count":1024,"ro_enable":0,"fault_mask":0,"rct_mask":0,"apt_mask":0,"observed":2048,"startup_seen":1024}


def review(archive,output_folder,execute_sts=True):
    expected=json.loads((ROOT.parent/'build/overlay/release_manifest.json').read_text())
    addon=json.loads((ROOT/'python/sts_addon_manifest.json').read_text())
    with zipfile.ZipFile(archive) as z:
        names=z.namelist()
        required={'summary.json','raw_batches.bin','digests_all.bin','batches.jsonl','sha3_output_1000000bits.bin','release_manifest.json','sts_addon_manifest.json'}
        if set(names)!=required or len(names)!=7 or sum(x.file_size for x in z.infolist())>16*1024*1024:
            raise RuntimeError('Wrong pilot ZIP or oversized data')
        summary=json.loads(z.read('summary.json'))
        if json.loads(z.read('release_manifest.json'))!=expected or json.loads(z.read('sts_addon_manifest.json'))!=addon:
            raise RuntimeError('Different base release or collector')
        if summary['status']!='PASS_COLLECTION' or summary['completed_batches']!=3907 or summary['requested_batches']!=3907:
            raise RuntimeError('Incomplete/failed pilot; retain error evidence')
        if summary['sequence_bits']!=1000000 or summary['sequences']!=1 or summary['divider']!=512 or summary['unused_tail_bits']!=192:
            raise RuntimeError('Wrong pilot configuration')
        if summary['build_id']!=expected['build_id'] or summary['final_health']!=HEALTH or summary['health_faults']!=0:
            raise RuntimeError('Wrong build/final health')
        for name,record in summary['files'].items():
            data=z.read(name)
            if len(data)!=record['bytes'] or hashlib.sha256(data).hexdigest()!=record['sha256']:
                raise RuntimeError('ZIP data mismatch: '+name)
        raw=z.read('raw_batches.bin');digests=z.read('digests_all.bin');tested=z.read('sha3_output_1000000bits.bin')
        records=z.read('batches.jsonl').splitlines()
        if len(raw)!=3907*1024 or len(digests)!=3907*32 or len(records)!=3907 or len(tested)!=125000 or tested!=digests[:125000]:
            raise RuntimeError('Invalid length or changed/truncated stream')
        for index,line in enumerate(records):
            item=json.loads(line);batch=raw[index*1024:(index+1)*1024];digest=digests[index*32:(index+1)*32]
            if item['index']!=index or item['raw_offset']!=index*1024 or item['digest_offset']!=index*32 or item['health']!=HEALTH or item['build_id']!=expected['build_id']:
                raise RuntimeError('Batch metadata mismatch')
            if hashlib.sha256(batch).hexdigest()!=item['raw_sha256'] or hashlib.sha3_256(batch).digest()!=digest or digest.hex()!=item['digest_hex']:
                raise RuntimeError('Raw/hardware-digest mismatch at '+str(index))
    out=Path(output_folder);out.mkdir(parents=True,exist_ok=False)
    (out/'sha3_output_1000000bits.bin').write_bytes(tested)
    result={'status':'PASS_PILOT_EVIDENCE','batches':3907,'fpga_digests_recomputed':3907,'tested_bits':1000000,
            'board_id':summary['board_id'],'experiment_date':summary['experiment_date'],'build_id':summary['build_id'],
            'archive_sha256':hashlib.sha256(Path(archive).read_bytes()).hexdigest(),'entropy_certified':False}
    (out/'integrity_review.json').write_text(json.dumps(result,indent=2)+'\n')
    if execute_sts:result['sts']=run(out/'sha3_output_1000000bits.bin',out/'nist_sts')
    return result


if __name__=='__main__':
    ap=argparse.ArgumentParser();ap.add_argument('archive');ap.add_argument('output');a=ap.parse_args()
    result=review(a.archive,a.output)
    print(json.dumps({k:v for k,v in result.items() if k!='sts'},indent=2))
    print('STS single-sequence results saved; no certification or multi-sequence pass claim')
