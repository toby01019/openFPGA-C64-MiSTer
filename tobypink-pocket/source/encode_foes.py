"""Shared row dictionary for the approved native opponent art."""
from pathlib import Path
s=Path(__file__).resolve().parent
raw=(s/'opponent-review.bin').read_bytes();rows=[];ids={}
def rowids(data):
 result=[]
 for at in range(0,len(data),3):
  row=data[at:at+3]
  if row not in ids:ids[row]=len(rows);rows.append(row)
  result.append(ids[row])
 return bytes(result)
heads=[];bodies=[]
for kind in range(2):
 for left in range(2):
  frames=[]
  for phase in range(9):
   at=(kind*18+left*9+phase)*128
   frame=raw[at:at+63]+raw[at+64:at+94]
   # Lower clothes use the VIC's shared grey, keeping the approved shape
   # while avoiding colour-register changes through the middle of a person.
   # Hats/coats and natural skin retain their approved individual colours.
   frame=frame[:63]+bytes(sum((1 if ((v>>shift)&3)==2 else ((v>>shift)&3))<<shift for shift in (6,4,2,0)) for v in frame[63:])
   frames.append(frame)
  assert all(f[:42]==frames[0][:42] for f in frames)
  heads.append(rowids(frames[0][:42]))
  for phase,f in enumerate(frames):
   if kind==0:bodies.append(rowids(f[42:]))
   else:assert rowids(f[42:])==bodies[left*9+phase]
assert len(rows)<256
lines=['; Generated lossless row dictionary: no recolouring or rescaling.']
for i,data in enumerate(heads):lines.append(f'foe_head{i}: .byte '+','.join(map(str,data)))
for i,data in enumerate(bodies):lines.append(f'foe_body{i}: .byte '+','.join(map(str,data)))
for j in range(3):lines.append(f'foe_row{j}: .byte '+','.join(str(row[j]) for row in rows))
for group,count in [('head',4),('body',18)]:
 for part,op in [('lo','<'),('hi','>')]:lines.append(f'foe_{group}_{part}: .byte '+','.join(f'{op}foe_{group}{i}' for i in range(count)))
(s/'foes-data.inc').write_text('\n'.join(lines)+'\n')
print('Approved opponents:',len(rows),'unique rows;',len(rows)*3+56+306+44,'bytes')
