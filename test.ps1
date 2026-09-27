param(
    [string]$Runner = '',
    [switch]$Nestest,
    [string]$SmbRom = ''
)
$ErrorActionPreference = 'Stop'
if (!$Runner) {
    $Runner = Join-Path $PSScriptRoot 'build\aot\dasNES.exe'
    if (!(Test-Path -LiteralPath $Runner -PathType Leaf)) { $Runner = Join-Path $PSScriptRoot '..\dasSDL3\build\ninja\bin\dasSDL3_runner.exe' }
}
& $Runner (Join-Path $PSScriptRoot 'pacing_tests.das') --smoke-test
if ($LASTEXITCODE -ne 0) { throw 'Frame pacing tests failed' }
& $Runner (Join-Path $PSScriptRoot 'tests.das') --smoke-test
if ($LASTEXITCODE -ne 0) { throw 'Core tests failed' }
& $Runner (Join-Path $PSScriptRoot 'timing_tests.das') --smoke-test
if ($LASTEXITCODE -ne 0) { throw 'PPU timing tests failed' }
& $Runner (Join-Path $PSScriptRoot 'scroll_tests.das') --smoke-test
if ($LASTEXITCODE -ne 0) { throw 'PPU scroll tests failed' }
& $Runner (Join-Path $PSScriptRoot 'renderer_tests.das') --smoke-test
if ($LASTEXITCODE -ne 0) { throw 'Renderer reference tests failed' }
& $Runner (Join-Path $PSScriptRoot 'hardware_tests.das') --smoke-test
if ($LASTEXITCODE -ne 0) { throw 'APU/mapper tests failed' }
& $Runner (Join-Path $PSScriptRoot 'apu_event_tests.das') --smoke-test
if ($LASTEXITCODE -ne 0) { throw 'Event APU reference tests failed' }
$previousRom = $env:DASNES_ROM
try {
    $env:DASNES_ROM = Join-Path $PSScriptRoot 'demo.nes'
    & $Runner (Join-Path $PSScriptRoot 'demo_test.das') --smoke-test
    if ($LASTEXITCODE -ne 0) { throw 'Demo integration test failed' }
} finally { $env:DASNES_ROM = $previousRom }
& (Join-Path $PSScriptRoot 'run.ps1') -Runner $Runner -SmokeTest
if ($Nestest) {
    python (Join-Path $PSScriptRoot 'tools\test_nestest.py') --runner $Runner
    if ($LASTEXITCODE -ne 0) { throw 'nestest failed' }
}
if ($SmbRom) {
    if (!(Test-Path -LiteralPath $SmbRom -PathType Leaf)) { throw "SMB ROM not found: $SmbRom" }
    $previousRom = $env:DASNES_ROM
    try {
        $env:DASNES_ROM = (Get-Item -LiteralPath $SmbRom).FullName
        & $Runner (Join-Path $PSScriptRoot 'smb_scroll_test.das') --smoke-test
        if ($LASTEXITCODE -ne 0) { throw 'SMB scrolling replay failed' }
    } finally { $env:DASNES_ROM = $previousRom }
}
