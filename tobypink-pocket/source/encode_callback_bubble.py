"""Append one compact speech bitmap while preserving all approved glyphs."""
from pathlib import Path
from PIL import Image
import json
s=Path(__file__).resolve().parent
rows={
 'A':['010','101','111','101','101'],'N':['101','111','111','111','101'],
 'D':['110','101','101','101','110'],'I':['111','010','010','010','111'],
 'H':['101','101','111','101','101'],'T':['111','010','010','010','010'],
 'E':['111','100','110','100','111'],'C':['011','100','100','100','011'],
 'L':['100','100','100','100','111'],'B':['110','101','110','101','110'],
 'K':['101','101','110','101','101'],'8':['111','101','111','101','111'],
 '0':['111','101','101','101','111'],'2':['110','001','010','100','111'],
 ' ':['000']*5}
lines=['AND I HATE THE','CALLBACK 8020'];width=72;height=24
p=[[0]*width for _ in range(height)]
for x in range(3,width-3):p[0][x]=p[height-4][x]=1
for y in range(2,height-5):p[y][0]=p[y][-1]=1
for x,y in [(1,1),(2,0),(width-2,1),(width-3,0),(1,height-5),(width-2,height-5),(width//2-2,height-3),(width//2-1,height-2),(width//2,height-1),(width//2+1,height-2),(width//2+2,height-3)]:p[y][x]=1
for ly,line in enumerate(lines):
 for cx,ch in enumerate(line):
  for yy,row in enumerate(rows[ch]):
   for xx,v in enumerate(row):
    if v=='1':p[3+ly*7+yy][5+cx*4+xx]=1
font=bytearray((s/'world-font.bin').read_bytes())
# Platform art occupies 64..95; gameplay and original speech use >=128.
# These new slots are separate from the flight charset at the same address.
font[96*8:128*8]=bytes(32*8)
lookup={bytes(font[i*8:i*8+8]):i for i in range(203,250)};lookup[bytes(8)]=32
cells=[];used=0
for cy in range(3):
 for cx in range(9):
  tile=bytes(sum(p[cy*8+y][cx*8+x]<<(7-x) for x in range(8)) for y in range(8))
  if tile not in lookup:
   assert used<32
   code=96+used;used+=1;lookup[tile]=code;font[code*8:code*8+8]=tile
  cells.append(lookup[tile])
oldmaps=(s/'bubble-maps.bin').read_bytes()[:108]
(s/'bubble-maps.bin').write_bytes(oldmaps+bytes(cells));(s/'world-font.bin').write_bytes(font)
# The world-font decoder uses zero runs, rather than the sprite LZ format.
packed=bytearray();i=0
while i<len(font):
 zero=not font[i];n=1
 while n<127 and i+n<len(font) and (not font[i+n])==zero:n+=1
 packed.append(n|(128 if zero else 0))
 if not zero:packed.extend(font[i:i+n])
 i+=n
packed.append(0);(s/'world-font.pak').write_bytes(packed)
(s/'bubble-tables.inc').write_text('BUBBLE_FIRST = 203\nBUBBLE_COUNT = 47\nBUBBLE_KIND_COUNT = 6\nCALLBACK_FIRST = 96\nCALLBACK_COUNT = '+str(used)+'\nbubble_widths: .byte 7,12,8,10,6,9\nbubble_heights: .byte 2,3,2,3,2,3\nbubble_offsets: .byte 0,14,50,66,96,108\n')
(s.parent/'speech-texts.json').write_text(json.dumps({'additional_phrase':'And I hate the Callback 8020','native_lines':lines,'kind':5,'size_pixels':[72,24],'new_glyphs':used,'slot_range':[96,96+used-1],'existing_phrases_preserved':True},indent=2))
print('Additional enemy bubble:',len(cells),'cells;',used,'new glyphs')
