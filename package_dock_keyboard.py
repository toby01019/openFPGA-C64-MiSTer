"""Package the hardware-UNTESTED Dock alpha; never overwrite existing files."""
from pathlib import Path
import hashlib,json,os,re,zipfile
P=Path(__file__).resolve().parent
BASE=Path(os.environ.get('C64_BASE_RELEASE',str(P.parents[1]/'outputs')))
OUT=Path(os.environ.get('C64_PACKAGE_OUT',str(P.parents[1]/'outputs')))
PREFIX='Cores/Experimental.C64MiSTer/'
V='0.5.1'
def sha(b):return hashlib.sha256(b).hexdigest()
def text(f):return f.read_text(encoding='utf-8',errors='replace')
assert 'Full Compilation was successful' in text(P/'build.log')
manifest=json.loads(text(P/'build-source-hashes.json'))
for n,h in manifest.items():assert sha((P/n).read_bytes())==h,'Stale build: '+n
slacks=[float(v)for v in re.findall(r'Slack\s*:\s*(-?[\d.]+)',text(P/'output_files/pocket.sta.summary'))]
assert len(slacks)>=64 and min(slacks)>=0,slacks
for n in ['video-phase-hold.rpt','video-phase-setup.rpt','remaining-hold.rpt']:
    f=P/n
    assert '(0 violated)'in text(f) and '(VIOLATED)'not in text(f),n
    assert f.stat().st_mtime>=(P/'output_files/pocket.fit.summary').stat().st_mtime,n
gates={'dock-keyboard.log':'PASS Dock keyboard','dock-pad.log':'PASS real PAD',
       'integration-dock.log':'PASS integrated Dock USB keyboard',
       'menu_settings.log':'PASS menu bridge','easyflash-cpu.log':'PASS EasyFlash actual',
       'pcm-cpu.log':'PASS full-core PCM','keyboard.log':'PASS virtual keyboard',
       'keyboard_pipeline.log':'PASS keyboard pipeline'}
for n,needle in gates.items():assert needle in text(P/'tests'/n) and 'FATAL:'not in text(P/'tests'/n),n
def read_zip(n):
    with zipfile.ZipFile(BASE/n)as z:return {i:z.read(i) for i in z.namelist()}
