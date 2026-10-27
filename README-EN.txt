C64 Pocket 0.5.3-alpha - Hardware-tested autostart fix

Hardware feedback confirms automatic D64/G64 loading and starting, manual
LOAD* and in-game disk changes without unwanted LOAD/RUN. This public
package uses the exact FPGA bitstream tested as 0.5.3-test. It remains an
alpha; this feedback is not an exhaustive test of every game or feature.

INSTALL: Back up your SD, power off Pocket, extract this SD ZIP to the SD
root, merge folders and replace core files. From 0.5.2 no renaming or asset
migration is needed. Keep your ROMs, games and settings. From 0.5.1 or older,
read MIGRATION-EN.txt first. Core ID: toby01019.C64; platform: c64.
Firmware 2.3+. Provide basic.bin, characters.bin, kernal.bin and 1541.bin
in Assets/c64/common/. System ROMs are not included.

Core Settings > Disk assist: Auto start + activity, Activity only,
Auto start only, or Off. At an empty standard BASIC READY prompt, select
D64/G64 in Disk 8, close the Pocket menu and release all buttons.
LOAD"*",8,1 is typed; RUN follows only after successful return to BASIC.
In-game swaps are insert-only. Disk 9 does not autostart; attached cartridges
disable disk autostart. Manual input cancels it. Existing LOAD*/RUN controls
remain available. For replacement ROMs or problems use Activity only/Off.
The top-right icon shows activity, not a percentage or remaining time.

TobyPink: enable REU 512 KiB and Ultimate Audio (2 voices), select its D64
and start TOBY TITLE. V027-AUDIO.REU is sample data, not a start program.
No D81/1581, NTSC, TAP, mouse, Sleep or savestates. EasyFlash writes volatile.
English menus and EN/DE guides. AI-assisted community port based on MiSTer.
Keep 0.5.2 as a fallback; older releases remain in the GitHub release archive.
