param(
    [string]$Rom = (Join-Path $PSScriptRoot 'demo.nes'),
    [string]$Runner = '',
    [switch]$Interpreter,
    [switch]$Mute,
    [switch]$Zapper,
    [switch]$SmokeTest
)
$ErrorActionPreference = 'Stop'
if (!$Runner) {
    $Runner = Join-Path $PSScriptRoot 'build\aot\dasNES.exe'
    if ($Interpreter -or !(Test-Path -LiteralPath $Runner -PathType Leaf)) {
        $Runner = Join-Path $PSScriptRoot '..\dasSDL3\build\ninja\bin\dasSDL3_runner.exe'
        if (!$Interpreter) { Write-Warning 'AOT build not found; using interpreter. Run .\build.ps1 for full speed.' }
    }
}
if (!(Test-Path -LiteralPath $Runner -PathType Leaf)) {
    throw "dasSDL3 runner not found: $Runner. Build dasSDL3 or pass -Runner."
}
if ([string]::IsNullOrWhiteSpace($Rom) -or !(Test-Path -LiteralPath $Rom -PathType Leaf)) {
    throw "ROM file not found: '$Rom'. Pass the path to an extracted .nes file."
}
$romPath = (Get-Item -LiteralPath $Rom -ErrorAction Stop).FullName
$previousRom = $env:DASNES_ROM
$previousMute = $env:DASNES_MUTE
$previousZapper = $env:DASNES_ZAPPER
try {
    $env:DASNES_ROM = $romPath
    $env:DASNES_MUTE = if ($Mute) { "1" } else { "0" }
    $env:DASNES_ZAPPER = if ($Zapper -or [IO.Path]::GetFileName($romPath) -like "Duck Hunt*") { "1" } else { "0" }
    $runnerArgs = @((Join-Path $PSScriptRoot 'main.das'))
    if ($SmokeTest) { $runnerArgs += '--smoke-test' }
    if ($Interpreter -and [IO.Path]::GetFileName($Runner) -eq 'dasNES.exe') { $runnerArgs += '--interpret' }
    & $Runner @runnerArgs
    if ($LASTEXITCODE -ne 0) { throw "dasNES failed with exit code $LASTEXITCODE" }
} finally {
    $env:DASNES_ROM = $previousRom
    $env:DASNES_MUTE = $previousMute
    $env:DASNES_ZAPPER = $previousZapper
}
