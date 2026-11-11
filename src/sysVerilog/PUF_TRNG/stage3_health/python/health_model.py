"""Reference-symbol binary RCT/APT model; thresholds are monitoring assumptions."""
class Monitor:
    def __init__(self,rct=41,window=1024,apt=793):
        self.rct=rct;self.window=window;self.apt=apt;self.reset()
    def reset(self):
        self.previous=None;self.reference=0;self.index=0;self.runs=[0]*8;self.counts=[0]*8;self.rct_mask=0;self.apt_mask=0
    def step(self,value,valid=True,clear=False):
        if clear:self.reset();return 0,0
        if not valid:return 0,0
        rf=0;af=0
        for k in range(8):
            bit=(value>>k)&1
            self.runs[k]=self.runs[k]+1 if self.previous is not None and bit==((self.previous>>k)&1) else 1
            if self.runs[k]>=self.rct:rf|=1<<k
            if self.index==0:self.counts[k]=1
            elif bit==((self.reference>>k)&1):self.counts[k]+=1
            if self.index!=0 and bit==((self.reference>>k)&1) and self.counts[k]>=self.apt:af|=1<<k
        if self.index==0:self.reference=value
        self.index=(self.index+1)%self.window;self.previous=value
        self.rct_mask|=rf;self.apt_mask|=af
        return rf,af
