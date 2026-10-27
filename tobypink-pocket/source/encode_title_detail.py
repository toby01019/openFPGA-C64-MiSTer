from pathlib import Path
from PIL import Image,ImageDraw
import json
p=Path(__file__).resolve().parent;out=p.parent
ref=Image.open(out/'toby-title-original.png').convert('RGB').resize((320,200),Image.Resampling.NEAREST)
shape=Image.new('1',(320,200));d=ImageDraw.Draw(shape);d.polygon([(144,44),(155,44),(166,48),(169,54),(166,60),(140,61),(138,54),(139,49)],fill=1)
positions=[(136,44,15),(160,44,15),(140,60,0),(164,60,0)]
data=bytearray();preview=Image.open(out/'toby-title-c64.png').convert('RGB');pal={15:(174,174,174),0:(0,0,0)}
counts=[]
for n,(left,top,color) in enumerate(positions):
 b=bytearray(64);count=0
 for y in range(21):
  for x in range(24):
   xx,yy=left+x,top+y;r,g,blue=ref.getpixel((xx,yy));hi=max(r,g,blue);lo=min(r,g,blue);sat=(hi-lo)/(hi+1)
   if n<2:on=shape.getpixel((xx,yy)) and 85<hi<225 and sat<.35
   else:on=142<=xx<=173 and 63<=yy<=70 and hi<150 and sat<.36
   if on:b[y*3+x//8]|=128>>(x%8);count+=1;preview.putpixel((xx,yy),pal[color])
 data.extend(b);counts.append(count)
assert all(c>0 for c in counts),counts
(p/'title-detail-sprites.bin').write_bytes(data);preview.save(out/'toby-title-detail-preview.png')
(out/'title-detail.json').write_text(json.dumps({'positions':positions,'foreground_pixels':counts,'implementation':'Four real unexpanded hires hardware sprites, multiplexed above the existing footer sprites; original-reference hair and glasses pixels.'},indent=2))
