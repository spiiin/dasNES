param(
    [string]$Runner = (Join-Path $PSScriptRoot '..\..\dasSDL3\build\ninja\bin\dasSDL3_runner.exe')
)
$ErrorActionPreference = 'Stop'
$repoDir = Split-Path $PSScriptRoot -Parent
$fixtureDir = Join-Path $repoDir ('work\launcher-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $fixtureDir -Force | Out-Null
$fixture = Join-Path $fixtureDir 'Super Mario Bros. (W) [!].nes'
Copy-Item -LiteralPath (Join-Path $repoDir 'demo.nes') -Destination $fixture
$previousRom = $env:DASNES_ROM
try {
    $env:DASNES_ROM = 'launcher-test-sentinel'
    & (Join-Path $repoDir 'run.ps1') -Rom $fixture -Runner $Runner -SmokeTest
    if ($env:DASNES_ROM -ne 'launcher-test-sentinel') { throw 'Launcher did not restore DASNES_ROM' }
    $missing = Join-Path $fixtureDir 'Missing [!].nes'
    $rejected = $false
    try {
        & (Join-Path $repoDir 'run.ps1') -Rom $missing -Runner $Runner -SmokeTest
    } catch {
        if (!$_.Exception.Message.Contains("ROM file not found: '$missing'")) { throw }
        $rejected = $true
    }
    if (!$rejected) { throw 'Launcher accepted a missing ROM' }
    if ($env:DASNES_ROM -ne 'launcher-test-sentinel') { throw 'Missing ROM changed DASNES_ROM' }
    Write-Output 'PASS: launcher supports spaces/brackets, rejects missing ROM with its path, and restores environment'
} finally {
    $env:DASNES_ROM = $previousRom
    Remove-Item -LiteralPath $fixture -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $fixtureDir -ErrorAction SilentlyContinue
}
