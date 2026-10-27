from pathlib import Path
from itertools import combinations
from PIL import Image
import numpy as np,json
p=Path(__file__).resolve().parent;out=p.parent
pal=np.array([(0,0,0),(255,255,255),(150,40,46),(91,214,206),(159,45,173),(65,185,54),(39,36,196),(239,243,71),(159,72,21),(94,53,0),(218,95,102),(71,71,71),(120,120,120),(145,255,132),(104,100,255),(174,174,174)],dtype=float)
old={n:(p/f'title-{n}.bin').read_bytes() for n in ('bitmap','screen','color')}
im=Image.open(out/'toby-title-original.png').convert('RGB').resize((320,200),Image.Resampling.BOX).resize((160,200),Image.Resampling.BOX)
rgb=np.array(im,dtype=float);high=rgb.max(2);low=rgb.min(2);chroma=high-low
sat=chroma/(high+1);hue=np.zeros(high.shape)
for channel,offset in ((0,0),(1,2),(2,4)):
 mask=(rgb.argmax(2)==channel)&(chroma>0)
 hue[mask]=((rgb[:,:, (channel+1)%3]-rgb[:,:, (channel+2)%3])[mask]/chroma[mask]+offset)/6
hue%=1
graded=255*(rgb/255)**.85
# Lift warm portrait skin toward pale peach; retain dark ground/belt colours.
yy,xx=np.indices(high.shape);skin=(xx>42)&(xx<119)&(yy>43)&(yy<131)&(hue<.14)&(sat>.25)&(high>65)
grey=graded.mean(2)
graded[skin]=graded[skin]*.85+grey[skin,None]*.15
graded[skin]=np.minimum(255,graded[skin]+10)
neutral=sat<.18;pink=(hue>.77)&(hue<.97);green=(hue>=.17)&(hue<.46);blue=(hue>=.52)&(hue<.77)
allowed=np.ones((*high.shape,16),dtype=bool)
for mask,values in ((neutral,[0,1,11,12,15]),(pink,[0,4]),(green,[0,5,13]),(blue,[0,6,14]),(skin,[0,8,10,15])):
 allowed[mask]=False
 for value in values:allowed[:,:,value][mask]=True
choices=np.array([[0,*v] for v in combinations(range(1,16),3)])
bitmap=bytearray();screen=bytearray();color=bytearray();indices=np.zeros((200,160),dtype=np.uint8)
for cy in range(25):
 for cx in range(40):
  tile=graded[cy*8:cy*8+8,cx*4:cx*4+4].reshape(32,3)
  ok=allowed[cy*8:cy*8+8,cx*4:cx*4+4].reshape(32,16)
  dist=((tile[:,None,:]-pal[None,:,:])**2).sum(2)+np.where(ok,0,24000)
  selected=choices[dist[:,choices].min(2).sum(0).argmin()]
  codes=dist[:,selected].argmin(1).reshape(8,4)
  indices[cy*8:cy*8+8,cx*4:cx*4+4]=selected[codes]
  bitmap.extend(int(sum(int(row[i])<<(6-2*i) for i in range(4))) for row in codes)
  screen.append(int(selected[1]*16+selected[2]));color.append(int(selected[3]))
def rle(data):
 result=bytearray();pos=0
 while pos<len(data):
  run=1
  while pos+run<len(data) and data[pos+run]==data[pos] and run<128:run+=1
  if run>=3:
   result.extend([128+run-1,data[pos]]);pos+=run
  else:
   begin=pos;pos+=run
   while pos<len(data) and pos-begin<128:
    run=1
    while pos+run<len(data) and data[pos+run]==data[pos] and run<3:run+=1
    if run>=3:break
    pos+=min(run,128-(pos-begin))
   result.append(pos-begin-1);result.extend(data[begin:pos])
 return result

for name,data in (('bitmap',bitmap),('screen',screen),('color',color)):
 start=18*40*(8 if name=='bitmap' else 1);data[start:]=old[name][start:]
 (p/f'title-{name}.bin').write_bytes(data);(p/f'title-{name}.rle').write_bytes(rle(data))
for cy in range(25):
 for cx in range(40):
  at=cy*40+cx;palette=[0,screen[at]>>4,screen[at]&15,color[at]]
  for y in range(8):
   for x in range(4):indices[cy*8+y,cx*4+x]=palette[(bitmap[at*8+y]>>(6-2*x))&3]
native=Image.fromarray(pal[indices].astype(np.uint8)).resize((320,200),Image.Resampling.NEAREST);native.save(out/'toby-title-c64.png')
assert all(len(set(indices[y:y+8,x:x+4].ravel()))<=4 for y in range(0,200,8) for x in range(0,160,4))
(out/'title-encoding.json').write_text(json.dumps({'result':'passed','format':'VIC-II standard multicolor bitmap','global_background':0,'max_colors_per_cell':4,'colors_used':list(map(int,np.unique(indices))),'changes':'Brighter dark detail; neutral logo restricted to greys; pink, green and blue retain their hue families; pale portrait skin.'},indent=2))
print('New native palette encoded; neutral logo, pale face, brighter scene detail')
