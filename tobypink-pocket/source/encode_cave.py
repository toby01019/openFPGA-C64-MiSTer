from pathlib import Path
s=Path(__file__).resolve().parent
# Native 8x8 rock glyphs: sparse single-pixel contours, no borrowed scenery.
glyphs=[bytes(8),bytes([255,128,128,129,128,128,128,255]),bytes([255,1,1,1,65,1,1,255]),bytes([128,64,32,16,8,4,2,1]),bytes([1,2,4,8,16,32,64,128]),bytes([255,127,63,31,15,7,3,1]),bytes([255,254,252,248,240,224,192,128]),bytes([129,66,36,24,24,0,0,0]),bytes([255,255,126,126,60,60,24,24]),bytes([24,24,60,60,126,126,255,255]),bytes([0,0,0,16,0,0,0,1]),bytes([0,32,0,0,0,0,4,0]),bytes([255,0,0,16,0,0,0,0]),bytes([128,128,144,128,128,128,128,128]),bytes([1,1,1,1,17,1,1,1]),bytes([0,0,0,0,0,0,0,255]),bytes([192,160,144,136,132,130,129,128]),bytes([3,5,9,17,33,65,129,1]),bytes([128,64,32,16,8,4,2,255]),bytes([1,2,4,8,16,32,64,255]),bytes([0,0,0,0,24,36,66,129])]
font=bytearray((s/'world-font.bin').read_bytes())
for i,g in enumerate(glyphs):font[(64+i)*8:(65+i)*8]=g
(s/'world-font.bin').write_bytes(font)
def pack(data):
 out=bytearray();i=0
 while i<len(data):
  if data[i]==0:
   n=1
   while i+n<len(data) and data[i+n]==0 and n<127:n+=1
   out.append(128+n);i+=n
  else:
   n=1
   while i+n<len(data) and data[i+n]!=0 and n<127:n+=1
   out.append(n);out.extend(data[i:i+n]);i+=n
 out.append(0);return out
(s/'world-font.pak').write_bytes(pack(font))
chars=[32]+list(range(64,85));palette=[0,3,6,10,11,12,15]
screen=bytearray([32]*1000);colors=bytearray(1000);packed=bytearray(1000)
for y in range(3,23):
 for x in range(40):
  ch=32;col=0
  if x<2 or x>37:
   ch=65 if (x+y)%2==0 else 66;col=11
  elif x==2 or x==37:
   ch=77 if x==2 else 78;col=12 if y%4==0 else 11
  elif y==3:
   ch=76;col=12
  elif y==4 and x%7 in (2,3):
   ch=69 if x%7==2 else 70;col=12
  elif y==5 and x%9==4:
   ch=72;col=11
  elif y==6 and x%9==4:
   ch=71;col=11
  elif 4<x<35 and 7<y<22 and (x*13+y*7)%43==0:
   ch=74+(x%2);col=11
  screen[y*40+x]=ch;colors[y*40+x]=col
  packed[y*40+x]=chars.index(ch)|(palette.index(col)<<5)
(s/'world-packed.bin').write_bytes(packed[120:920])
(s/'world-map.bin').write_bytes(screen);(s/'world-colors.bin').write_bytes(colors)
(s/'world-dictionary.inc').write_text('world_chars: .byte '+','.join(map(str,chars))+'\nworld_colors: .byte '+','.join(map(str,palette))+'\n',encoding='utf-8')

from pathlib import Path
p=s;data=(p/'world-font.bin').read_bytes();n=len(data);cost=[0]*(n+1);choice=[None]*n
for i in range(n-1,-1,-1):
 best=10**9
 for k in range(1,min(127,n-i)+1):
  v=1+k+cost[i+k]
  if v<best:best=v;choice[i]=(k,False)
  if not any(data[i:i+k]):
   v=1+cost[i+k]
   if v<best:best=v;choice[i]=(k,True)
 cost[i]=best
out=bytearray();i=0
while i<n:
 k,z=choice[i];out.append(k|(128 if z else 0))
 if not z:out.extend(data[i:i+k])
 i+=k
out.append(0);(p/'world-font.pak').write_bytes(out)
print('Packed native font:',len(out))
