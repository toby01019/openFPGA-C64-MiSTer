"""Prepare a local test package only after build, timing and regression gates."""
from pathlib import Path
import hashlib,json,re,zipfile
from core_identity import convert,CORE_ID
P=Path(__file__).resolve().parent
BASE=P.parents[1]/'outputs/0.5.1-release'
OUT=P.parents[1]/'outputs/0.5.2-renamed-candidate'
PREFIX='Cores/Experimental.C64MiSTer/'
def text(f):return f.read_text(encoding='utf8',errors='replace')
def sha(b):return hashlib.sha256(b).hexdigest()
assert 'Full Compilation was successful' in text(P/'build.log')
manifest=json.loads(text(P/'build-source-hashes.json'))
for n,h in manifest.items():assert sha((P/n).read_bytes())==h,'Stale build: '+n
slacks=[float(v) for v in re.findall(r'Slack\s*:\s*(-?[\d.]+)',text(P/'output_files/pocket.sta.summary'))]
assert len(slacks)>=64 and min(slacks)>=0,slacks
for n in ['video-phase-hold.rpt','video-phase-setup.rpt','remaining-hold.rpt']:
 f=P/n
 assert '(0 violated)' in text(f) and '(VIOLATED)' not in text(f),n
 assert f.stat().st_mtime>=(P/'output_files/pocket.fit.summary').stat().st_mtime,n
gates={'autostart.log':'PASS autostart','autostart_cpu.log':'PASS actual 6510',
 'activity.log':'PASS activity','menu_settings.log':'PASS menu bridge',
 'keyboard_pipeline.log':'PASS keyboard pipeline','integration-dock.log':'PASS integrated Dock USB keyboard',
 'autostart-regressions.log':'ALL REGRESSIONS PASS'}
for n,needle in gates.items():
 s=text(P/'tests'/n);assert needle in s and 'FATAL:' not in s,n
def readzip(name):
 with zipfile.ZipFile(BASE/name) as z:return {n:z.read(n) for n in z.namelist() if not n.endswith('/')}
sd=readzip('C64-Pocket-0.5.1-Test-SD-EN.zip')
source=readzip('C64-Pocket-0.5.1-Source-EN.zip')
# Preserve earlier test evidence under an explicitly historical directory.
for n in list(source):
 if n.startswith('tests/') and n.endswith('.log') and not (P/n).exists():
  source['validation-0.5.1/'+n]=source.pop(n)
en=text(P/'AUTOSTART-EN.txt');de=text(P/'AUTOSTART-DE.txt')
install_en='\nInstallation: back up the SD card, power off, extract to its root and merge folders. Keep your own system ROMs in Assets/c64mister/common/. Keep 0.5.1 as fallback.\n'
install_de='\nInstallation: SD sichern, Pocket ausschalten, ins SD-Hauptverzeichnis entpacken und Ordner zusammenfuehren. Eigene System-ROMs in Assets/c64mister/common/ behalten. 0.5.1 als Rueckfall behalten.\n'
notes=en+'\n'+text(P/'output_files/pocket.fit.summary')+f'\nMinimum timing slack: {min(slacks)} ns.\n'
for files in [sd,source]:
 for n in ['HARDWARE-TEST-STATUS-EN.txt','HARDWARE-TEST-STATUS-DE.txt']:
  if n in files:files[n.replace('STATUS-','STATUS-0.5.1-')]=files.pop(n)
 files['HARDWARE-TEST-STATUS-EN.txt']=b'0.5.2-alpha: NOT hardware tested. Earlier 0.5.1 hardware feedback does not validate this changed FPGA build.\n'
 files['HARDWARE-TEST-STATUS-DE.txt']=b'0.5.2-alpha: Noch nicht auf Hardware getestet. Die Rueckmeldungen zu 0.5.1 gelten nicht als Hardwaretest dieses geaenderten FPGA-Baus.\n'
 for n in ['README.txt','READ-FIRST.txt']:files[n]=(en+install_en).encode()
 for n in ['README-DE.txt','ZUERST-LESEN-DE.txt']:files[n]=(de+install_de).encode()
 for n in ['AUTOSTART-EN.txt','AUTOSTART-DE.txt']:files[n]=(P/n).read_bytes()
 files['GAME-START.txt']=(en+'\nTobyPink: enable REU 512 KiB and Ultimate Audio (2 voices) before starting. Select TobyPink-Pocket-V027.d64 in Disk 8. First program: TOBY TITLE. V027-AUDIO.REU is sample data, not a start program.\n').encode()
 files['SPIELE-START-DE.txt']=(de+'\nTobyPink: Vor dem Start REU 512 KiB und Ultimate Audio (2 voices) einschalten. TobyPink-Pocket-V027.d64 in Disk 8 auswaehlen. Erstes Programm: TOBY TITLE. V027-AUDIO.REU ist eine Samplebank, kein Startprogramm.\n').encode()
 files['VERSION.txt']=b'0.5.2-alpha\n';files['RELEASE-NOTES.txt']=notes.encode()
