param([string]$Toolchain = "$PSScriptRoot\..\..\..\work\tools\cc65")
$ErrorActionPreference = 'Stop'
$assembler = Join-Path $Toolchain 'bin\ca65.exe'
$linker = Join-Path $Toolchain 'bin\ld65.exe'
$library = Join-Path $Toolchain 'lib\c64.lib'
$configuration = Join-Path $PSScriptRoot 'game.cfg'
$buildDirectory = Join-Path $PSScriptRoot '..\build'
New-Item -ItemType Directory -Path $buildDirectory -Force | Out-Null
Push-Location $PSScriptRoot
try {
    foreach ($module in @('game','graphics','movement','raster','sample','sprites', 'mechanics','projectile','weapons','coast','scroll','landing','bonus','health','details','world','actors','spritepack','campaign','transit','preview','reward','toby','foes')) {
        & $assembler -t c64 -o "$buildDirectory\$module.o" "$module.s"
        if ($LASTEXITCODE -ne 0) { throw "Assembly failed: $module" }
    }
    & $linker -C $configuration -D '__HIMEM__=0xC000' -D '__STACKSIZE__=0x0400' -o '..\toby-saves-the-pink-v0.3.27.prg' -m '..\toby-saves-the-pink-v0.3.27.map' -Ln '..\toby-saves-the-pink-v0.3.27.lbl' "$buildDirectory\game.o" "$buildDirectory\graphics.o" "$buildDirectory\movement.o" "$buildDirectory\raster.o" "$buildDirectory\sample.o" "$buildDirectory\sprites.o" "$buildDirectory\mechanics.o" "$buildDirectory\projectile.o" "$buildDirectory\weapons.o" "$buildDirectory\coast.o" "$buildDirectory\scroll.o" "$buildDirectory\landing.o" "$buildDirectory\bonus.o" "$buildDirectory\health.o" "$buildDirectory\details.o" "$buildDirectory\world.o" "$buildDirectory\actors.o" "$buildDirectory\spritepack.o" "$buildDirectory\campaign.o" "$buildDirectory\transit.o" "$buildDirectory\preview.o" "$buildDirectory\reward.o" "$buildDirectory\toby.o" "$buildDirectory\foes.o" $library
    if ($LASTEXITCODE -ne 0) { throw 'Assembler link failed' }
    Copy-Item -LiteralPath '..\toby-saves-the-pink-v0.3.27.prg' -Destination '..\toby-try-to-save-the-pink-v0.3.27.prg' -Force
    & $assembler -o "$buildDirectory\title.o" 'title.s'
    if ($LASTEXITCODE -ne 0) { throw 'Title assembly failed' }
    & $linker -C 'title.cfg' -o '..\toby-try-to-save-the-pink-title-v0.3.27.prg' -Ln '..\title-v0.3.27.lbl' "$buildDirectory\title.o"
    if ($LASTEXITCODE -ne 0) { throw 'Title link failed' }
} finally { Pop-Location }




