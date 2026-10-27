"""Create a new local candidate only after build, timing and regression gates pass."""
from pathlib import Path
import hashlib,json,re,zipfile,os
P=Path(__file__).resolve().parent;V='0.5.0'
GAME=P/'tobypink-pocket'if(P/'tobypink-pocket').is_dir()else P.parent/'tobypink-pocket'
OUT=Path(os.environ.get('C64_PACKAGE_OUT',str(P/'packages'if GAME.parent==P else P.parents[1]/'outputs')));OUT.mkdir(parents=True,exist_ok=True)
PREFIX='Cores/Experimental.C64MiSTer/'
def sha(b):return hashlib.sha256(b).hexdigest()
def text(p):return p.read_text(errors='replace')
def encode(s):return s.replace('\r\n','\n').encode('utf-8')
def archive(path,files):
 assert not path.exists(),f'Refusing to replace {path}'
 with zipfile.ZipFile(path,'w',zipfile.ZIP_DEFLATED)as z:
  for n,b in sorted(files.items()):z.writestr(n,b)
 with zipfile.ZipFile(path)as z:
  assert z.testzip()is None and {n:z.read(n)for n in z.namelist()}==files

assert 'Full Compilation was successful'in text(P/'build.log')
manifest=json.loads(text(P/'build-source-hashes.json'))
for n,h in manifest.items():assert sha((P/n).read_bytes())==h,f'Stale build: {n}'
slacks=[float(v)for v in re.findall(r'Slack\s*:\s*(-?[\d.]+)',text(P/'output_files/pocket.sta.summary'))]
assert len(slacks)>=64 and min(slacks)>=0,slacks
for name in ['video-phase-hold.rpt','video-phase-setup.rpt','remaining-hold.rpt']:
 report=P/name;assert '(0 violated)'in text(report) and '(VIOLATED)'not in text(report)
 assert report.stat().st_mtime>=(P/'output_files/pocket.fit.summary').stat().st_mtime,name
gates={
 'tests/easyflash.log':'PASS EasyFlash:',
 'tests/easyflash-quick.log':'PASS EasyFlash:',
 'tests/easyflash-cpu.log':'PASS EasyFlash actual C64 CPU/VIC',
 'tests/pcm.log':'PASS PCM:',
 'tests/pcm-cpu.log':'PASS full-core PCM:',
 'tests/loader-pcm.log':'PASS optional PCM loader mode 5',
 'tests/sample-memory.log':'PASS shared sample memory',
 'tests/reu-shared.log':'PASS registered-start REU',
 'tests/menu_settings.log':'D81 rejection/1541 retention',
 'tests/cart_top.log':'PASS CRT eject',
 'tests/loader_crt.log':'automatic BASIC recovery',
 'tests/keyboard_pipeline.log':'PASS keyboard pipeline',
 'tests/audio-contract.log':'PASS I2S contract',
 'tests/integration-reu.log':'PASS integrated APF',
}
for n,needle in gates.items():assert needle in text(P/n) and 'FATAL:'not in text(P/n),n
for phase in [0,20,35]:assert 'PASS native keyboard'in text(P/f'tests/native-keyboard-pad2-phase{phase}-pipeline.log')
assert 'PASS compiled TobyPink'in text(GAME/'tests/playback.log')
for name,h in json.loads(text(GAME/'checksums.json')).items():assert sha((GAME/name).read_bytes())==h

