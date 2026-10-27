"""Build the approved palm concept as real C64 hires character assets.

Every tile has black plus one C64 foreground colour; only 8x8 glyphs are
stored. The two sizes share their drawing rules and form an 80-column loop.
"""
from pathlib import Path
from PIL import Image,ImageDraw
import math,re,json
s=Path(__file__).resolve().parent
ns={};exec((s/'encode_sprites.py').read_text().split('s=Path(__file__)')[0],ns);pack=ns['pack']
def tree(w,h):
 im=Image.new('1',(w,h));d=ImageDraw.Draw(im);cx=w//2;cy=16
 # Slender bent trunk with alternating notches and an illuminated edge.
 pts=[]
 for y in range(cy,h):
  q=(y-cy)/(h-cy);x=cx+round(12*q*q)
  d.line((x-2,y,x+2,y),fill=1)
  if y%6 in (0,1):d.point((x-2,y),fill=0);d.point((x,y),fill=0)
  pts.append((x,y))
 # Curved single-pixel leaf spines and fine drooping leaflets.
 for side in (-1,1):
  for endx,endy,controlx,controly in [(w//2-2,31,w//3,-2),(w//2-4,17,w//3,-8),(w//3,4,w//5,-10)]:
   curve=[]
   for i in range(25):
    t=i/24;u=1-t
    x=cx+side*round(2*u*t*controlx+t*t*endx)
    y=cy+round(2*u*t*controly+t*t*(endy-cy));curve.append((x,y))
   d.line(curve,fill=1)
   for i in range(4,24,3):
    x,y=curve[i];length=round(6*(1-i/30))+1
    d.line((x,y,x-side*2,y+length),fill=1)
 d.ellipse((cx-2,cy-1,cx+2,cy+3),fill=1)
 return im
world=Image.new('1',(640,104));placements=[(8,16,64,88),(128,40,48,64),(232,16,64,88),(360,32,56,72),(480,16,64,88),(584,40,48,64)]
for x,y,w,h in placements:world.paste(tree(w,h),(x,y),tree(w,h))
# Distant palm silhouettes use the same small-tree glyphs and dark purple.
d=ImageDraw.Draw(world)
# Keep the sand transition open, without the previous repeated grass zigzag.
for x in (80,400):d.ellipse((x,0,x+15,15),fill=1)
glyphs=[];lookup={};screen=bytearray();colors=bytearray()
available=list(range(64,128))+list(range(151,160))+list(range(180,190))+list(range(194,256))
for row in range(13):
 for col in range(80):
  tile=bytes(sum(int(world.getpixel((col*8+x,row*8+y)))<<(7-x) for x in range(8)) for y in range(8))
  if not any(tile):code=32
  else:
   if tile not in lookup:
    lookup[tile]=available[len(glyphs)];glyphs.append(tile)
   code=lookup[tile]
  screen.append(code)
  color=1 if row<2 else 10
  if row>=6:
   color=4
   # Trunks and nearby leaves have distinct warm/pink shades per cell.
   for tx,ty,tw,th in placements:
    cy=ty+16;q=max(0,(row*8+4-cy)/(th-16));trunk=tx+tw//2+round(12*q*q)
    if cy+14<=row*8+4 and abs(col*8+4-trunk)<7:color=8
    elif tx<=col*8+4<tx+tw and ty<=row*8<cy+28:color=10 if col%3 else 4
   # Keep the trunk warm to the beach, without green end caps.
  colors.append(color)
assert len(glyphs)<=len(available),(len(glyphs),len(available))
font=bytearray(2048)
# Preserve all flight gameplay glyphs, skeletons, pumpkin and coast.
t=(s/'game.s').read_text()
section=t.split('_halloween_tiles:')[1].split('S0007:')[0]
old=bytes(int(v,16) for v in re.findall(r'\$([0-9A-Fa-f]{2})',section));font[136*8:136*8+len(old)]=old
coast=bytes(map(int,re.search(r'flight_coast_font: .byte ([0-9,]+)',t)[1].split(',')));font[160*8:180*8]=coast
for tile,code in lookup.items():font[code*8:(code+1)*8]=tile
# Draw the whole coast before splitting it into native tiles. Small repeated
# dash pairs read as type; a long shoreline and widely spaced curves do not.
# All 40 cells in a sea row share a colour, preserving the fast scroll path.
coast_image=Image.new('1',(320,64));cd=ImageDraw.Draw(coast_image)
# Sand: just a few irregular, shallow contours, with room for actors/bones.
for start,length,y in [(23,28,13),(111,43,11),(221,34,15),(278,25,12)]:
 points=[(x,y+round(1.5*math.sin((x-start)*math.pi/length))) for x in range(start,start+length)]
 cd.line(points,fill=1)
# Yellow sand curves down over the blue sea in the first water row.
for x in range(320):
 edge=27+round(1.6*math.sin(2*math.pi*x/80)+.6*math.sin(2*math.pi*x/40))
 cd.line((x,24,x,edge),fill=1)
# One foam contour follows the shore; the open sea has longer, quieter swells.
for x in range(320):
 y=34+round(1.2*math.sin(2*math.pi*x/80+.6))
 cd.point((x,y),fill=1)
for start,length,y,amplitude in [(8,55,43,1),(156,68,44,1),(71,76,54,1),(254,59,53,1)]:
 points=[(x,y+round(amplitude*math.sin((x-start)*math.pi/length))) for x in range(start,start+length)]
 cd.line(points,fill=1)
coast_slots=list(range(160,180))+available[len(glyphs):]
coast_lookup={bytes(8):32};coast_map=bytearray();coast_colors=bytearray()
row_colors=[7,8,8,7,3,14,14,14]
for row in range(8):
 for col in range(40):
  tile=bytes(sum(int(coast_image.getpixel((col*8+x,row*8+y)))<<(7-x) for x in range(8)) for y in range(8))
  if tile not in coast_lookup:
   index=len(coast_lookup)-1
   assert index<len(coast_slots),('coast glyph budget',index,len(coast_slots))
   code=coast_slots[index];coast_lookup[tile]=code
   font[code*8:(code+1)*8]=tile
  coast_map.append(coast_lookup[tile]);coast_colors.append(row_colors[row])
(s/'coast-map.bin').write_bytes(coast_map+coast_colors)
(s/'palm-font.bin').write_bytes(font[512:]);(s/'palm-font.pak').write_bytes(pack(bytes(font[512:])))
for name,data in [('flight-map.bin',screen),('flight-colors.bin',colors),('flight-background.bin',screen+colors)]: (s/name).write_bytes(data)
(s/'flight-background.pak').write_bytes(pack(bytes(screen+colors)))
(s/'world-packed.pak').write_bytes(pack((s/'world-packed.bin').read_bytes()))
(s/'palm-layout.json').write_text(json.dumps({'glyphs':len(glyphs),'native_dimensions':[640,104],'hires_colors_per_cell':2,'trees':placements,'concept':'approved pink palm coast'},indent=2))
print('Palm glyphs',len(glyphs),'coast glyphs',len(coast_lookup)-1,'font bytes',len(pack(bytes(font[512:]))),'map bytes',len(pack(bytes(screen+colors))),'cave map',len(pack((s/'world-packed.bin').read_bytes())))
