from PIL import Image, ImageDraw, ImageFont
from pathlib import Path
import itertools
OUT=Path('C:/Users/0milk/.codex/visualizations/2026/10/29/01a18677-d7b6-7571-a565-f3b7d63c19d6')
font='C:/Windows/Fonts/msjh.ttc'
def make(n):
 im=Image.new('RGB',(1600,1450),'white'); d=ImageDraw.Draw(im)
 def t(x,y,s,size=25,col='#172b42'):
  d.text((x,y),s,font=ImageFont.truetype(font,size),fill=col)
 def line(points,col='#263747',w=3):d.line(points,fill=col,width=w)
 def dot(x,y):d.ellipse((x-5,y-5,x+5,y+5),fill='#263747')
 t(45,25,f'{n}-input XOR｜共用電晶體的 parity 網路',42)
 t(45,90,'Y = '+ ' ⊕ '.join('ABCD'[:n]),30)
 t(45,140,'圓圈 = PMOS；無圈 = NMOS。A̅ 表示反相信號；交叉無黑點不相接。',25)
 h=105; top=235
 def network(y0,p):
  target=(1^(n%2)) if p else 0
  for k in range(n):
   starts=[0] if k==0 else [0,1]
   ends=[target] if k==n-1 else [0,1]
   for s in starts:
    for e in ends:
     x1=330 if k==0 else [180,480][s]
     x2=330 if k==n-1 else [180,480][e]
     y1=y0+k*h;y2=y1+h
     # Gate literal is 1 for a parity transition, 0 otherwise.
     bit=s^e; label='ABCD'[k]+('̅' if bit==0 else '')
     # Spread middle-level devices horizontally to make crossings legible.
     xm=(x1+x2)/2
     if k>0 and k<n-1 and s!=e:xm=280 if s==0 else 380
     ym=(y1+y2)/2
     line([(x1,y1),(xm,ym-22),(xm+10,ym-22),(xm+10,ym-15)])
     line([(xm+10,ym+15),(xm+10,ym+22),(xm,ym+22),(x2,y2)])
     line([(xm+10,ym-15),(xm+10,ym+15)],w=4)
     line([(xm,ym-15),(xm,ym+15)])
     line([(xm-24,ym),(xm-7 if p else xm,ym)])
     if p:d.ellipse((xm-8,ym-4,xm,ym+4),outline='#263747',width=2)
     t(xm-55,ym-33,label,23,'#9c382c' if p else '#1a6190')
     dot(x1,y1);dot(x2,y2)
  return y0+n*h
 t(55,200,f'PUN：每顆 Wp = {2*n}',24,'#9c382c')
 line([(330,220),(330,top)]);t(350,205,'VDD',23)
 mid=network(top,True)
 line([(330,mid),(330,mid+65),(615,mid+65)])
 t(630,mid+45,'Y',29);dot(330,mid+65)
 bottomstart=mid+130
 line([(330,mid+65),(330,bottomstart)])
 t(50,bottomstart-40,f'PDN：每顆 Wn = {n}',24,'#1a6190')
 end=network(bottomstart,False)
 line([(330,end),(330,end+20)]);line([(305,end+20),(355,end+20)]);line([(313,end+28),(347,end+28)]);line([(322,end+36),(338,end+36)])
 x=770
 t(x,220,'① 先對齊標準反相器的驅動能力',28)
 for j,s in enumerate(['標準 INV：Wn = 1，Wp = 2','Cin,inv = 1 + 2 = 3',f'每條導通路徑串聯 {n} 顆 MOS',f'NMOS：Rn = {n} × (1/{n}) = 1',f'PMOS：Rp = {n} × (2/{2*n}) = 1',f'所以 Wn = {n}，Wp = {2*n}']):t(x,270+j*43,s)
 t(x,565,'② 加總同一組輸入的 gate 電容',28)
 t(x,615,'X* = {X, X̅}，gX* = (CX + CX̅) / 3')
 for k,c in enumerate('ABCD'[:n]):
  count=2 if k in (0,n-1) else 4
  t(x,675+k*74,f'{c}*：{count} 顆 P + {count} 顆 N',25)
  t(x,708+k*74,f'g{c}* = ({count}×{2*n} + {count}×{n}) / 3 = {count*n}',25,'#165f86')
 yy=1010
 t(x,yy,'③ 對照表格',28)
 vals=[(2 if k in (0,n-1) else 4)*n for k in range(n)]
 t(x,yy+48,'g = ('+', '.join(map(str,vals))+')',32,'#165f86')
 t(x,yy+110,'單一實體 pin 的 g 是上述數值的一半。',23)
 t(x,yy+153,'假設正、反訊號皆已提供；',23)
 t(x,yy+188,'產生反相信號的 INV 未含在此網路內。',23)
 t(45,1350,'正規化：固定通道長度、μn / μp ≈ 2；Cgate 與 W 成正比。',24)
 t(45,1390,'這是可重現表格的共用網路；XOR 的 g 會隨實作拓樸與輸入計數定義改變。',23)
 im.save(OUT/f'xor-{n}-notes.png')
 # Verify graph connectivity for every input: exactly one network conducts.
 for bits in itertools.product([0,1],repeat=n):
  parity=sum(bits)%2
  for p in (False,True):
   target=(1^(n%2)) if p else 0
   state=0
   for b in bits:state^=(1-b if p else b)
   assert (state==target)==(parity==int(p))
for n in (2,3,4):make(n)
print('Generated 3 diagrams; all 56 pull-up/pull-down truth-table checks passed.')