de=f'''C64 Pocket {V}-alpha - EasyFlash und TobyPink-Samples

Neue Fassung fuer den Hardwaretest. Diese Aenderungen sind noch nicht
auf einem echten Analogue Pocket getestet. Die bisherige Version bleibt
als Rueckfall erhalten. Bitte nur mit Kopien eigener Spiele testen.

INSTALLATION
Pocket ausschalten und SD sichern. Das ZIP ins Hauptverzeichnis der SD
entpacken und Core-Dateien ersetzen. Vorhandene System-ROMs behalten:
Assets/c64mister/common/basic.bin, characters.bin, kernal.bin und 1541.bin.
System-ROMs sind nicht im Paket enthalten. Im Pocket {V}-alpha pruefen.
Die Menues sind Englisch; diese Anleitung gibt es auch auf Englisch.

TOBYPINK MIT DEN ZUSAETZLICHEN DIGITALEN SAMPLES
Die angepasste Pocket-Diskette liegt unter:
Assets/c64mister/common/Games/TobyPink-Pocket-V027.d64
Die Samplebank liegt bereits an der richtigen Stelle:
Assets/c64mister/common/V027-AUDIO.REU
Sie ist kein Startprogramm und wird beim Oeffnen des Cores geladen.
Der Ultimate-Pfad /SD/Spiele/Toby Try to Save the Pink wird hier nicht benutzt.

1. Vor dem Spielstart REU auf 512 KiB und Ultimate Audio (TobyPink)
   auf On (2 voices) stellen. Joystick port 2 verwenden.
2. Ueber Load Disk 8 die neue TobyPink-Pocket-V027.d64 einlegen.
3. Bildschirmtastatur mit Y oeffnen, LOAD* mit A ausloesen; danach
   gegebenenfalls RUN. Das erste Programm ist TOBY TITLE.
4. Im Spiel schiessen und einen Treffer einstecken: Sind die erweiterten
   Effekte sauber zu hoeren? Bleiben Musik und Bild normal?

Zum Vergleich Audio auf Off stellen, Reset Core ausloesen und das Spiel
neu laden. Audio-Einstellungen bitte vor dem Spielstart waehlen; nach
einer Aenderung das Spiel neu starten. Fehlt die Bank, bleibt der normale
SID-Ton. Nach dem Kopieren einer fehlenden Bank den Core ganz neu oeffnen.
Die urspruengliche Ultimate-Version wird durch diese Pocket-Ausgabe nicht
ersetzt. Die Sounds verwenden dieselbe V027-Samplebank.

CAREN / EASYFLASH
Eigene EasyFlash-CRT ueber Load Cartridge auswaehlen. Caren ist nicht
beigelegt. Bitte pruefen, ob es startet und nachlaedt. Ein abgewiesenes
oder beschaedigtes Modul soll wieder zu BASIC fuehren und den Core nicht
festhalten. EasyFlash-Schreib-/Loeschaenderungen bleiben nur bis zum
erneuten Laden des Moduls bzw. Beenden des Cores erhalten; kein CRT-Speichern.

BEIBEHALTEN / GEANDERT
1541-Laufwerke 8 und 9 mit D64/G64, REU, Reset Core, SID-Auswahl,
Paletten und die Bildschirmtastatur mit LOAD*, Shift-Zeichen und
umschaltbarer Transparenz bleiben enthalten. D81/1581 ist in dieser
Fassung entfernt, um Platz fuer EasyFlash und Audiowiedergabe zu schaffen.
Alte gespeicherte 1581-Einstellungen werden auf Off gesetzt.

Bitte kurz zurueckmelden: Pocket-Firmware, Spiel/Datei, Bild und Ton okay?
Bei einem Fehler genuegen die Schritte bis dorthin und ein Foto/kurzes Video.
'''
en=f'''C64 Pocket {V}-alpha - EasyFlash and TobyPink samples

New hardware-test candidate. These changes have not yet been tested on a
real Analogue Pocket. Keep the previous release as a fallback and use copies.

INSTALL
Power off, back up the SD, extract the ZIP into its root and replace core
files. Keep your existing basic.bin, characters.bin, kernal.bin and 1541.bin
in Assets/c64mister/common/. System ROMs are not included. Check {V}-alpha.
Menus are English; both English and German instructions are included.

TOBYPINK DIGITAL SAMPLES
Use Assets/c64mister/common/Games/TobyPink-Pocket-V027.d64.
The bank is already at Assets/c64mister/common/V027-AUDIO.REU.
It is sample data, not a program. The core preloads it when opened; the
Ultimate's /SD/Spiele/Toby Try to Save the Pink path is not used on Pocket.

1. Before starting the game, select REU 512 KiB, Ultimate Audio (TobyPink)
   On (2 voices), and joystick port 2.
2. Insert TobyPink-Pocket-V027.d64 using Load Disk 8.
3. Open the keyboard with Y, select LOAD* with A, then RUN if required.
   The first program is TOBY TITLE.
4. Fire and take a hit. Are the enhanced effects clear, with normal music
   and picture? To compare, select Audio Off, Reset Core and reload the game.

Choose audio settings before starting; restart the game after changing them.
A missing bank falls back to SID sound. Reopen the entire core after adding
a missing bank. The original Ultimate edition is preserved; this Pocket
edition uses the same V027 sample data.

EASYFLASH / CAREN
Select your own EasyFlash CRT with Load Cartridge. Caren is not included.
Check that it starts and loads further content. Rejected/malformed modules
should return to BASIC instead of leaving the core stuck. Flash writes and
erases are volatile: reloading the CRT or closing the core loses changes.
Saving modified CRTs back to SD is not implemented.

RETAINED / CHANGED
1541 drives 8/9 with D64/G64, REU, Reset Core, SID models, palettes and the
keyboard's LOAD*, Shift labels and transparency are retained. D81/1581 is
removed in this build to make room for EasyFlash and PCM playback. Old
persisted 1581 mode settings safely map to Off.

Please report firmware version, file/game and whether picture/sound work.
For failures, short reproduction steps and a photo/video are sufficient.
'''
fit=text(P/'output_files/pocket.fit.summary')
notes=f'''C64 Pocket {V}-alpha - hardware-test release

EasyFlash type32: 64 banks, 1MiB ROM in independent cram1, mode/bank regs,
256B IO2 RAM and two AM29F040 flash command engines. REU remains on cram0.
Flash modifications are volatile. Unsupported/bad CRTs detach and reboot
to BASIC after draining the mailbox and clearing all 64KiB RAM; error retained.

TobyPink PCM: two signed little-endian 16-bit one-shot voices, rate divider
6.25MHz/rate, volume/pan and saturated SID mix. This is a compatible subset
of Ultimate Audio's voice registers, not full Ultimate emulation: no seven-
voice playback, loops, interrupts or Ultimate host filesystem commands.
DF18..1B identify the Pocket extension and report a completely loaded bank.
An optional asset205 preloads the raw bank before an optional startup CRT.
Missing/invalid/failed banks do not prevent a normal C64 boot. Physical
memory writes drain before bank-ready is published. REU/PCM/upload share
cram0 through fair arbitration supporting registered-start REU requests.
Global reset invalidates bank metadata; Reset Core stops voices and retains
the bank. The adapted game preserves its original Ultimate code path.

D81/1581 is disabled by user request; second 1541 drive remains. Colour RAM
is explicitly mapped to M10K to avoid a large automatic LUT expansion.
Keyboard font uses a synchronous ROM with unchanged four-clock pipeline;
1,263,704 pixel comparisons and native output at 3 phases remain exact.

Validation: complete local Caren CRT payload mapped byte-identically into
1MiB physical PSRAM including erased holes, all64banks/byte lanes/CPU+VIC
reads, both flash IDs, NOR programming, erase isolation and reset/eject.
Separate actual C64 CPU/VIC test checks Ultimax reset/bootstrap, bank/mode
switching, IO2 RAM and real bus read deadlines against physical PSRAM pins.
Compiled TobyPink initialization and shot/scream routines execute on the
MiSTer T65, programming PCM and producing exact V027 sample words.
Bank loader errors/order, physical preload, mixed REU traffic, registered
REU DMA roundtrip/swap/verify/wrap, legacy carts, keyboard, menu and I2S
contract tests pass. Full C64 integration additionally checks the REU,
joystick/CIA/keyboard, PAL video and SID/I2S. These are simulations, not
proof that every game or cartridge works on real hardware.
No Caren or Sherwood game files or Commodore system ROMs are redistributed.
Sherwood was removed from the downloadable package by user request.

Timing: {len(slacks)} STA summary checks, minimum slack {min(slacks):.3f}ns;
additional video setup/hold and remaining hold reports have zero violations.
These cover constrained clock paths; asynchronous PSRAM is additionally
checked against the 70ns pin model. Real board validation remains required.

Primary interface references:
https://skoe.de/easyflash/files/devdocs/EasyFlash-ProgRef.pdf
https://1541ultimate.net/content/download/ultimate_audio_v0.2.pdf

{fit}
'''
base=next((x for x in [OUT/'C64-Pocket-0.4.8-Test-SD-EN.zip',OUT/'Archiv/0.4.8/C64-Pocket-0.4.8-Test-SD-EN.zip']if x.exists()),None)
if base:
 with zipfile.ZipFile(base)as z:sd={n:z.read(n)for n in z.namelist()}
