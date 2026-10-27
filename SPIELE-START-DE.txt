C64 Pocket 0.5.1-alpha - USB-Tastatur am Dock

27.10.2026: Erfolgreich getestet: die USB-Tastatur auf echtem
Pocket/Dock erfolgreich getestet. Grundfunktion in diesem Aufbau bestaetigt;
Modell/Firmware und alle Sonderfaelle sind nicht dokumentiert.
Bitstream unveraendert. Siehe HARDWARE-TEST-STATUS-DE.txt.

SD sichern, Pocket ausschalten, SD-ZIP ins Hauptverzeichnis entpacken.
Cores, Platforms und Assets zusammenfuehren, Core-Dateien ersetzen, eigene
basic.bin, characters.bin, kernal.bin und 1541.bin in
Assets/c64mister/common/ behalten. Version 0.5.1-alpha pruefen.
Diskettenkopien verwenden, Schreibschutz zunaechst On.

USB-HID-Tastatur ans Analogue Dock. Core Settings -> Dock USB keyboard:
QWERTY, QWERTZ (nur Y/Z) oder Off. Nach Start/Menue/Reset/Umstecken alle
Tasten loslassen. Shift+4=$, Escape=RUN/STOP, F12=RESTORE.
Tasten und kurzer Test: DOCK-KEYBOARD-DE.txt. Bildschirmtastatur bleibt.
Y oeffnet sie, Steuerkreuz waehlt, A drueckt, X rastet ein, Y loest, B schliesst.
LOAD* und bei Bedarf RUN; TR schaltet die Transparenz um.

TobyPink: REU 512 KiB, Ultimate Audio (TobyPink) On (2 voices), Load Disk 8
-> TobyPink-Pocket-V027.d64; erstes Programm TOBY TITLE. V027-AUDIO.REU
liegt bei, ist Samplebank und kein Startprogramm. Nach Audioaenderung Neustart.
D64/G64, EasyFlash, REU, PAL, SID, Reset und Paletten bleiben enthalten.
Kein D81/1581, NTSC, TAP, Maus, Sleep oder Savestates. EasyFlash fluechtig.
System-ROMs, Sherwood und Caren fehlen. Eigenes TobyPink liegt mit Erlaubnis bei.
Quellen/Releases: https://github.com/toby01019/openFPGA-C64-MiSTer
Updater-Katalogaufnahme erst nach Annahme durch Betreuer; siehe UPDATERS.md.
