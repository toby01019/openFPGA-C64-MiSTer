# C64 MiSTer for Analogue Pocket

Community port based on MiSTer C64, with Pocket/APF integration and
AI-assisted development. Not an official MiSTer or Analogue release.

## Download and install

Download **C64-Pocket-0.5.2-Test-SD-EN.zip** from [Releases](../../releases/latest).
**New core ID: toby01019.C64; platform: c64. Existing users must follow
[migration instructions](MIGRATION-EN.txt) before installing.**
[English guide](READ-FIRST.txt) · [German guide](ZUERST-LESEN-DE.txt).
Firmware 2.3 or later. Supply your own ROMs in Assets/c64/common/.

## Features and test status

PAL C64, PRG, two 1541 drives (D64/G64, 8/9), EasyFlash, REU, SID 6581/8580,
TobyPink digital samples, reset, virtual keyboard with shifted labels,
transparency and LOAD*/RUN, Dock USB keyboard. New in 0.5.2: guarded disk
autostart and a small activity icon, individually switchable under Disk assist.

**0.5.2 has NOT yet been tested on real Pocket hardware.** Earlier positive
hardware tests include 0.5.1 Dock keyboard and preceding disk/video/audio,
EasyFlash and virtual keyboard functions. They do not validate this new build.
FPGA compilation, timing and simulations passed; see [validation](VALIDATION.txt).

## Updaters

0.5.1 is listed in both public openFPGA catalogs under Experimental.C64MiSTer.
The renamed 0.5.2 entry must propagate after publication. Install manually
until it appears; asset/settings migration is not automatic.
See [updater status](UPDATERS.md).

## Limits

No D81/1581, NTSC, TAP, mouse, Sleep or savestates. EasyFlash writes are
volatile. Use disk copies, leave write protection On initially and allow
time after SAVE before shutdown. TobyPink audio is not full Ultimate emulation.
System ROMs and third-party games are not distributed. User-owned TobyPink
is bundled with its author's permission.

## Source, build, testing, credits and AI

Source is in apf/, core/ and rtl/. The compiled build's hardware source
hashes are in build-source-hashes.json; release-only metadata/docs change
independently. `QUARTUS_BIN` selects Quartus; run `python build.py`.
Tests and logs are in tests/. Some simulation tools have local paths and
need adjusting. Unused upstream ROM MIF dumps are omitted; this port loads
user-supplied ROMs at runtime. Existing copyright/license headers are retained.

Based on [MiSTer-devel/C64_MiSTer](https://github.com/MiSTer-devel/C64_MiSTer)
at fe6dfe53c99122e5a088691f2d358d6caba61de1 and the
[myc64-pocket/APF foundation](https://github.com/markus-zzz/myc64-pocket)
at cad23ce24a3481ec721cbf90579202fbf00ee484, with the original FPGA64,
T65, SID, drive, APF and other contributors credited in source headers.
The Dock HID decoder is our independent implementation against Analogue's
documented APF reports; the old myc64 keyboard decoder was not copied.

AI (OpenAI Codex, SOL/Astra models) assisted porting, debugging, tests and
documentation. Compilation/simulation/timing checks and independent tester
feedback are recorded; AI assistance is not a substitute for hardware testing.
See [LICENSES.md](LICENSES.md) for mixed-source licensing scope.

Also available on [itch.io](https://toby01019.itch.io/c64-mister-analogue-pocket).
