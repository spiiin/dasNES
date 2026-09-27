param(
    [string]$Rom = (Join-Path $PSScriptRoot 'demo.nes'),
    [switch]$Interpreter,
    [switch]$Jit,
    [switch]$Profile
)
$ErrorActionPreference = 'Stop'
if (!(Test-Path -LiteralPath $Rom -PathType Leaf)) { throw "ROM file not found: '$Rom'" }
$runner = Join-Path $PSScriptRoot 'build\aot\dasNES.exe'
if ($Interpreter -and !$Jit) { $runner = Join-Path $PSScriptRoot '..\dasSDL3\build\ninja\bin\dasSDL3_runner.exe' }
if (!(Test-Path -LiteralPath $runner -PathType Leaf)) { throw 'Build dasNES (AOT) or dasSDL3 (interpreter) first' }
$previousRom = $env:DASNES_ROM
try {
    $env:DASNES_ROM = (Get-Item -LiteralPath $Rom).FullName
    $script = if ($Profile) { 'profile.das' } else { 'benchmark.das' }
    $runnerArgs = @((Join-Path $PSScriptRoot $script), '--smoke-test')
    if ($Jit) { $runnerArgs += '--jit' }
    & $runner @runnerArgs
    if ($LASTEXITCODE -ne 0) { throw 'Benchmark failed' }
} finally { $env:DASNES_ROM = $previousRom }
