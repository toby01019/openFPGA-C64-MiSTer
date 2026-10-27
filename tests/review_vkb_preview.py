from pathlib import Path
from PIL import Image
import re,sys

T=Path(__file__).resolve().parent
source=(T.parent/'core/pocket_keyboard_video.sv').read_text()
banner_assignments=re.findall(r'\bbanner\s*=([^;]*);',source)
for assignment in banner_assignments:
    for banner in re.findall(r'"([^"\n]*)"',assignment):
        assert len(banner)==32, f'banner must occupy exactly 32 bytes: {banner!r}'
pixels=[int(line.strip(),16) for line in (T/'review_vkb_pixels.hex').read_text().splitlines()]
assert len(pixels)==382*270
def at(x,y):return pixels[y*382+x]
assert at(65,191)==0xd8c999, 'selected A not highlighted'
assert at(37,207)==0xc9904f, 'sticky Shift not highlighted'
assert at(19,240)==0x7b6b58, 'Shift incorrectly highlights F2'
assert any(at(x,y)==0x514637 for y in range(146,153) for x in range(190,370)), 'English help missing'
sys.path.insert(0,str(T.parent))
from keyboard_layout import ROWS,FONT,GEOMETRY,DISPLAY_LABELS,LAYOUT_ROWS,SHIFT_LABELS
assert [len(row) for row in LAYOUT_ROWS]==[16,15,15,15,4,2,11]
assert GEOMETRY[39][2]>GEOMETRY[30][2] and GEOMETRY[60][2]>GEOMETRY[40][2]
assert GEOMETRY[63][2]>=200
assert [GEOMETRY[i][0] for i in (0,2,4,6)]==[338]*4
for row,keys in enumerate(ROWS):
    for col,(label,contact) in enumerate(keys):
        key_id=row*10+col
        label='TR OFF' if key_id==76 else SHIFT_LABELS.get(key_id,DISPLAY_LABELS.get(key_id,label))
        mask=0 if contact is None else sum(1<<n for n in (contact if isinstance(contact,tuple) else [contact]))
        selected=key_id==30
        locked=mask!=0 and (mask&0x8000)==mask
        ink=0x3b3028 if selected or locked else 0xf3ead0
        x,y,w,h,*_=GEOMETRY[key_id]
        stacked=w<24 and len(label)>3
        left=x+((w-12)//2 if stacked else (w-len(label)*6+1)//2)
        top=y+(h-7)//2
        for i,ch in enumerate(label):
            rows=[FONT[ch][n] for n in (0,1,3,5,6)] if stacked else FONT[ch]
            for gy,bits in enumerate(rows):
                for gx,bit in enumerate(bits):
                    if bit=='1':
                        px=left+(i%2 if stacked else i)*6+gx
                        py=(y+(8 if i>=2 else 1) if stacked else top)+gy
                        assert at(px,py)==ink, f'clipped key glyph {label!r} at {px},{py}: {at(px,py):06x}'
from keyboard_style import ENGRAVING_TEXT,pixels as engraving_pixels
assert ENGRAVING_TEXT=='Works best with the Callback 8020.'
for y,line in enumerate(engraving_pixels()):
    for x,value in enumerate(line):
        color=[0xc8bfa5,0x8a795f,0xeee2c3][value]
        assert at(106+x,260+y)==color, f'engraving mismatch at {x},{y}'
for y in range(270):
    for x in range(382):
        if x<8 or x>=374 or y<140:
            assert at(x,y)==0x3636a8, f'overlay outside bounds at {x},{y}'
im=Image.new('RGB',(382,270))
im.putdata([((p>>16)&255,(p>>8)&255,p&255) for p in pixels])
im.save(T/'review_vkb_native.png')
out=T.parents[2]/'outputs/C64-Pocket-Tastatur-Retro-Vorschau.png'
out.parent.mkdir(parents=True,exist_ok=True)
im.resize((1528,1080),Image.Resampling.NEAREST).save(out)
print('PASS keyboard pixels: staggered breadbin rows, wide Shift/Return/Space, vertical F keys, 78 unclipped labels including LOAD* and transparency, English help, 140 untouched lines, selection, sticky Shift and exact Callback engraving')
print(out)
