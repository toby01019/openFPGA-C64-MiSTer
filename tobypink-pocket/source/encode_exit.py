"""Native one-pixel exit sign and arch, reserving world glyphs 85..95."""
from pathlib import Path
s=Path(__file__).resolve().parent
font=bytearray((s/'world-font.bin').read_bytes())
# 24x8 miniature EXIT lettering, centred over the entrance.
letters={'E':[7,4,6,4,7],'X':[5,5,2,5,5],'I':[7,2,2,2,7],'T':[7,2,2,2,2]}
rows=[0]*8
for j,ch in enumerate('EXIT'):
 for y,bits in enumerate(letters[ch]):rows[y+1]|=bits<<(17-j*4)
glyphs=[bytes((row>>(16-i*8))&255 for row in rows) for i in range(3)]
glyphs += [bytes([0,0,3,7,14,28,56,48]),bytes([0,126,255,129,0,0,0,0]),bytes([0,0,192,224,112,56,28,12]),
 bytes([112,80,112,96,80,112,96,112]),bytes([14,10,14,6,10,14,6,14]),
 bytes([112,80,112,96,112,127,255,255]),bytes([0,0,0,0,0,255,255,255]),bytes([14,10,14,6,14,254,255,255])]
assert len(glyphs)==11
for i,g in enumerate(glyphs):font[(85+i)*8:(86+i)*8]=g
(s/'world-font.bin').write_bytes(font)
# Same optimal zero/literal codec as the existing world font.
n=len(font);cost=[0]*(n+1);choice=[None]*n
for i in range(n-1,-1,-1):
 best=10**9
 for k in range(1,min(127,n-i)+1):
  v=1+k+cost[i+k]
  if v<best:best=v;choice[i]=(k,False)
  if not any(font[i:i+k]) and 1+cost[i+k]<best:best=1+cost[i+k];choice[i]=(k,True)
 cost[i]=best
packed=bytearray();i=0
while i<n:
 k,z=choice[i];packed.append(k|(128 if z else 0))
 if not z:packed.extend(font[i:i+k])
 i+=k
packed.append(0);(s/'world-font.pak').write_bytes(packed)
print('Exit glyphs 85..95; packed font',len(packed))
