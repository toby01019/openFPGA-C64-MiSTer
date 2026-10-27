C64 Pocket 0.5.1-alpha - Dock USB keyboard

27 October 2026: positive real Pocket/Dock USB keyboard feedback. Basic operation confirmed for that setup; keyboard model,
firmware and exhaustive special-key/reconnect tests not documented.
The FPGA bitstream is unchanged. See HARDWARE-TEST-STATUS-EN.txt.

Back up your SD card, switch off Pocket, extract the SD ZIP to its root.
Merge Cores, Platforms and Assets; replace core files, keep your own ROMs:
Assets/c64mister/common/basic.bin, characters.bin, kernal.bin, 1541.bin.
Check version 0.5.1-alpha. Use copies of disks, write protection On initially.

Dock: wired USB HID keyboard -> Analogue Dock. Core Settings -> Dock USB
keyboard -> QWERTY, QWERTZ (Y/Z only), or Off. Release all keys after
startup/menu/reset/reconnect/mode change. C64 symbols: Shift+4=$,
Escape=RUN/STOP, F12=RESTORE. Full key table: DOCK-KEYBOARD-EN.txt.

Y opens virtual keyboard, D-pad selects, A presses, X holds, Y clears,
B closes. LOAD* then RUN if needed; TR changes keyboard transparency.
TobyPink: REU 512 KiB, Ultimate Audio (TobyPink) On (2 voices), Load Disk 8
-> TobyPink-Pocket-V027.d64; first program TOBY TITLE. Included
V027-AUDIO.REU is sample data, not a boot program. Restart after audio changes.
Retained: D64/G64, EasyFlash, REU, PAL, SID, Reset Core, palettes.
No D81/1581, NTSC, TAP, mouse, Sleep or savestates. EasyFlash writes volatile.
No system ROMs, Sherwood or Caren included. Own TobyPink included by permission.

Source/releases: https://github.com/toby01019/openFPGA-C64-MiSTer
itch.io: https://toby01019.itch.io/c64-mister-analogue-pocket
Updater catalog listing requires maintainer acceptance; see UPDATERS.md.