sd=read_zip('C64-Pocket-0.5.0-Test-SD-EN.zip')
source=read_zip('C64-Pocket-0.5.0-Source-EN.zip')
en='''C64 Pocket 0.5.1-alpha - Dock USB keyboard test build

PUBLIC TEST ALPHA: Dock keyboard support and this changed FPGA build have
not yet been tested on real Pocket/Dock hardware. Keep a copy of the
hardware-tested 0.5.0 as a fallback.

Back up the SD, switch off, extract to the SD root and merge folders.
Replace core files; retain your own basic.bin, characters.bin, kernal.bin
and 1541.bin in Assets/c64mister/common/. Check version 0.5.1-alpha.

Use a wired USB HID keyboard through Analogue Dock. Core Settings ->
Dock USB keyboard: On - QWERTY, On - QWERTZ (Y/Z), or Off.
Release all keys after startup, menu close, reset, reconnect or mode change.
Shift legends are C64-style: Shift+2 is a quote and Shift+4 is $.
Escape=RUN/STOP, F12=RESTORE, Ctrl=CTRL, Alt/GUI=Commodore.
See DOCK-KEYBOARD-EN.txt for the complete key table and short hardware test.

Existing features retained: virtual keyboard, LOAD*/RUN, transparency,
joystick, PAL video, SID, D64/G64 drives 8/9, REU, EasyFlash and TobyPink PCM.
D81/1581, mouse, Sleep and savestates are not supported. EasyFlash writes
remain volatile. Keep write protection On and use copies of disk images.

TobyPink: select REU 512 KiB and Ultimate Audio (TobyPink) On (2 voices)
before starting. Load Disk 8 -> TobyPink-Pocket-V027.d64, Y -> LOAD* with A,
then RUN if needed. First program TOBY TITLE. V027-AUDIO.REU is already
in Assets/c64mister/common/ and is sample data, not a boot program.
Restart the game after changing audio settings.
System ROMs, Sherwood and Caren are not included. Own TobyPink is retained.
'''
de='''C64 Pocket 0.5.1-alpha - Testfassung mit Dock-USB-Tastatur

OEFFENTLICHE TEST-ALPHA: Die neue Dock-Tastatur und dieser geaenderte FPGA-Bau
sind noch nicht auf echter Pocket-/Dock-Hardware getestet. Eine Kopie der
hardwaregetesteten 0.5.0 als Rueckfall behalten.

SD sichern, Pocket ausschalten, ZIP ins SD-Hauptverzeichnis entpacken,
Ordner zusammenfuehren und Core-Dateien ersetzen. Eigene System-ROMs in
Assets/c64mister/common/ behalten. Version 0.5.1-alpha pruefen.

Kabelgebundene USB-HID-Tastatur ans Analogue Dock anschliessen.
Core Settings -> Dock USB keyboard: QWERTY, QWERTZ (nur Y/Z) oder Off.
Nach Start, Menue, Reset, Umstecken oder Moduswechsel alle Tasten loslassen.
Es gilt die C64-Belegung: Shift+2 gibt Anfuehrungszeichen, Shift+4 das $.
Escape=RUN/STOP, F12=RESTORE, Ctrl=CTRL, Alt/Windows=Commodore.
Zuordnung und kurzer Hardwaretest: DOCK-KEYBOARD-DE.txt und -EN.txt.

Bildschirmtastatur mit LOAD*/RUN/Transparenz, Joystick, PAL, SID, D64/G64,
1541-Laufwerke 8/9, REU, EasyFlash und TobyPink-Audio bleiben enthalten.
Kein D81/1581, keine Maus, Sleep oder Savestates. EasyFlash-Aenderungen
sind fluechtig. Schreibschutz On lassen und Diskettenkopien verwenden.

TobyPink vor Spielstart: REU 512 KiB, Ultimate Audio (TobyPink) On (2 voices).
Load Disk 8 -> TobyPink-Pocket-V027.d64. Y -> LOAD* mit A, bei Bedarf RUN.
Erstes Programm TOBY TITLE. Die V027-AUDIO.REU liegt bereits richtig in
Assets/c64mister/common/, ist Samplebank und kein Startprogramm.
Nach Audio-Aenderungen das Spiel neu starten.
System-ROMs, Sherwood und Caren fehlen bewusst; eigenes TobyPink liegt bei.
'''
notes='''C64 Pocket 0.5.1-alpha - Public Dock USB keyboard test alpha
Hardware test pending. Keep hardware-tested 0.5.0 as a fallback copy.

Original APF keyboard decoder; no old myc64-pocket implementation imported.
32-bit controller type fields retained through APF. Complete serial PAD
reports publish a strobe; partial reports never publish keyboard state.
Type 4 in Player 3 only. Held-data mailbox provides atomic report CDC.
Byte-swapped APF modifiers, six unordered/duplicate HID usages, C64 contact
matrix, F1-F8/arrow Shift chords, Caps Lock -> Shift Lock, F12 -> RESTORE.
Menu/reset/mode-change/disconnect/error/timeout release keys, then require
a neutral report. QWERTY, Y/Z-only QWERTZ and Off in English Core Settings.
Physical and virtual contacts merge without replacing the existing CIA path.

Changes to APF vendor files are limited to restoring the documented type
width, report publication and clearing stale controller data on timeout.
Other C64/audio/drive/cartridge RTL is unchanged from 0.5.0.
Source includes tests. New Dock hardware behavior remains unverified.

'''+text(P/'output_files/pocket.fit.summary')+'\nTiming minimum slack: '+str(min(slacks))+' ns\n'
def put_docs(files):
    for n in list(files):
        if n.startswith('HARDWARE-TEST-STATUS-'):
            files[n.replace('HARDWARE-TEST-STATUS-','HARDWARE-TEST-STATUS-0.5.0-')]=files.pop(n)
    for n in ['README.txt','READ-FIRST.txt','GAME-START.txt']:files[n]=en.encode()
    for n in ['README-DE.txt','ZUERST-LESEN-DE.txt','SPIELE-START-DE.txt']:files[n]=de.encode()
    files['DOCK-KEYBOARD-EN.txt']=(P/'DOCK-KEYBOARD-EN.txt').read_bytes()
    files['DOCK-KEYBOARD-DE.txt']=(P/'DOCK-KEYBOARD-DE.txt').read_bytes()
    files['VERSION.txt']=(V+'-alpha\n').encode()
    files['RELEASE-NOTES.txt']=notes.encode()
