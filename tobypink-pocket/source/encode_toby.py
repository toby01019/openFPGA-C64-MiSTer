from pathlib import Path
import json
from PIL import Image,ImageDraw

s=Path(__file__).resolve().parent;out=s.parent
design=(s/'toby-design.py').read_text()
ns={};exec(design,ns)
figure=ns['figure']; C=ns['C']
rgb={tuple(bytes.fromhex(v[1:])):k for k,v in C.items()}
raw=bytearray((s/'sprite-data.bin').read_bytes()[:7168])+bytearray(960)
left_legs=[2,3,4,5,18,19,20,21]

def encoded(a,mc):
 b=bytearray(64)
 for y in range(21):
  for x in range(a.width):b[y*3+(x//4 if mc else x//8)]|=a.getpixel((x,y))<<(6-2*(x%4) if mc else 7-x%8)
 return b

def store(n,a,mc):raw[n*64:(n+1)*64]=encoded(a,mc)

def planes(im):
 im=im.crop((4,1,28,32))
 a=Image.new('P',(12,21));h=Image.new('P',(24,21));legs=Image.new('P',(12,21))
 for y in range(31):
  for mx in range(12):
   keys=[rgb.get(tuple(im.getpixel((mx*2+q,y))[:3]),'bg') if im.getpixel((mx*2+q,y))[3] else 'bg' for q in (0,1)]
   if y<21:
    v=0
    if any(k.startswith('hair') for k in keys):v=1
    if any(k.startswith('skin') or k in ('shade','light','lens') for k in keys):v=3
    if any(k in ('glass','shirt','shirtlight','pants','pantshadow') for k in keys):v=2
    a.putpixel((mx,y),v)
    for q,k in enumerate(keys):
     x=mx*2+q
     # White belongs only to hair highlights and the C= shirt logo.
     # Skin and glasses lenses stay solid light red (native C64 colour 10).
     if k in ('logo','hairlight'):h.putpixel((x,y),1)
   else:
    v=0
    if any(k in ('pants','pantshadow','shirt','shirtlight') for k in keys):v=2
    if any(k in ('shoe','skin','shade') for k in keys):v=3
    if any(k=='logo' for k in keys):v=1
    legs.putpixel((mx,y-21),v)
 return a,h,legs

def pose(saw=False,gun=False,phase=0):
 im=figure();d=ImageDraw.Draw(im)
 if saw or gun:
  d.rectangle((20,17,24,22),fill=(0,0,0,0))
  d.line([(20,17),(21,20),(24,20)],fill=C['skin'],width=2)
  d.line((20,16,21,17),fill=C['shirtlight'],width=2)
 if saw:
  d.rectangle((23,20,25,22),fill=C['shirt'])
  d.line((24,21,27,21),fill=C['hairlight'])
  d.point((25+phase,22),fill=C['hairlight'])
 if gun:
  d.line((23,18,27,18),fill=C['shirtlight'],width=2)
  d.line((23,17,27,17),fill=C['hairlight'])
 return im

for p in (0,3,4,5,6,7):
 for left in (False,True):
  im=pose(saw=p in (4,5),gun=p in (6,7),phase=p&1)
  if left:im=im.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
  a,h,lo=planes(im)
  n=p*2+(16 if left else 0)
  store(n,a,True);store(n+1,h,False)
for i in range(8):
 for left in (False,True):
  a,h,lo=planes(figure(i,left))
  n=(96 if left else 80)+2*i
  store(n,a,True);store(n+1,h,False)
  store(left_legs[i] if left else 112+i,lo,True)
for left in (False,True):
 a,h,lo=planes(figure(left=left));store(120+int(left),lo,True)

# Matching seated rider: retain the full approved head and logo.
for left in (False,True):
 im=pose(gun=True)
 if left:im=im.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
 a,h,_=planes(im)
 store(63 if left else 53,a,True);store(65 if left else 57,h,False)

# The entire bike uses one horizontally expanded multicolour sprite.
bike=Image.new('P',(12,21));d=ImageDraw.Draw(bike)
d.line((3,9,5,9),fill=2);d.line((5,10,8,10),fill=1)
d.line((8,10,10,8),fill=1);d.point((10,7),fill=2)
d.line((0,12,10,12),fill=1);d.line((1,13,9,13),fill=3)
d.rectangle((2,14,7,16),fill=2);d.line((3,15,6,15),fill=1)
d.line((8,14,11,14),fill=1);d.line((0,15,1,15),fill=3)
d.line((3,17,6,17),fill=1);d.point((4,18),fill=2)
store(54,bike,True);store(56,bike,True)
store(64,bike.transpose(Image.Transpose.FLIP_LEFT_RIGHT),True)

# Death retains the same portrait; the second pose is the fallen whole body.
a,h,_=planes(figure());store(58,a,True);store(59,h,False)
im=figure().transpose(Image.Transpose.ROTATE_90).resize((24,21),Image.Resampling.NEAREST)
canvas=Image.new('RGBA',(32,32));canvas.paste(im,(4,1));a,h,_=planes(canvas)
store(60,a,True);store(61,h,False)

# Four climbing poses. Their common hair detail uses one shared hires sprite.
# Jump now aliases idle upper art, releasing slots 6/7/22/23 for bent legs.
climb_legs=[6,7,22,23]
for i in range(4):
 a,h,lo=planes(ns['climb'](i))
 store(122+i,a,True);store(climb_legs[i],lo,True)
 if i==0:climb_detail=h.tobytes();store(126,h,False)
 else:assert h.tobytes()==climb_detail

# Enemy designs are kept separately for approval, not installed in the game.
# Each has two multicolour planes and the same 30-pixel visual height as Toby.
foes=bytearray()
for kind in range(2):
 for left in (False,True):
  for phase in [None]+list(range(8)):
   a,h,lo=planes(ns['opponent'](kind,phase,left))
   foes.extend(encoded(a,True));foes.extend(encoded(lo,True))
(s/'opponent-review.bin').write_bytes(foes)
# Double-buffered working planes for the full-height opponents.
raw[32*64:44*64]=bytes(12*64)
(s/'sprite-data.bin').write_bytes(raw)
(s/'walk-planes.bin').write_bytes(raw[5120:7168])
(s/'toby-lower.inc').write_text('lower_left: .byte '+','.join(str(128+n) for n in left_legs)+'\n')
print('Native Toby art regenerated:',len(raw),'bytes')
