"""Optimal bounded LZ blocks for the native 6510 sprite decoder."""
from pathlib import Path
from collections import defaultdict

def pack(data):
 n=len(data)
 seen=defaultdict(list);matches=[]
 for i in range(n):
  best=(0,0);key=data[i:i+3]
  for j in reversed(seen[key]):
   if i-j>65535:break
   limit=min(130,n-i);length=3
   while length<limit and data[i+length]==data[j+length]:length+=1
   if length>best[0]:best=length,i-j
   if length==limit:break
  matches.append(best);seen[key].append(i)
 cost=[0]*(n+1);choice=[None]*n
 for i in range(n-1,-1,-1):
  options=[(1+k+cost[i+k],k,0) for k in range(1,min(127,n-i)+1)]
  length,offset=matches[i]
  options += [(3+cost[i+k],k,offset) for k in range(3,min(length,n-i)+1)]
  cost[i],length,offset=min(options);choice[i]=length,offset
 packed=bytearray();i=0
 while i<n:
  length,offset=choice[i]
  if offset:packed.extend([128+length-3,offset&255,offset>>8])
  else:packed.append(length);packed.extend(data[i:i+length])
  i+=length
 packed.append(0)
 decoded=bytearray();i=0
 while packed[i]:
  token=packed[i];i+=1
  if token<128:decoded.extend(packed[i:i+token]);i+=token
  else:
   distance=int.from_bytes(packed[i:i+2],'little');i+=2
   for _ in range((token&127)+3):decoded.append(decoded[-distance])
 assert decoded==data
 return bytes(packed)

s=Path(__file__).resolve().parent
raw=(s/'sprite-data.bin').read_bytes()
for filename,data in [('sprite-prefix.pak',raw),('walk-planes.pak',raw[5120:7168])]:
 packed=pack(data)
 (s/filename).write_bytes(packed)
 print(f'{filename}: {len(data)} -> {len(packed)} bytes, verified lossless')
