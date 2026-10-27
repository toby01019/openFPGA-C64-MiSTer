"""Compile the exact recorded sources; QUARTUS_BIN may override local tools."""
from pathlib import Path
import hashlib,json,os,subprocess
P=Path(__file__).resolve().parent
B=Path(os.environ.get('QUARTUS_BIN','C:/Users/toby0/Documents/Codex/tools/quartus25/quartus/bin64'))
files=[f for folder in ['apf','core','rtl'] for f in (P/folder).rglob('*')
       if f.is_file() and f.suffix.lower() in ['.v','.sv','.vh','.vhd','.qip','.sdc','.hex','.mif']]
files+=list(P.glob('*.qsf'))+list(P.glob('*.qpf'))
manifest={str(f.relative_to(P)).replace('\\','/'):hashlib.sha256(f.read_bytes()).hexdigest()
          for f in sorted(files) if f.suffix.lower()!='.mif'}
(P/'build-source-hashes.json').write_text(json.dumps(manifest,indent=2)+'\n')
with (P/'build.log').open('w') as out:
    r=subprocess.run([str(B/'quartus_sh.exe'),'--flow','compile','pocket'],cwd=P,stdout=out,stderr=subprocess.STDOUT)
print((P/'build.log').read_text()[-1600:])
assert r.returncode==0
