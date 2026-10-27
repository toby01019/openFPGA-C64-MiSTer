C64 Pocket 0.5.2-alpha - Disk autostart and activity indicator

PUBLIC ALPHA. The new 0.5.2 FPGA build and renamed installation have NOT
yet been tested on real Pocket hardware. Earlier positive hardware tests
apply to 0.5.1 and earlier, not to these new changes. Keep 0.5.1 as fallback.

NEW CORE ID: toby01019.C64. PLATFORM: c64.
Existing users MUST read MIGRATION-EN.txt before installing. Back up your SD,
power off Pocket, extract the SD ZIP to its root and merge folders.
Copy your ROMs/games from Assets/c64mister/common/ to Assets/c64/common/.
Do not blindly overwrite files used by other C64 cores. Reapply settings
and reselect disks. Once tested, move the old Cores/Experimental.C64MiSTer/
folder to your backup to avoid a duplicate menu entry. Keep old assets safe.
System ROMs are not included; provide basic.bin, characters.bin, kernal.bin
and 1541.bin yourself. Firmware requirement: 2.3.

Core Settings > Disk assist: Auto start + activity, Activity only,
Auto start only, or Off. At an empty standard BASIC READY prompt, select
a D64/G64 in Disk 8, close the Pocket menu and release all buttons.
LOAD"*",8,1 is typed; RUN follows only after a successful return to BASIC.
In-game disk changes remain insert-only. Disk 9 never starts automatically.
Attached cartridges disable disk autostart. Manual input cancels it.
The small top-right icon shows activity, not percentage progress.
Existing LOAD*/RUN and virtual/Dock keyboard controls remain available.
For replacement ROMs or problems, select Activity only or Off.

Quick test: D64/G64 from READY, disk change during gameplay, manual loading
with Disk assist Off, picture/sound and both keyboards. See AUTOSTART-EN.txt.
TobyPink: REU 512 KiB and Ultimate Audio (2 voices); select its D64 and start
TOBY TITLE. V027-AUDIO.REU is sample data, not a start program.
No D81/1581, NTSC, TAP, mouse, Sleep or savestates. EasyFlash writes volatile.
