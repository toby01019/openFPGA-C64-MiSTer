C64 Pocket 0.5.3-alpha - Autostart-Korrektur auf Hardware getestet

Bestaetigt wurden automatisches Laden/Starten mit D64 und G64, manuelles
LOAD* und Diskettenwechsel im Spiel ohne unerwuenschtes LOAD/RUN. Dieses
Paket enthaelt exakt das als 0.5.3-test getestete FPGA-Bitstream. Weiterhin
Alpha: Die Rueckmeldung ist kein vollstaendiger Test aller Spiele/Funktionen.

INSTALLATION: SD sichern, Pocket ausschalten, SD-ZIP ins Hauptverzeichnis
der SD entpacken, Ordner zusammenfuehren und Core-Dateien ersetzen.
Von 0.5.2 aus nichts umbenennen oder umziehen. Eigene ROMs, Spiele und
Einstellungen behalten. Nur von 0.5.1 oder aelter: MIGRATION-DE.txt lesen.
Kennung toby01019.C64, Plattform c64. Firmware mindestens 2.3.
Eigene basic.bin, characters.bin, kernal.bin und 1541.bin unter
Assets/c64/common/ bereitstellen. System-ROMs sind nicht enthalten.

Core Settings > Disk assist: Auto start + activity, Activity only,
Auto start only oder Off. Am leeren Standard-BASIC-READY eine D64/G64 in
Disk 8 waehlen, Pocket-Menue schliessen und alle Tasten loslassen.
LOAD"*",8,1 wird eingegeben; RUN nur nach erfolgreicher Rueckkehr zu BASIC.
Diskwechsel im Spiel bleiben ohne Eingabe. Disk 9 startet nicht automatisch;
mit eingelegtem Cartridge ist Disk-Autostart aus. Manuelle Eingabe bricht ab.
LOAD*/RUN bleiben verfuegbar. Bei Ersatz-ROMs/Problemen Activity only/Off.
Das Symbol oben rechts zeigt Aktivitaet, keinen prozentualen Fortschritt.

TobyPink: REU 512 KiB und Ultimate Audio (2 voices) einschalten, D64 waehlen,
TOBY TITLE starten. V027-AUDIO.REU ist eine Samplebank, kein Startprogramm.
Kein D81/1581, NTSC, TAP, Maus, Sleep oder Savestates; EasyFlash-Schreiben
fluechtig. Englische Menues, Anleitungen DE/EN. KI-unterstuetzter Community-Port.
0.5.2 als Rueckfall behalten; alte Versionen bleiben im GitHub-Release-Archiv.
