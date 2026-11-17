"""MMIO transport only. Acquisition, voting, helper generation and ECC run in PL.

Python 3.6+, one controller per overlay. Integers/CSR words use least-significant
word first. This returns PUF material, not an authenticated or extracted key.
"""
import operator
import time

STATUS_NAMES={0:'PUF_OK',1:'PUF_BAD_COMMAND',2:'PUF_MEASURE_TIMEOUT',4:'PUF_WEAK_PAIR',
              5:'PUF_ECC_UNCORRECTABLE',6:'PUF_MISSING_HELPER',7:'PUF_BAD_BITMAP',
              8:'PUF_BAD_WINDOW',9:'PUF_BAD_WARMUP',10:'PUF_RO_STOPPED',
              11:'PUF_RO_SATURATED',12:'PUF_BACKEND_FAULT'}


class Puf256:
    def __init__(self, ip):
        self.ip=ip
        if ip.read(0)!=0x50554631 or ip.read(4)!=0x00010000:
            raise RuntimeError('Wrong PUF256 overlay/register map')
        self.clock_hz=ip.read(0x34)
        self.pairs=ip.read(0x38)
        self.raw_bits=ip.read(0x3c)
        self.helper_bits=ip.read(0x40)
        self.repeats=ip.read(0x44)
        self.min_margin=ip.read(0x48)
        if (self.clock_hz,self.pairs,self.raw_bits,self.helper_bits,self.repeats,self.min_margin)!=(100000000,320,256,80,5,8):
            raise RuntimeError('Unsupported hardware configuration')

    def _words(self, address, count):
        return sum(self.ip.read(address+4*i)<<(32*i) for i in range(count))

    def _put(self,address,value,count):
        for i in range(count):
            self.ip.write(address+4*i,(value>>(32*i))&0xffffffff)

    def _ready(self):
        flags=self.ip.read(0x0c)
        if not flags&1:
            raise RuntimeError('PUF busy, result pending, or locked; consume the result or call abort()')

    def abort(self, timeout=1.0):
        if timeout<=0:raise ValueError('timeout must be positive')
        self.ip.write(8,4)
        deadline=time.monotonic()+timeout
        while not self.ip.read(0x0c)&1:
            if time.monotonic()>=deadline:raise TimeoutError('Abort failed; reset/reload the overlay')
            time.sleep(0.001)

    def _configure(self,window_cycles,warmup_cycles):
        window_cycles=operator.index(window_cycles)
        warmup_cycles=operator.index(warmup_cycles)
        if not 16<=window_cycles<=100000:raise ValueError('window_cycles must be 16..100000')
        if not 64<=warmup_cycles<=1000000:raise ValueError('warmup_cycles must be 64..1000000')
        self.ip.write(0x14,window_cycles);self.ip.write(0x18,warmup_cycles)
        return window_cycles,warmup_cycles

    def _await(self,flag_bit,seq_address,previous,timeout):
        deadline=time.monotonic()+timeout
        while True:
            flags=self.ip.read(0x0c)
            sequence=self.ip.read(seq_address)
            if flags&32:raise RuntimeError('START rejected; check for a second controller')
            if flags&(1<<flag_bit) and sequence!=previous:
                if sequence!=((previous+1)&0xffffffff):raise RuntimeError('Unexpected completion sequence')
                return flags,sequence
            if time.monotonic()>=deadline:
                self.abort()
                raise TimeoutError('PUF timed out and both core/backend were reset')
            time.sleep(0.001)

    def register(self,bitmap,window_cycles=100000,warmup_cycles=1024,timeout=None):
        return self._run(0,bitmap,None,window_cycles,warmup_cycles,timeout)

    def reconstruct(self,bitmap,helper,window_cycles=100000,warmup_cycles=1024,timeout=None):
        return self._run(1,bitmap,helper,window_cycles,warmup_cycles,timeout)

    def _run(self,command,bitmap,helper,window_cycles,warmup_cycles,timeout):
        bitmap=operator.index(bitmap)
        if not 0<=bitmap<(1<<320) or bin(bitmap).count('1')!=256:
            raise ValueError('bitmap must be 320 bits with exactly 256 selected pairs')
        if command==1:
            helper=operator.index(helper)
            if not 0<=helper<(1<<80):raise ValueError('helper must be an 80-bit integer (zero is valid)')
        if timeout is not None and timeout<=0:raise ValueError('timeout must be positive')
        self._ready()
        window,warmup=self._configure(window_cycles,warmup_cycles)
        self._put(0x100,bitmap,10);self._put(0x140,helper or 0,3)
        self.ip.write(0x30,int(command==1));self.ip.write(0x10,command)
        previous=self.ip.read(0x24)
        self.ip.write(8,17)
        timeout=timeout if timeout is not None else 2.0+2.0*256*self.repeats*(window+warmup)/self.clock_hz
        flags,sequence=self._await(2,0x24,previous,timeout)
        packed_status=self.ip.read(0x1c)
        status=packed_status&255
        error=(packed_status>>8)&1
        if status not in STATUS_NAMES or error!=int(status!=0):
            raise RuntimeError('Inconsistent hardware error/status packet')
        key=self._words(0x180,8)
        helper_out=self._words(0x1c0,3)
        corrected=self.ip.read(0x20)
        if self.ip.read(0x28)!=command or self.ip.read(0x24)!=sequence:
            raise RuntimeError('Result belongs to another request/controller')
        if bool(flags&8)!=(error==0) or bool(flags&16)!=(error==0 and command==0):
            raise RuntimeError('Invalid result qualification flags')
        if error and (key or helper_out or corrected):raise RuntimeError('Failed operation exposed result data')
        if command==1 and helper_out:raise RuntimeError('Reconstruction unexpectedly returned a helper')
        result=dict(command=command,sequence=sequence,ok=not error,status=status,
                    status_name=STATUS_NAMES.get(status,'UNKNOWN'),error=error,
                    key=key if not error else None,helper=helper_out if not error and command==0 else None,
                    corrected_words=corrected,bitmap=bitmap,window_cycles=window,warmup_cycles=warmup)
        self.ip.write(8,2)  # Consume only after the complete packet was read coherently.
        if status==2:self.abort()
        else:
            deadline=time.monotonic()+1.0
            while not self.ip.read(0x0c)&1:
                if time.monotonic()>=deadline:raise TimeoutError('Result consumed but device did not become ready')
                time.sleep(0.001)
        return result

    def measure(self,pair,window_cycles=100000,warmup_cycles=1024,timeout=2.0):
        pair=operator.index(pair)
        if not 0<=pair<320:raise ValueError('pair must be 0..319')
        if timeout<=0:raise ValueError('timeout must be positive')
        self._ready();window,warmup=self._configure(window_cycles,warmup_cycles)
        self.ip.write(0x200,pair);previous=self.ip.read(0x210);self.ip.write(8,24)
        _,sequence=self._await(8,0x210,previous,timeout)
        a=self.ip.read(0x204);b=self.ip.read(0x208);status=self.ip.read(0x20c)
        if (self.ip.read(0x214),self.ip.read(0x218),self.ip.read(0x21c),self.ip.read(0x210))!=(pair,window,warmup,sequence):
            raise RuntimeError('Raw result metadata changed; use one controller')
        scale=8*self.clock_hz/window/1e6
        return dict(pair=pair,sequence=sequence,status=status,count_a=a,count_b=b,delta=a-b,
                    bit=int(a>b) if status==0 and a!=b else None,
                    frequency_a_mhz=a*scale,frequency_b_mhz=b*scale,
                    window_cycles=window,warmup_cycles=warmup)
