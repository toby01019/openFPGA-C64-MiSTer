# Updater validation - 27 October 2026

## Release package

The official openFPGA validator completed with exit code 0. Its only
recommendation was the optional missing c64mister platform image.
The ZIP has Cores/, Platforms/, Assets/ at its root, one core identifier
Experimental.C64MiSTer, and a GitHub repository URL in core metadata.
The source ZIP is separate and excluded by the inventory asset filter.

## pupdate installation

Official pupdate 5.9.0 was downloaded from mattpannella/pupdate's GitHub
release and verified against GitHub's asset digest. The installation test
used a completely separate empty directory, not an actual SD card.
Firmware, system ROM/asset downloads, plugins and unmanaged-core deletion
were disabled. A local v3 inventory fixture containing the accepted core
entry was used while the public catalog's generation was still pending.

Command: `pupdate update -p <empty-test-directory> -c Experimental.C64MiSTer -y`

Result: successful download from the public GitHub release, extraction and
installation of 0.5.1-alpha. All eleven installed Cores/Assets files match
the released SD ZIP byte for byte, including bitstream, game and sample bank.

This checks the actual download/install path. It does not claim that the
public catalog was already updated or that every keyboard has been tested.

## Shared catalog status

[Add Core request #1862](https://github.com/openfpga-library/analogue-pocket/issues/1862)
produced [PR #1863](https://github.com/openfpga-library/analogue-pocket/pull/1863),
which was merged. The registered asset regex selects only Test-SD-EN.zip.
The public v2/v3 API had not yet published Experimental.C64MiSTer at the
time of this test. Normal automatic catalog install follows that publication.
Pocket Sync also supports installing the SD ZIP directly by drag and drop.

No new FPGA build was needed: the tested 0.5.1 bitstream is unchanged.