put_docs(sd);put_docs(source)
metadata=json.loads((P/'dist'/PREFIX/'core.json').read_text())
assert metadata['core']['metadata']['version']==V+'-alpha'
sd[PREFIX+'core.json']=(json.dumps(metadata,indent=2)+'\n').encode()
sd[PREFIX+'interact.json']=(P/'dist'/PREFIX/'interact.json').read_bytes()
bits=(P/'output_files/pocket.rbf').read_bytes();assert len(bits)>100000
sd[PREFIX+'bitstream.rbf_r']=bits.translate(bytes(int(f'{x:08b}'[::-1],2)for x in range(256)))
for n,h in manifest.items():source[n]=(P/n).read_bytes()
for folder in ['apf','core','rtl']:
    for f in (P/folder).rglob('*.mif'):
        source[f.relative_to(P).as_posix()]=f.read_bytes()
for f in (P/'tests').glob('*'):
    if f.is_file()and f.suffix in {'.py','.sv'} and 'sherwood' not in f.name.lower():
        source['tests/'+f.name]=f.read_bytes()
for n in gates:source['tests/'+n]=(P/'tests'/n).read_bytes()
for n in ['build.log','build-source-hashes.json','build.py','package_dock_keyboard.py',
          'review_video_phase.tcl','review_remaining_hold.tcl','video-phase-hold.rpt',
          'video-phase-setup.rpt','remaining-hold.rpt']:
    source[n]=(P/n).read_bytes()
for n in ['pocket.fit.summary','pocket.sta.summary','pocket.fit.rpt','pocket.sta.rpt']:
    source['output_files/'+n]=(P/'output_files'/n).read_bytes()
for n in ['core.json','interact.json']:source['dist/'+PREFIX+n]=sd[PREFIX+n]
original_sd=read_zip('C64-Pocket-0.5.0-Test-SD-EN.zip')
for n,b in original_sd.items():
    if n.startswith(('Assets/','Platforms/')):assert sd[n]==b,'Changed game/asset: '+n
for n,h in manifest.items():assert sha(source[n])==h,n
for files in [sd,source]:
    assert not any('sherwood' in n.lower()or n.lower().endswith(('.crt','basic.bin','characters.bin','kernal.bin','1541.bin')) for n in files)
outputs=[OUT/f'C64-Pocket-{V}-{suffix}'for suffix in ['Test-SD-EN.zip','Source-EN.zip','Read-First-EN.txt','ZUERST-LESEN-DE.txt','Release-Notes-EN.txt','Checksums.sha256']]
assert all(not n.exists()for n in outputs),'Refusing to replace an existing candidate'
OUT.mkdir(parents=True,exist_ok=True)
for name,files in zip(outputs[:2],[sd,source]):
    with zipfile.ZipFile(name,'w',zipfile.ZIP_DEFLATED)as z:
        for n,b in sorted(files.items()):z.writestr(n,b)
    with zipfile.ZipFile(name)as z:
        assert z.testzip()is None and {n:z.read(n)for n in z.namelist()}==files
outputs[2].write_text(en);outputs[3].write_text(de);outputs[4].write_text(notes)
checks=''.join(f'{sha(n.read_bytes())}  {n.name}\n'for n in outputs[:2])
outputs[5].write_text(checks)
print('PASS local Dock candidate: exact compiled source hashes, unchanged assets/game data, no private cartridges/ROMs, ZIP roundtrip verified.')
print(checks)