meta=json.loads(sd[PREFIX+'core.json']);meta['core']['metadata'].update(version='0.5.2-alpha',date_release='2026-10-27',description='C64 Alpha: disk autostart, activity, EasyFlash and Dock keyboard')
metadata=(json.dumps(meta,indent=2)+'\n').encode()
sd[PREFIX+'core.json']=metadata
sd[PREFIX+'interact.json']=(P/'dist'/'Cores'/CORE_ID/'interact.json').read_bytes()
bits=(P/'output_files/pocket.rbf').read_bytes();assert len(bits)>100000
# Pocket rbf_r reverses bits within each byte (same conversion as 0.5.1).
reverse=bytes(int(f'{x:08b}'[::-1],2) for x in range(256))
sd[PREFIX+'bitstream.rbf_r']=bits.translate(reverse)
assert sd[PREFIX+'bitstream.rbf_r'].translate(reverse)==bits
for n in list(source):
 if (n.startswith(('core/','rtl/','apf/','tests/','output_files/')) or n.endswith('.rpt') or n in ['pocket.qsf','build.log','build-source-hashes.json']) and (P/n).is_file():
  source[n]=(P/n).read_bytes()
for n in ['core/pocket_autostart.sv','tests/run_autostart.py','tests/tb_autostart.sv','tests/run_autostart_cpu.py','tests/run_activity.py','AUTOSTART-IMPLEMENTATION.txt','package_autostart.py']:
 source[n]=(P/n).read_bytes()
for n in ['core_identity.py','MIGRATION-EN.txt','MIGRATION-DE.txt','UPDATERS.md']:
 source[n]=(P/n).read_bytes()
for n in gates:source['tests/'+n]=(P/'tests'/n).read_bytes()
source['dist/'+PREFIX+'core.json']=metadata
source['dist/'+PREFIX+'interact.json']=sd[PREFIX+'interact.json']
source['VALIDATION.txt']=(f'0.5.2-alpha local checks passed; minimum slack {min(slacks)} ns.\nReal Pocket test pending. See AUTOSTART-IMPLEMENTATION.txt and tests/*.log.\n').encode()
# Old README.md remains as the upstream project overview, with a prominent update.
if 'README.md' in source:source['README.md']=b'> Local 0.5.2-alpha test build: see AUTOSTART-EN.txt. Not hardware tested.\n\n'+source['README.md']
sd=convert(sd);source=convert(source)
for files in [sd,source]:
 for n in ['MIGRATION-EN.txt','MIGRATION-DE.txt','UPDATERS.md']:files[n]=(P/n).read_bytes()
 if 'UPDATER-VALIDATION.md' in files:
  files['UPDATER-VALIDATION.md']=b'> Historical 0.5.1 validation only. This does not validate the renamed 0.5.2 package. See UPDATERS.md.\n\n'+files['UPDATER-VALIDATION.md']
 for n in ['README.txt','READ-FIRST.txt']:
  files[n]=b'New core ID: toby01019.C64. Existing users MUST read MIGRATION-EN.txt before installing.\n\n'+files[n]
 for n in ['README-DE.txt','ZUERST-LESEN-DE.txt']:
  files[n]=b'Neue Kennung: toby01019.C64. Bestehende Nutzer: vor Installation MIGRATION-DE.txt lesen.\n\n'+files[n]
OUT.mkdir(exist_ok=True)
written=[]
for suffix,files in [('Test-SD-EN',sd),('Source',source)]:
 dest=OUT/f'C64-Pocket-0.5.2-{suffix}.zip'
 assert not dest.exists(),dest
 for n in files:
  assert not any(x in n.lower() for x in ['sherwood','caren.crt']),n
  assert not n.lower().endswith(('basic.bin','kernal.bin','characters.bin','1541.bin')),n
 with zipfile.ZipFile(dest,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as z:
  for n,b in sorted(files.items()):z.writestr(n,b)
 with zipfile.ZipFile(dest) as z:assert z.testzip() is None
 written.append(dest)
for n,b in [('C64-Pocket-0.5.2-Read-First-EN.txt',(en+install_en).encode()),('C64-Pocket-0.5.2-ZUERST-LESEN-DE.txt',(de+install_de).encode())]:
 f=OUT/n;f.write_bytes(b.replace(b'Assets/c64mister/',b'Assets/c64/')+b'\nExisting users / Bestehende Nutzer: MIGRATION-EN.txt / MIGRATION-DE.txt im ZIP lesen.\n');written.append(f)
(OUT/'SHA256SUMS.txt').write_text(''.join(f'{sha(f.read_bytes())}  {f.name}\n' for f in written))
print('Local test packages validated:',OUT)
