param([string]$Archive = '')
$ErrorActionPreference = 'Stop'
$destination = Join-Path $PSScriptRoot '..\build\jit'
$version = '22.1.5-r4'
$stamp = Join-Path $destination 'LLVM.version'
if ((Test-Path -LiteralPath (Join-Path $destination 'LLVM.dll')) -and
    (Test-Path -LiteralPath $stamp) -and (Get-Content -LiteralPath $stamp -Raw).Trim() -eq $version) { return }
New-Item -ItemType Directory -Force $destination | Out-Null
if (!$Archive) {
    $Archive = Join-Path $destination 'win64_llvm.tar.gz'
    & curl.exe -L --fail --retry 2 -o $Archive 'https://github.com/GaijinEntertainment/daScript/releases/download/llvm-v22.1.5/win64_llvm.tar.gz'
    if ($LASTEXITCODE -ne 0) { throw 'LLVM download failed' }
}
# Same version/hash as the pinned daScript modules/dasLLVM/CMakeLists.txt.
if ((Get-FileHash -LiteralPath $Archive -Algorithm SHA256).Hash -ne '7f67cbfa1b8196d13b020f8fea721c4c586204b3d0f9f0c73b289514a888c899') { throw 'LLVM archive SHA256 mismatch' }
& tar.exe -xf $Archive -C $destination LLVM.dll
if ($LASTEXITCODE -ne 0) { throw 'LLVM extraction failed' }
Set-Content -LiteralPath $stamp -Value $version
