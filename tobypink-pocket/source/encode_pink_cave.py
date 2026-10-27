"""Pink rock entrance, authored directly in the C64 sprite's four colours."""
from pathlib import Path
s=Path(__file__).resolve().parent
ns={};exec((s/'encode_sprites.py').read_text().split('s=Path(__file__)')[0],ns)
# 0 transparent, 1 pale stone highlight, 2 opaque black mouth, 3 pink rock.
# An uneven rock profile and a few connected facets replace the flat arch.
rows=[
 '000003300000',
 '000033330000',
 '000331333000',
 '003313333000',
 '003333333300',
 '033333333330',
 '033322233330',
 '033222223330',
 '031222223330',
 '031222223330',
 '333222223330',
 '333222223333',
 '313222223333',
 '333222223333',
 '333222223313',
 '333222223333',
 '333222223333',
 '333222223333',
 '313222223333',
 '333222223333',
 '333222223333',
]
assert len(rows)==21 and all(len(r)==12 for r in rows)
raw=bytes(sum(int(row[x+i])<<(6-i*2) for i in range(4)) for row in rows for x in (0,4,8))+b'\0'
clips=bytearray()
for shift in range(0,24,2):
 for y in range(21):
  clips.extend(((int.from_bytes(raw[y*3:y*3+3],'big')<<shift)&0xffffff).to_bytes(3,'big'))
 clips.append(0)
clips=bytes(clips)
(s/'pink-cave-clips.bin').write_bytes(clips)
(s/'pink-cave-clips.pak').write_bytes(ns['pack'](clips))
print('Pink cave: 12 native clipping frames,',len(ns['pack'](clips)),'packed bytes')
