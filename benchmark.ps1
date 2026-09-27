param(
    [string]$Rom = (Join-Path $PSScriptRoot 'demo.nes'),
    [switch]$Interpreter
)
$ErrorActionPreference = 'Stop'
if (!(Test-Path -LiteralPath $Rom -PathType Leaf)) { throw "ROM file not found: '$Rom'" }
$runner = Join-Path $PSScriptRoot 'build\aot\dasNES.exe'
if (!(Test-Path -LiteralPath $runner -PathType Leaf)) { throw 'Run .\build.ps1 first' }
$previousRom = $env:DASNES_ROM
try {
    $env:DASNES_ROM = (Get-Item -LiteralPath $Rom).FullName
    $runnerArgs = @((Join-Path $PSScriptRoot 'benchmark.das'), '--smoke-test')
    if ($Interpreter) { $runnerArgs += '--interpret' }
    & $runner @runnerArgs
    if ($LASTEXITCODE -ne 0) { throw 'Benchmark failed' }
} finally { $env:DASNES_ROM = $previousRom }
