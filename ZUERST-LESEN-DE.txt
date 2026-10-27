C64 Pocket 0.5.2-alpha - Disketten-Autostart und Aktivitaetsanzeige

OEFFENTLICHE ALPHA. Der neue 0.5.2-FPGA-Bau und die umbenannte Installation
sind noch NICHT auf echtem Pocket getestet. Bisherige positive Hardwaretests
gelten fuer 0.5.1 und aelter. Bitte 0.5.1 als Rueckfall behalten.

NEUE KENNUNG: toby01019.C64. PLATTFORM: c64.
Bestehende Nutzer: ZUERST MIGRATION-DE.txt lesen! SD sichern, Pocket aus,
SD-ZIP ins Hauptverzeichnis entpacken und Ordner zusammenfuehren.
Eigene ROMs/Spiele aus Assets/c64mister/common/ nach Assets/c64/common/
kopieren. Vorhandene Dateien anderer C64-Cores nicht blind ueberschreiben.
Einstellungen neu setzen, Disketten neu auswaehlen. Nach erfolgreichem Test
den alten Ordner Cores/Experimental.C64MiSTer/ ins Backup verschieben,
damit kein doppelter Menueeintrag bleibt. Alte Assets als Rueckfall behalten.
System-ROMs sind nicht enthalten: basic.bin, characters.bin, kernal.bin,
1541.bin selbst bereitstellen. Firmware mindestens 2.3.

Core Settings > Disk assist: Autostart und Anzeige zusammen, einzeln oder Off.
Am leeren Standard-BASIC-READY-Prompt D64/G64 in Disk 8 auswaehlen,
Pocket-Menue schliessen und alle Tasten loslassen. LOAD"*",8,1 wird eingegeben;
RUN nur nach erfolgreicher Rueckkehr zu BASIC. Diskettenwechsel im Spiel
bleiben ohne Tastatureingabe. Disk 9 startet nie automatisch. Mit eingelegtem
Cartridge ist der Disk-Autostart aus. Manuelle Eingabe bricht ihn ab.
Das Symbol oben rechts zeigt Aktivitaet, keinen prozentualen Fortschritt.
LOAD*/RUN, Bildschirm- und Dock-Tastatur bleiben verfuegbar.
Bei Ersatz-ROMs oder Problemen Activity only oder Off verwenden.

Kurztest: D64/G64 ab READY, Diskwechsel im Spiel, manuelles Laden mit Off,
Bild/Ton und beide Tastaturen. Details in AUTOSTART-DE.txt.
TobyPink: REU 512 KiB und Ultimate Audio (2 voices) aktivieren, D64 auswaehlen,
TOBY TITLE starten. V027-AUDIO.REU ist Samplebank, kein Startprogramm.
Kein D81/1581, NTSC, TAP, Maus, Sleep oder Savestates. EasyFlash-Schreiben fluechtig.
