"""Host protocol and selection invariants, independent of oscillator timing."""
import sys
from pathlib import Path
import unittest

sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'software'))
from puf256 import Puf256
from puf_screening import Stats,references,freeze,validate

BITMAP=sum(1<<p for p in range(320) if p%5)
KEY=int('0123456789abcdef'*4,16)
HELPER=int('fedcba98765432100123',16)


class Transport:
    """Pre-scripted result packets; does not implement the hardware ECC."""
    def __init__(self,status=0,step=1,hang=False,leak=False):
        self.reg={0:0x50554631,4:0x10000,0xc:1,0x34:100000000,0x38:320,
                  0x3c:256,0x40:80,0x44:5,0x48:8,0x24:0,0x210:0}
        self.writes=[];self.status=status;self.step=step;self.hang=hang;self.leak=leak
    def read(self,address):return self.reg.get(address,0)
    def words(self,address,value,n):
        for i in range(n):self.reg[address+4*i]=(value>>(32*i))&0xffffffff
    def write(self,address,value):
        self.writes.append((address,value));self.reg[address]=value
        if address!=8:return
        action=value&15
        if action in [2,4]:self.reg[0xc]=1
        elif action==1:
            if self.hang:self.reg[0xc]=2;return
            cmd=self.read(0x10);error=self.status!=0
            self.reg[0xc]=4+(0 if error else 8+(16 if cmd==0 else 0))
            self.reg[0x24]=(self.read(0x24)+self.step)&0xffffffff
            self.reg[0x28]=cmd;self.reg[0x1c]=self.status+256*error
            self.words(0x180,KEY if not error or self.leak else 0,8)
            self.words(0x1c0,HELPER if not error and cmd==0 else 0,3)
        elif action==8:
            self.reg[0xc]=257;self.reg[0x210]=(self.read(0x210)+1)&0xffffffff
            for out,src in [(0x214,0x200),(0x218,0x14),(0x21c,0x18)]:self.reg[out]=self.read(src)
            self.reg.update({0x204:45000,0x208:43000,0x20c:0})


class HostProtocol(unittest.TestCase):
    def test_word_order_and_consume(self):
        bus=Transport();device=Puf256(bus)
        response=device.register(BITMAP)
        self.assertEqual((response['key'],response['helper']),(KEY,HELPER))
        self.assertEqual(sum(bus.read(0x100+4*i)<<(32*i) for i in range(10)),BITMAP)
        self.assertEqual(bus.writes[-1],(8,2))
        bus.reg[0x24]=0xffffffff
        response=device.reconstruct(BITMAP,0)
        self.assertEqual(response['sequence'],0)
        self.assertIsNone(response['helper'])
        self.assertEqual(bus.read(0x30),1)  # All-zero helper still valid.
    def test_error_packet_and_leak_rejection(self):
        for status in [2,4,5,8,9,10,11,12]:
            bus=Transport(status=status);response=Puf256(bus).register(BITMAP)
            self.assertFalse(response['ok']);self.assertIsNone(response['key'])
            if status==2:self.assertEqual(bus.writes[-1],(8,4))
        with self.assertRaises(RuntimeError):Puf256(Transport(status=5,leak=True)).register(BITMAP)
    def test_no_partial_configuration_on_invalid_inputs(self):
        bus=Transport();device=Puf256(bus)
        for bitmap in [0,(1<<255)-1,(1<<257)-1,1<<320,-1]:
            with self.assertRaises(ValueError):device.register(bitmap)
        for helper in [-1,1<<80]:
            with self.assertRaises(ValueError):device.reconstruct(BITMAP,helper)
        with self.assertRaises(ValueError):device.register(BITMAP,warmup_cycles=63)
        self.assertFalse(bus.writes)
    def test_sequence_race_and_timeout(self):
        with self.assertRaises(RuntimeError):Puf256(Transport(step=2)).register(BITMAP)
        bus=Transport(hang=True)
        with self.assertRaises(TimeoutError):Puf256(bus).register(BITMAP,timeout=0.002)
        self.assertEqual(bus.writes[-1],(8,4))
    def test_raw_acquisition(self):
        bus=Transport();row=Puf256(bus).measure(319)
        self.assertEqual((row['pair'],row['delta'],row['bit']),(319,2000,1))
        self.assertEqual(row['frequency_a_mhz'],360.0)


def sample(a,b,status=0):return dict(count_a=a,count_b=b,status=status)


class FrozenSelection(unittest.TestCase):
    def test_training_only_margin_and_holdout(self):
        initial=[Stats() for _ in range(320)]
        for p,s in enumerate(initial):
            for _ in range(2):s.add(sample(100+p,80))
        ref=references(initial,2)
        training=[Stats(ref[p]) for p in range(320)]
        for s in training:
            for _ in range(2):s.add(sample(120,100))
        training[0]=Stats(ref[0]);training[0].add(sample(100,93));training[0].add(sample(100,93))
        training[1].add(sample(100,120))  # Wrong read count and sign flip.
        training[2]=Stats(ref[2]);training[2].add(sample(0,0,4));training[2].add(sample(120,100))
        selection=freeze(ref,training,2)
        self.assertTrue(selection['complete']);self.assertEqual(selection['eligible_count'],317)
        self.assertEqual(selection['selected_pairs'],list(range(3,259)))
        frozen=selection['bitmap_hex']
        held=[Stats(ref[p]) for p in range(320)]
        for p in selection['selected_pairs']:held[p].add(sample(120,100))
        self.assertTrue(validate(selection,held,1)['passed'])
        held[3]=Stats(ref[3]);held[3].add(sample(100,120))
        self.assertFalse(validate(selection,held,1)['passed'])
        self.assertEqual(selection['bitmap_hex'],frozen)
    def test_exact_gap_ranking_and_insufficient_pairs(self):
        refs=[1]*320;training=[Stats(1) for _ in range(320)]
        for p,s in enumerate(training):s.add(sample(1000+p,900))
        selection=freeze(refs,training,1)
        self.assertEqual(selection['ranked_eligible'],list(reversed(range(320))))
        self.assertEqual(selection['selected_pairs'],list(range(64,320)))
        for p in range(65):refs[p]=None
        self.assertFalse(freeze(refs,training,1)['complete'])


if __name__=='__main__':unittest.main()
