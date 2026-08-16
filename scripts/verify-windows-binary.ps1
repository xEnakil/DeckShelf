param(
    [string]$Binary = "target/release/deck-shelf.exe"
)

$ErrorActionPreference = "Stop"
$resolved = (Resolve-Path -LiteralPath $Binary).Path
$dumpbin = (Get-Command dumpbin.exe -ErrorAction SilentlyContinue).Source
if (-not $dumpbin) {
    $vswhere = Join-Path ${env:ProgramFiles(x86)} "Microsoft Visual Studio\Installer\vswhere.exe"
    $installation = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
    $dumpbin = Get-ChildItem -Path "$installation\VC\Tools\MSVC\*\bin\Hostx64\x64\dumpbin.exe" |
        Sort-Object -Property FullName -Descending |
        Select-Object -First 1 -ExpandProperty FullName
}
if (-not $dumpbin) {
    throw "dumpbin.exe was not found. Install the Visual C++ build tools."
}

$dependencies = & $dumpbin /dependents $resolved | Out-String
if ($LASTEXITCODE -ne 0) {
    throw "dumpbin failed for $resolved"
}

$forbidden = [regex]::Matches(
    $dependencies,
    '(?im)^\s*((?:VCRUNTIME|MSVCP|UCRTBASE|api-ms-win-crt)[^\s]*\.dll)\s*$'
) | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique
if ($forbidden) {
    throw "Dynamic Visual C++ runtime dependency found: $($forbidden -join ', ')"
}

$headers = & $dumpbin /headers $resolved | Out-String
if ($headers -notmatch '(?im)Windows GUI') {
    throw "The executable is not marked as a Windows GUI application."
}

$size = (Get-Item -LiteralPath $resolved).Length
if ($size -ge 20MB) {
    throw "The executable is unexpectedly large: $size bytes"
}

Write-Output "Verified static CRT, GUI subsystem, and size ($size bytes): $resolved"
