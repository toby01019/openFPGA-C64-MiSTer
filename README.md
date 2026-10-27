# C64 MiSTer for Analogue Pocket

A community port using the MiSTer C64 core as its basis, with Pocket/APF
integration and AI-assisted development. Not an official MiSTer or Analogue release.

## Download and install

Download **C64-Pocket-0.5.1-Test-SD-EN.zip** from [Releases](../../releases/latest).
Turn off Pocket, back up the SD, extract Cores/Platforms/Assets to the SD root.
Keep your own system ROMs. Full [English](READ-FIRST.txt) and
[German](ZUERST-LESEN-DE.txt) guides are included. Firmware requirement: 2.3.

## Features and hardware status

PAL C64, PRG, D64/G64 with 1541 drives 8/9, EasyFlash, REU, SID 6581/8580,
palettes, reset and a C64-style virtual keyboard with shifted labels,
transparency, LOAD* and RUN. Targeted two-voice TobyPink digital samples.
Dock wired USB HID keyboard: QWERTY, QWERTZ (Y/Z only), or Off.

**27 October 2026:** positive real Pocket/Dock USB keyboard test reported
on real hardware. Basic operation works in that setup; this is not
an exhaustive keyboard/firmware compatibility guarantee. Earlier 0.5.0
hardware feedback covers EasyFlash/Caren, TobyPink effects and existing
disk/video/audio/keyboard functions. [Test scope](HARDWARE-TEST-STATUS-EN.txt).
The FPGA bitstream is unchanged from the original 0.5.1-alpha.

## Updaters

**27 October:** [catalog registration accepted and merged](https://github.com/openfpga-library/analogue-pocket/pull/1863). Public inventory generation is still pending. The actual pupdate installation from the GitHub ZIP passed with a local accepted-entry fixture; [validation details](UPDATER-VALIDATION.md).

The release ZIP has Cores, Platforms and Assets at its root. The existing
`Experimental.C64MiSTer` ID is intentionally retained for in-place upgrades.
[Updater integration/status](UPDATERS.md). Catalog acceptance is separate
from publishing this repository; do not assume automatic listing yet.

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
