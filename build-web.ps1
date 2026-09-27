param(
    [string]$EmSdk = 'C:\src\emsdk',
    [string]$DasSDL3 = (Join-Path $PSScriptRoot '..\dasSDL3'),
    [string]$DependencyBuild = '',
    [int]$Jobs = 6
)
$ErrorActionPreference = 'Stop'
$EmSdk = (Get-Item -LiteralPath $EmSdk).FullName
$DasSDL3 = (Get-Item -LiteralPath $DasSDL3).FullName
if (!$DependencyBuild) { $DependencyBuild = Join-Path $DasSDL3 'build\web' }
$cache = Get-Content -LiteralPath (Join-Path $DependencyBuild 'CMakeCache.txt')
$ninja = (($cache | Where-Object { $_ -match '^CMAKE_MAKE_PROGRAM:' }) -split '=', 2)[1]
if (!$ninja -or !(Test-Path -LiteralPath $ninja)) { throw 'Ninja missing from dasSDL3 Web CMake cache' }
$previous = @{}
Get-ChildItem Env: | ForEach-Object { $previous[$_.Name] = $_.Value }
try {
    $activation = Join-Path $EmSdk 'emsdk_env.bat'
    & cmd.exe /d /s /c "`"call `"$activation`" >nul && set`"" | ForEach-Object {
        if ($_ -match '^([^=]+)=(.*)$') { [Environment]::SetEnvironmentVariable($matches[1], $matches[2], 'Process') }
    }
    if ($LASTEXITCODE -ne 0) { throw 'Cannot activate Emscripten' }
    $node = (Get-ChildItem -LiteralPath (Join-Path $EmSdk 'node') -Directory | ForEach-Object { Join-Path $_.FullName 'node.exe' } | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1)
    $buildDir = Join-Path $PSScriptRoot 'build\web'
    & (Join-Path $EmSdk 'upstream\emscripten\emcmake.bat') cmake -S (Join-Path $PSScriptRoot 'web') -B $buildDir -G Ninja -DCMAKE_BUILD_TYPE=Release "-DCMAKE_MAKE_PROGRAM=$ninja" "-DDASSDL3_ROOT=$DasSDL3" "-DDASSDL3_BUILD=$DependencyBuild" "-DNODE_EXECUTABLE=$node"
    if ($LASTEXITCODE -ne 0) { throw 'Web configure failed' }
    cmake --build $buildDir --parallel $Jobs
    if ($LASTEXITCODE -ne 0) { throw 'Web build failed' }
    Write-Output "Built $buildDir\site. Serve it with: python -m http.server 8080 --bind 127.0.0.1 --directory `"$buildDir\site`""
} finally {
    Get-ChildItem Env: | Where-Object { !$previous.ContainsKey($_.Name) } | ForEach-Object { [Environment]::SetEnvironmentVariable($_.Name, $null, 'Process') }
    foreach ($key in $previous.Keys) { [Environment]::SetEnvironmentVariable($key, $previous[$key], 'Process') }
}
