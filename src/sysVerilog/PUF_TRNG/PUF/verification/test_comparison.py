"""Synthetic protocol fixtures; never presented as hardware measurements."""
import csv
import hashlib
import json
from pathlib import Path
import shutil
import tempfile
import unittest
from unittest.mock import patch
from fractions import Fraction
import compare_boards as c


class ComparisonTests(unittest.TestCase):
    def setUp(self):
        self.root=Path(tempfile.mkdtemp(prefix='puf_two_board_test_')).resolve()
        self.root.relative_to(Path(tempfile.gettempdir()).resolve())
        self.addCleanup(shutil.rmtree,self.root)
        self.plan=self.root/'common_bitmap.json'
        c.write(self.plan,dict(complete=True,selected_pairs=list(range(256)),bitmap_hex=format((1<<256)-1,'080x'),
                              bitstream_sha256='synthetic',hwh_sha256='synthetic',window_cycles=100000,warmup_cycles=1024))

    def make_board(self,label,key):
        folder=self.root/label;folder.mkdir()
        ref=self.root/('reference_'+label+'.json')
        c.write(ref,dict(board_label=label,plan_sha256=c.digest(self.plan),expected_candidate_hex=format(key,'064x')))
        p=c.read(self.plan)
        env=dict(board_label=label,plan_sha256=c.digest(self.plan),reference_sha256=c.digest(ref),
                 linux_boot_id='synthetic-boot-'+label,holdout_reads=2,reconstruction_runs=2,reload_runs=2,
                 **{k:p[k] for k in ['bitstream_sha256','hwh_sha256','bitmap_hex','window_cycles','warmup_cycles']})
        c.write(folder/'environment.json',env)
        registers=dict(bitmap=0,helper_input=0,key_data=0,helper_output=0,puf_sequence=0,raw_sequence=0,helper_input_valid=0)
        c.write(folder/'overlay_loads.json',[dict(index=i,fclk0_mhz=100.0,initial_volatile_registers=registers) for i in range(3)])
        with (folder/'holdout.csv').open('w',newline='') as f:
            writer=csv.DictWriter(f,fieldnames=['read','pair','sequence','status','count_a','count_b','delta','bit','window_cycles','warmup_cycles']);writer.writeheader()
            for n in range(2):
                for j in range(256):
                    bit=(key>>j)&1;a=5100 if bit else 5000;b=5000 if bit else 5100
                    writer.writerow(dict(read=n,pair=j,sequence=n*256+j+1,status=0,count_a=a,count_b=b,delta=a-b,bit=bit,window_cycles=100000,warmup_cycles=1024))
        c.write(folder/'holdout_verdict.json',dict(passed=True,failures=[],rows=512,min_abs_margin=100))
        helper=0
        for w in range(16):
            value=0
            for b in range(16):
                if key>>(16*w+b)&1:value^=16|(b+1 if b<15 else 0)
            helper|=value<<(5*w)
        digest=hashlib.sha256(key.to_bytes(32,'little')).hexdigest()
        c.write(folder/'registration.json',dict(candidate_hex=format(key,'064x'),helper_hex=format(helper,'020x')))
        c.write(folder/'enrollment.json',dict(bitmap_hex=p['bitmap_hex'],helper_hex=format(helper,'020x'),bitstream_sha256='synthetic',plan_sha256=c.digest(self.plan)))
        stages=[('registration',0),('repeat',0),('repeat',1),('abort-reset',0),('same-bitstream-reload',0),('same-bitstream-reload',1)]
        trials=[];seq=0
        for stage,n in stages:
            if stage=='same-bitstream-reload':seq=0
            seq+=1;trials.append(dict(stage=stage,index=n,status=0,match=True,key_sha256=digest,sequence=seq,corrected_words=0))
        c.write(folder/'reconstructions.json',trials)
        c.write(folder/'summary.json',dict(passed=True,candidate_hex=format(key,'064x'),key_sha256=digest,plan_sha256=c.digest(self.plan),holdout_samples=512,reconstruction_count=5,reload_count=2,corrected_words=0))
        return folder

    def test_distinct_and_equal_identities(self):
        a=self.make_board('20100',0);b=self.make_board('20200',(1<<128)-1)
        result=c.compare(a,b,self.plan,self.root)
        self.assertTrue(result['identities_differ']);self.assertEqual(result['hamming_distance_bits'],128)
        self.assertEqual(result['hamming_distance_percent'],50)

    def test_reject_changed_trial(self):
        a=self.make_board('20100',1);b=self.make_board('20200',3)
        trials=c.read(b/'reconstructions.json');trials[2]['key_sha256']='bad';c.write(b/'reconstructions.json',trials)
        with self.assertRaises(ValueError):c.compare(a,b,self.plan,self.root)

    def test_reject_same_running_kernel(self):
        a=self.make_board('20100',1);b=self.make_board('20200',3)
        env=c.read(b/'environment.json');env['linux_boot_id']='synthetic-boot-20100';c.write(b/'environment.json',env)
        with self.assertRaises(ValueError):c.compare(a,b,self.plan,self.root)

    def test_characterization_never_counts_rejection_as_success(self):
        a=self.make_board('20100',1);b=self.make_board('20200',3)
        trials=c.read(b/'reconstructions.json');trials[2].update(status=4,match=False,key_sha256=None)
        c.write(b/'reconstructions.json',trials);c.write(b/'strict_prefix_reconstructions.json',trials[:3])
        c.write(b/'continuation.json',dict(strict_prefix_sha256=c.digest(b/'strict_prefix_reconstructions.json'),
                module_sha256=c.digest(Path(__file__).resolve().parents[1]/'software/characterize_common.py')))
        summary=c.read(b/'summary.json');summary.update(passed=False,completed=True,strict_pass=False,all_accepted_keys_match=True,rejected_reconstructions=1,successful_reconstructions=4)
        c.write(b/'summary.json',summary)
        with self.assertRaises(ValueError):c.compare(a,b,self.plan,self.root)
        result=c.compare(a,b,self.plan,self.root,allow_rejections=True)
        self.assertTrue(result['comparison_verified']);self.assertTrue(result['identities_differ'])
        self.assertFalse(result['passed']);self.assertFalse(result['all_transactions_successful'])
        self.assertFalse(result['board_20200']['passed']);self.assertTrue(result['board_20200']['records_verified'])
        self.assertEqual(result['board_20200']['rejected_reconstructions'],1)

    def test_no_false_difference_when_equal(self):
        a=self.make_board('20100',7);b=self.make_board('20200',7)
        result=c.compare(a,b,self.plan,self.root)
        self.assertFalse(result['identities_differ']);self.assertEqual(result['hamming_distance_bits'],0)

    def test_joint_selection_ignores_polarity(self):
        for role in ['inputA','inputB']:
            (self.root/role).mkdir()
            for name in ['environment.json','reference.csv','training.csv','selection.json']:(self.root/role/name).write_text('{}')
        env=dict(bitstream_sha256='synthetic',hwh_sha256='synthetic',window_cycles=100000,warmup_cycles=1024)
        base=dict(environment=env,reference=[0]*320,eligible=set(range(1,320)),gap=[Fraction(p+10,1000) for p in range(320)],margin=list(range(10,330)),original_bitmap=(1<<256)-1)
        other=dict(base);other['reference']=[1]*320
        with patch.object(c,'training',side_effect=[base,other]):p=c.freeze(self.root/'inputA',self.root/'inputB',self.root/'frozen1')
        with patch.object(c,'training',side_effect=[other,base]):q=c.freeze(self.root/'inputA',self.root/'inputB',self.root/'frozen2')
        self.assertFalse(p['reused_original_20100_bitmap']);self.assertEqual(p['selected_pairs'],list(range(64,320)))
        self.assertEqual(p['selected_pairs'],q['selected_pairs'])
        small=dict(base);small['eligible']=set(range(255))
        with patch.object(c,'training',side_effect=[small,small]):r=c.freeze(self.root/'inputA',self.root/'inputB',self.root/'too_few')
        self.assertFalse(r['complete'])


if __name__=='__main__':unittest.main()