else:sd={p.relative_to(P/'dist').as_posix():p.read_bytes()for p in(P/'dist').rglob('*')if p.is_file()}
sd={n:b for n,b in sd.items()if not n.startswith('Assets/c64mister/common/Games/TobyPink-V027/')and 'sherwood'not in n.lower()}
for n in ['data.json','interact.json']:
 sd[PREFIX+n]=(P/'dist'/PREFIX/n).read_bytes()
meta=json.loads(sd[PREFIX+'core.json']);meta['core']['metadata']['version']=V+'-alpha';sd[PREFIX+'core.json']=encode(json.dumps(meta,indent=2)+'\n')
bits=(P/'output_files/pocket.rbf').read_bytes();assert len(bits)>100000
sd[PREFIX+'bitstream.rbf_r']=bits.translate(bytes(int(f'{x:08b}'[::-1],2)for x in range(256)))
sd['Assets/c64mister/common/Games/TobyPink-Pocket-V027.d64']=(GAME/'TobyPink-Pocket-V027.d64').read_bytes()
sd['Assets/c64mister/common/V027-AUDIO.REU']=(GAME/'V027-AUDIO.REU').read_bytes()
for n in ['README-DE.txt','ZUERST-LESEN-DE.txt','SPIELE-START-DE.txt']:sd[n]=encode(de)
for n in ['README.txt','READ-FIRST.txt','GAME-START.txt']:sd[n]=encode(en)
sd['VERSION.txt']=encode(V+'-alpha\n');sd['RELEASE-NOTES.txt']=encode(notes)
assert all('d81'not in x.get('extensions',[])for x in json.loads(sd[PREFIX+'data.json'])['data']['data_slots'])
assert all(x['id']!=204 for x in json.loads(sd[PREFIX+'data.json'])['data']['data_slots'])
assert not any('sherwood'in n.lower()or 'caren'in n.lower()for n in sd)

