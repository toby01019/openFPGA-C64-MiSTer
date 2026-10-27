"""Link normalized drive sources with the already-converted C64 CPU helpers."""
from pathlib import Path
import re,subprocess,sys
P=Path(__file__).resolve().parents[1];T=P/'tests';D=T/'drive_converted';O=T/'converted'
def drive_sources():
    if not (D/'logic.sv').exists():
        subprocess.run([sys.executable,str(T/'run_1541.py')],check=True)
    text=(D/'t65.v').read_text()
    start=re.search(r'^module T65\b',text,re.M)
    assert start
    target=O/'standalone_T65.v';target.write_text(text[start.start():])
    D81=T/'drive1581_converted'
    if not (D81/'logic.sv').exists():
        subprocess.run([sys.executable,str(T/'run_1581.py')],check=True)
    extra=[P/'core'/n for n in ['pocket_1581.sv','pocket_drive9.sv','pocket_d81.sv','pocket_d81_storage.sv','pocket_file_arbiter.sv']]
    extra += [D81/'logic.sv',D81/'fdc1772.v',P/'rtl/iec_drive/floppy.v',P/'rtl/iec_drive/iecdrv_mos8520.v']
    return extra+[P/'core/pocket_1541.sv',D/'logic.sv',D/'gcr.sv',D/'misc.sv',D/'via.v',target,P/'rtl/iec_drive/lfsr.v']
