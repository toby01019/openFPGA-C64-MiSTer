"""Authored native 320x200 hires bitmap: two C64 colours per 8x8 cell."""
from pathlib import Path
from PIL import Image,ImageDraw
from collections import Counter
from itertools import combinations
import json
s=Path(__file__).resolve().parent;out=s.parent
im=Image.new('P',(320,200));d=ImageDraw.Draw(im)
letters=json.loads((s/'ui-font-design.json').read_text())
def text(x,y,label,c=15):
 for ch in label:
  for yy,row in enumerate(letters.get(ch,['00000']*7)):
   for xx,v in enumerate(row):
    if v=='1':d.point((x+xx,y+yy),fill=c)
  x+=6
def centered(y,label,c):text((320-len(label)*6+1)//2,y,label,c)
message=['CONGRATULATIONS, YOU HAVE COLLECTED','ALL THE CRYSTALS AND YOU HAVE WON','THE PINK AMIGA 4000.','CONGRATULATIONS.']
for y,label,c in zip([8,18,28,38],message,[10,15,10,15]):centered(y,label,c)
left=[(0,51),(17,51),(24,59),(19,75),(26,90),(21,111),(29,130),(25,151),(34,174),(0,188)]
d.polygon(left,fill=4);d.polygon([(319-x,y) for x,y in left],fill=4)
for x,y in [(5,57),(15,83),(7,108),(19,137),(13,165)]:
 for mirror in (False,True):
  p=[(x,y),(x+7,y-3),(x+12,y+4),(x+6,y+10),(x-2,y+7)]
  if mirror:p=[(319-a,b) for a,b in p]
  d.polygon(p,fill=11);d.line(p[:3],fill=12)
for x,h in [(37,8),(79,6),(236,9),(276,7)]:
 d.polygon([(x,53),(x+12,53),(x+6,53+h)],fill=11)
 d.line((x+1,54,x+6,53+h),fill=12)
d.polygon([(20,176),(68,170),(260,170),(301,178),(294,184),(27,184)],fill=11)
d.ellipse((73,174,247,182),fill=4)
for x,y,h in [(39,68,20),(53,82,15),(29,109,25),(51,126,17),(280,68,20),(263,82,15),(288,109,25),(266,126,17)]:
 d.polygon([(x,y),(x+6,y+6),(x+4,y+h),(x-3,y+h+2),(x-7,y+8)],fill=4)
 d.polygon([(x,y+1),(x+4,y+7),(x,y+h-1),(x-5,y+8)],fill=10)
 d.line((x,y+3,x,y+h-3),fill=15);d.line((x-5,y+8,x+4,y+7),fill=0)
 d.line((x-8,y+h+3,x+8,y+h+3),fill=12)
# Pink CRT, bevels, glass, Boing ball and diagonal Amiga colour accents.
d.polygon([(108,65),(207,65),(216,71),(216,117),(210,123),(105,123),(101,116),(101,73)],fill=4)
d.polygon([(108,66),(205,66),(211,71),(211,116),(207,120),(107,120),(104,116),(104,73)],fill=10)
d.line([(108,66),(205,66),(210,71)],fill=15);d.line([(104,74),(104,114),(108,118)],fill=15)
d.rounded_rectangle((112,72,202,111),radius=5,fill=11)
d.rounded_rectangle((115,75,199,108),radius=4,fill=0)
d.line((117,76,195,76),fill=12)
for y in range(80,103):
 for x in range(148,175):
  nx=(x-161)/13;ny=(y-91)/11
  if nx*nx+ny*ny<=1:
   c=1 if ((x-148)//4+(y-80)//4)%2==0 else 2
   if nx>0.6 or ny>0.7:c=15 if c==1 else 9
   d.point((x,y),fill=c)
for i,c in enumerate([2,8,7,5,14]):d.line((121+i*4,93,128+i*4,81),fill=c,width=2)
text(130,114,'AMIGA',11);d.rectangle((197,115,200,116),fill=13)
d.polygon([(148,124),(169,124),(176,131),(141,131)],fill=12);d.line((141,131,176,131),fill=15)
# A4000 case: perspective, ribbed top, recessed drives and readable badge.
d.polygon([(88,133),(225,133),(242,142),(242,161),(78,161),(78,143)],fill=4)
for x in range(96,178,4):d.line((x,135,x-5,139),fill=10);d.point((x,135),fill=15)
d.rectangle((80,143,239,158),fill=10);d.line((81,143,237,143),fill=15);d.line((81,157,237,157),fill=4)
d.rectangle((88,147,92,151),fill=11);d.point((90,149),fill=13)
d.rectangle((101,146,166,154),fill=4);text(104,147,'AMIGA 4000',15)
for y in (146,152):
 d.rectangle((187,y,230,y+2),fill=0);d.line((189,y,227,y),fill=11);d.point((224,y+1),fill=15)
for x in (94,220):d.rectangle((x,162,x+8,163),fill=11)
d.polygon([(96,165),(221,165),(233,179),(86,179)],fill=12);d.line((96,165,221,165),fill=15)
for row in range(3):
 y=167+row*3;start=96-row*2
 for k in range(18):
  x=start+k*6;d.rectangle((x,y,x+3,y+1),fill=15);d.point((x+3,y+1),fill=11)
 for x in (210,216,222):d.rectangle((x,y,x+3,y+1),fill=15)
d.rectangle((117,176,174,177),fill=15);d.line((87,179,232,179),fill=0)
d.line([(239,171),(250,172),(256,168),(258,162)],fill=12)
d.rounded_rectangle((248,172,262,181),radius=4,fill=15);d.line((255,173,255,177),fill=11)
centered(190,'PRESS FIRE TO REPLAY',10)
vpl=Path('C:/Users/toby0/Downloads/GTK3VICE-3.10-win64/GTK3VICE-3.10-win64/C64/pepto-pal.vpl')
pal=[tuple(int(x,16) for x in l.split()[:3]) for l in vpl.read_text().splitlines() if l and not l.startswith('#')]
dist=[[sum((pal[a][i]-pal[b][i])**2 for i in range(3)) for b in range(16)] for a in range(16)]
bitmap=bytearray();matrix=bytearray();native=Image.new('RGB',(320,200))
for cy in range(25):
 for cx in range(40):
  cell=[im.getpixel((cx*8+x,cy*8+y)) for y in range(8) for x in range(8)];counts=Counter(cell)
  candidates=sorted(counts) if len(counts)>1 else sorted({0,next(iter(counts)),1})
  a,b=min(combinations(candidates,2),key=lambda p:sum(n*min(dist[c][p[0]],dist[c][p[1]]) for c,n in counts.items()))
  matrix.append((b<<4)|a)
  for y in range(8):
   bits=0
   for x in range(8):
    c=cell[y*8+x];v=b if dist[c][b]<dist[c][a] else a
    if v==b:bits|=128>>x
    native.putpixel((cx*8+x,cy*8+y),pal[v])
   bitmap.append(bits)
ns={};exec((s/'encode_sprites.py').read_text().split('s=Path(__file__)')[0],ns)
packed=ns['pack'](bytes(matrix))+ns['pack'](bytes(bitmap))
assert len(packed)<=4096,('scene overlaps I/O',len(packed))
(s/'reward-bitmap.bin').write_bytes(bitmap);(s/'reward-screen.bin').write_bytes(matrix)
(s/'reward-scene.pak').write_bytes(packed)
(out/'toby-reward-scene-v0.3.27.prg').write_bytes(b'\x00\xc0'+packed)
native.resize((960,600),Image.Resampling.NEAREST).save(out/'amiga-bitmap-design-3x.png')
(out/'reward-scene-design.json').write_text(json.dumps({'status':'awaiting user approval','mode':'native C64 hires bitmap','dimensions':[320,200],'colours_per_cell':2,'packed_bytes':len(packed),'victory_text':' '.join(message),'replay_prompt':'PRESS FIRE TO REPLAY','ultimate_deployed':False,'music_scene':'one persistent bitmap before and during music; two animated bats'},indent=2))
print('Reward bitmap:',len(bitmap),'bytes; packed scene',len(packed),'bytes')