source={}
allowed={'.v','.sv','.vh','.vhd','.qip','.sdc','.hex','.mif','.py','.txt','.md','.qsf','.qpf','.qdf','.tcl','.vpart'}
for directory in ['apf','core','rtl']:
 for p in(P/directory).rglob('*'):
  if p.is_file()and p.suffix.lower()in allowed:source[p.relative_to(P).as_posix()]=p.read_bytes()
for p in(P/'tests').glob('*'):
 if p.is_file()and p.suffix.lower()in {'.sv','.py'}and 'sherwood'not in p.name.lower():source[p.relative_to(P).as_posix()]=p.read_bytes()
for name in ['menu_palette_expected.hex','review_vkb_pixels.hex']:
 source['tests/'+name]=(P/'tests'/name).read_bytes()
for p in(P/'tests').glob('*.log'):
 if p.name in {Path(n).name for n in gates}|{'native-keyboard-pad2-phase0-pipeline.log','native-keyboard-pad2-phase20-pipeline.log','native-keyboard-pad2-phase35-pipeline.log'}:
  source[p.relative_to(P).as_posix()]=p.read_bytes()
for p in P.glob('*'):
 if p.is_file()and(p.name in ['build.py','build-source-hashes.json','build.log','package_easyflash_audio.py']or p.suffix in {'.qsf','.qpf','.qdf','.tcl','.vpart'}):source[p.name]=p.read_bytes()
for n in ['pocket.fit.summary','pocket.sta.summary','pocket.fit.rpt','pocket.sta.rpt']:
 source['output_files/'+n]=(P/'output_files'/n).read_bytes()
for n in ['video-phase-hold.rpt','video-phase-setup.rpt','remaining-hold.rpt']:source[n]=(P/n).read_bytes()
for n,b in sd.items():
 if (n.startswith(PREFIX)and not n.endswith('bitstream.rbf_r'))or n.startswith('Platforms/')or n=='Assets/c64mister/common/pocket-test.prg':source['dist/'+n]=b
for p in GAME.rglob('*'):
 if not p.is_file()or 'build'in p.relative_to(GAME).parts or 'tests'in p.relative_to(GAME).parts:continue
 if p.suffix=='.prg'and p.parent==GAME:continue
 if p.parent==GAME and(p.name.endswith('.d64')or p.name=='V027-AUDIO.REU'):continue
 source['tobypink-pocket/'+p.relative_to(GAME).as_posix()]=p.read_bytes()
for n in ['audio-init.log','playback.log']:source['tobypink-pocket/tests/'+n]=(GAME/'tests'/n).read_bytes()
source['README-DE.txt']=encode(de);source['README.txt']=encode(en);source['RELEASE-NOTES.txt']=encode(notes)
source['VALIDATION.txt']=encode('Source archive excludes private game/ROM fixtures. CAREN_CRT may point to your own Caren CRT for run_easyflash.py; --quick uses an original synthetic fixture. GHDL conversion tools and Icarus/Quartus must be installed separately. Source includes the disabled 1581 code for future work. C64 ROMs are not included.\nGame rebuild: run tobypink-pocket/source/build.ps1 with -Toolchain pointing to cc65. Set C1541 to the VICE c1541 executable, then run tobypink-pocket/make_disk.py. The resources folder includes the original reward PRGs and V027 bank. Run tests/run_pcm.py before the PCM memory/game tests to create their bank fixture.\n')
assert not any('private-caren'in n or n.endswith(('kernal.bin','basic.bin','characters.bin','1541.bin','1581.bin'))for n in source)
for n,h in manifest.items():assert n in source and sha(source[n])==h,n
checks={}
for suffix,files in [('Test-SD-EN.zip',sd),('Source-EN.zip',source)]:
 path=OUT/f'C64-Pocket-{V}-{suffix}';archive(path,files);checks[path.name]=sha(path.read_bytes())
for name,body in [('ZUERST-LESEN-DE.txt',de),('Read-First-EN.txt',en),('Release-Notes-EN.txt',notes)]:
 (OUT/f'C64-Pocket-{V}-{name}').write_bytes(encode(body))
(OUT/f'C64-Pocket-{V}-Checksums.sha256').write_text(''.join(f'{h}  {n}\n'for n,h in checks.items()))
print(json.dumps(checks,indent=2))
