# C64 MiSTer for Analogue Pocket

Community port based on MiSTer C64, with Pocket/APF integration and
AI-assisted development. Not an official MiSTer or Analogue release.

## Download and install

Download **C64-Pocket-0.5.3-Test-SD-EN.zip** from [Releases](../../releases/latest).
Back up your SD, power off Pocket, extract to its root and merge folders.
**From 0.5.2: no renaming/migration.** From 0.5.1 or older, read
[migration instructions](MIGRATION-EN.txt). Core ID `toby01019.C64`, platform `c64`.
[English guide](READ-FIRST.txt) · [German guide](ZUERST-LESEN-DE.txt).
Firmware 2.3+. Supply your own ROMs in Assets/c64/common/.

## Features and test status

PAL C64, PRG, two 1541 drives (D64/G64, 8/9), EasyFlash, REU, SID 6581/8580,
TobyPink digital samples, reset, virtual keyboard with shifted labels,
transparency and LOAD*/RUN, Dock USB keyboard, guarded disk autostart and
an activity icon. Helpers can be switched off under Disk assist.

**0.5.3 fixes autostart cancellation during boot. Hardware tests confirmed
D64/G64 autostart, manual LOAD*, and in-game disk swaps.** The bitstream is
identical to the tested 0.5.3-test. Earlier reports cover Dock keyboard,
picture/audio, EasyFlash and other features, not an exhaustive new test.
FPGA build, timing and simulations passed; see [validation](VALIDATION.txt).

## Updaters

The core is registered with openFPGA Library. 0.5.3 requires the next catalog
update before pupdate/Pocket Sync offer it. Manual installation works now.
See [updater status](UPDATERS.md). Older releases remain as a rollback archive.

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
