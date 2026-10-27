# pupdate and Pocket Sync

Release asset: `C64-Pocket-0.5.1-Test-SD-EN.zip`
Asset regex: `^C64-Pocket-.*-Test-SD-EN\.zip$`
Core ID: `Experimental.C64MiSTer` (kept for existing users)
GitHub repository: `toby01019/openFPGA-C64-MiSTer`

The ZIP is rooted at Cores/, Platforms/, Assets/ (no wrapper directory).
Source and checksum downloads are separate and must not be selected by updaters.
No system ROM download is configured; users provide their own ROMs.

Catalog submission: [openFPGA Library Add Core](https://github.com/openfpga-library/analogue-pocket/issues/new?template=ADD-CORE.yml).
The shared inventory is used by pupdate and Pocket Sync. A published release
alone does not add a core to their browse/install lists: maintainers must
accept the entry. Until accepted, use manual ZIP extraction, or drag the
SD ZIP into Pocket Sync (its documented manual install flow).

References:
- https://github.com/openfpga-library/analogue-pocket#adding-a-new-core
- https://github.com/neil-morrison44/pocket-sync#why-isnt-some-core-in-the-list
- https://github.com/mattpannella/pupdate

## Registration accepted

[Request #1862](https://github.com/openfpga-library/analogue-pocket/issues/1862) / [merged PR #1863](https://github.com/openfpga-library/analogue-pocket/pull/1863). Public catalog generation is pending as of 27 October. See [installation validation](UPDATER-VALIDATION.md).
