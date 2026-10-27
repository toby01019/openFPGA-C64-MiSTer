"""Independent pixel geometry and per-channel alpha reference, using an RTL dump."""
from pathlib import Path
import ast,re,sys
from PIL import Image,ImageDraw,ImageFont

T=Path(__file__).resolve().parent;P=T.parent
data=[[int(v,16) for v in line.split()]for line in (T/'review_style_pixels.hex').read_text().splitlines()]
assert len(data)==382*270
opaque=set()
def rect(x,y,w,h):opaque.update((xx,yy)for yy in range(y,y+h)for xx in range(x,x+w))
font_source=(P/'core/keyboard_font.vh').read_text()
font={int(a):b for a,b in re.findall(r"8'd(\d+):glyph=35'b([01]+)",font_source)}
def text(s,x,y):
    for i,ch in enumerate(s):
        for n,bit in enumerate(font.get(ord(ch),'0'*35)):
            if bit=='1':opaque.add((x+i*6+n%5,y+n//5))

# Fixed banner geometry and the four restrained rainbow stripes.
text('COMMODORE 64',35,146);text('A KEY X HOLD Y CLEAR B CLOSE',190,146)
rect(18,146,12,6)
layout=(P/'core/keyboard_layout.vh').read_text()
labels={int(a):b.rstrip() for a,b in re.findall(r'7\'d(\d+):key_label="([^"]*)"',layout)}
sys.path.insert(0,str(P))
from keyboard_layout import GEOMETRY
for k,label in labels.items():
    if k==76:continue # Dynamic mode label is checked against its own pixel reference below.
    x,y,w,h,*_=GEOMETRY[k]
    if w<24 and len(label)>3:
        for i,ch in enumerate(label):
            bits=font[ord(ch)]
            for yy,source_row in enumerate((0,1,3,5,6)):
                for xx in range(5):
                    if bits[source_row*5+xx]=='1':opaque.add((x+(w-12)//2+(i%2)*6+xx,y+(8 if i>=2 else 1)+yy))
    else:text(label,x+(w-len(label)*6+1)//2,y+(h-7)//2)
# Selected A, sticky Shift and its LOCK alias stay completely opaque.
for key_id in (30,60,71):rect(*GEOMETRY[key_id][:4])
# Held F1 contact also highlights F2's key combo only if its whole mask is held;
# here F1 alone gets the underline.
x,y,w,h,*_=GEOMETRY[0];rect(x+3,y+h-2,w-6,1)

# Read the original glyph artwork as literals, without calling its rasterizer.
tree=ast.parse((P/'keyboard_style.py').read_text())
values={n.targets[0].id:ast.literal_eval(n.value) for n in tree.body
        if isinstance(n,ast.Assign) and isinstance(n.targets[0],ast.Name)
        and n.targets[0].id=='ENGRAVING_TEXT'}
assert values['ENGRAVING_TEXT']=='Works best with the Callback 8020.'
tiny_node=next(n.value for n in tree.body if isinstance(n,ast.Assign)
               and isinstance(n.targets[0],ast.Name) and n.targets[0].id=='TINY')
tiny={ast.literal_eval(k):(['0000']*6 if isinstance(v,ast.BinOp) else ast.literal_eval(v))
      for k,v in zip(tiny_node.keys,tiny_node.values)}
dark={(i*5+xx,yy) for i,ch in enumerate(values['ENGRAVING_TEXT'])
      for yy,row in enumerate(tiny[ch]) for xx,bit in enumerate(row) if bit=='1'}
light={(x+1,y+1)for x,y in dark}-dark
encoded={int(y):bits for y,bits in re.findall(r"3'd(\d+):engraving_row=340'b([01]+)",
                                         (P/'core/keyboard_engraving.vh').read_text())}
for y in range(7):
    for x in range(170):
        expected=1 if(x,y)in dark else 2 if(x,y)in light else 0
        assert int(encoded[y][x*2:x*2+2],2)==expected,('engraving source mismatch',x,y)
        if expected:
            opaque.add((x+106,y+260))
            expected_color=0x8a795f if expected==1 else 0xeee2c3
            assert all(v==expected_color for v in data[(y+260)*382+x+106][1:]),('engraving RTL mismatch',x,y)

def blend(fg,bg,mode):
    channels=[]
    for shift in (16,8,0):
        f,b=(fg>>shift)&255,(bg>>shift)&255
        channels.append((3*f+b)//4 if mode==1 else (f+b)//2)
    return (channels[0]<<16)|(channels[1]<<8)|channels[2]

# The UI-only key has different glyphs in each transparency mode.
# Build independent masks; do not compare TR OFF ink with TR 25%/TR 50% ink.
tx,ty,tw,th,*_=GEOMETRY[76]
mode_ink=[]
for label in ('TR OFF','TR 25%','TR 50%'):
    points=set()
    for i,ch in enumerate(label):
        for n,bit in enumerate(font[ord(ch)]):
            if bit=='1':points.add((tx+(tw-35)//2+i*6+n%5,ty+(th-7)//2+n//5))
    mode_ink.append(points)

for index,(bg,base,a25,a50) in enumerate(data):
    x,y=index%382,index//382
    inside=8<=x<374 and 140<=y<270
    if not inside:
        assert bg==base==a25==a50,('outside panel changed',x,y)
    elif tx<=x<tx+tw and ty<=y<ty+th:
        for mode,actual in enumerate((base,a25,a50)):
            if (x,y)in mode_ink[mode]:expected=0xf3ead0
            else:
                fg=0x7b6b58
                if y==ty+th-1:fg=0x2f2721
                if x in (tx,tx+tw-1) or y==ty:fg=0x9b8a70
                expected=fg if mode==0 else blend(fg,bg,mode)
            assert actual==expected,('transparency-key mode glyph/background',mode,x,y,hex(actual),hex(expected))
    elif (x,y)in opaque:
        assert base==a25==a50,('ink/marking faded',x,y)
    else:
        assert a25==blend(base,bg,1),('25% blend mismatch',x,y,hex(a25),hex(blend(base,bg,1)))
        assert a50==blend(base,bg,2),('50% blend mismatch',x,y)

# A labeled comparison; synthetic color ramps are intentionally recognizable.
scale=2;gap=24;header=62;w=382*scale;h=270*scale
canvas=Image.new('RGB',(w*3+gap*4,h+header+gap),(242,239,230))
draw=ImageDraw.Draw(canvas)
try:label_font=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',22)
except OSError:label_font=ImageFont.load_default()
for column,label in enumerate(['Opaque','25 % transparent','50 % transparent']):
    im=Image.new('RGB',(382,270));im.putdata([tuple((v[column+1]>>s)&255 for s in (16,8,0))for v in data])
    left=gap+column*(w+gap)
    draw.text((left,8),label,fill=(51,41,32),font=label_font)
    draw.text((left,34),'RTL simulation, synthetic background',fill=(89,77,61),font=label_font)
    canvas.paste(im.resize((w,h),Image.Resampling.NEAREST),(left,header))
out=P.parents[1]/'outputs/C64-Pocket-Retro-Transparenz.png'
canvas.save(out)
message='PASS independent style pixels: exact mixed-case engraving and bevel, opaque glyphs/selection/sticky/rainbow, per-channel rounded alpha, no RGB carry, untouched outside 130-line panel'
(T/'review_style_check.log').write_text(message+'\n')
print(message);print(out)
