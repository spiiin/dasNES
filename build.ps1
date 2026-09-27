param(
    [string]$DasSDL3 = (Join-Path $PSScriptRoot '..\dasSDL3'),
    [string]$DependencyBuild = '',
    [string]$VsDevCmd = '',
    [int]$Jobs = 4,
    [switch]$Standalone,
    [switch]$Jit
)
$ErrorActionPreference = 'Stop'
if ($Standalone -and $Jit) { throw 'Standalone does not include JIT' }
if ($Jit) { & (Join-Path $PSScriptRoot 'tools\install-jit.ps1') }
$DasSDL3 = (Get-Item -LiteralPath $DasSDL3 -ErrorAction Stop).FullName
if (!$DependencyBuild) { $DependencyBuild = Join-Path $DasSDL3 'build\ninja' }
$cache = Get-Content -LiteralPath (Join-Path $DependencyBuild 'CMakeCache.txt')
function CacheValue([string]$Name) {
    $line = $cache | Where-Object { $_ -match ('^' + [regex]::Escape($Name) + ':[^=]+=') } | Select-Object -First 1
    if (!$line) { throw "Missing $Name in dasSDL3 CMake cache" }
    return ($line -split '=', 2)[1]
}
$ninja = CacheValue 'CMAKE_MAKE_PROGRAM'
if (!$VsDevCmd) {
    $compiler = (CacheValue 'CMAKE_CXX_COMPILER').Replace('/', '\')
    $vsRoot = ($compiler -split '\\VC\\Tools\\MSVC\\', 2)[0]
    $VsDevCmd = Join-Path $vsRoot 'Common7\Tools\VsDevCmd.bat'
}
if (!(Test-Path -LiteralPath $VsDevCmd -PathType Leaf)) { throw "VS developer shell not found: $VsDevCmd; pass -VsDevCmd" }
$oldEnvironment = @{}
try {
    # Use the exact MSVC installation used by the prebuilt dependency.
    $devEnvironment = & $env:ComSpec /d /s /c "`"$VsDevCmd`" -arch=x64 -host_arch=x64 >nul && set"
    if ($LASTEXITCODE -ne 0) { throw 'Could not initialize MSVC environment' }
    foreach ($line in $devEnvironment) {
        if ($line -match '^([^=]+)=(.*)$') {
            $key = $Matches[1]
            $oldEnvironment[$key] = [Environment]::GetEnvironmentVariable($key, 'Process')
            [Environment]::SetEnvironmentVariable($key, $Matches[2], 'Process')
        }
    }
    $buildDir = Join-Path $PSScriptRoot 'build\aot'
    cmake -S $PSScriptRoot -B $buildDir -G Ninja -DCMAKE_BUILD_TYPE=Release "-DDASSDL3_ROOT=$DasSDL3" "-DDASSDL3_BUILD=$DependencyBuild" "-DCMAKE_MAKE_PROGRAM=$ninja"
    if ($LASTEXITCODE -ne 0) { throw 'CMake configuration failed' }
    $buildArgs = @('--build', $buildDir, '--parallel', $Jobs)
    if ($Standalone) { $buildArgs += @('--target', 'dasNES_standalone') }
    cmake @buildArgs
    if ($LASTEXITCODE -ne 0) { throw 'AOT build failed' }
} finally {
    foreach ($key in $oldEnvironment.Keys) { [Environment]::SetEnvironmentVariable($key, $oldEnvironment[$key], 'Process') }
}
