param(
    [string]$Version = "0.1.0",
    [string]$BaaPath = "baa.exe",
    [string]$BaaStdlibPath = ""
)

$ErrorActionPreference = "Stop"

$root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$distDir = Join-Path $root "dist"
$binDir = Join-Path $distDir "bin"
$outputExeLegacy = Join-Path $binDir "takween.exe"
$arabicCommand = -join [char[]](0x062A, 0x0643, 0x0648, 0x064A, 0x0646)
$outputExeArabic = Join-Path $binDir ($arabicCommand + ".exe")

$resolvedBaa = Get-Command $BaaPath -ErrorAction SilentlyContinue
if (-not $resolvedBaa) {
    throw "Baa compiler not found: $BaaPath"
}
$BaaPath = $resolvedBaa.Source

$sourceFiles = @(
    Get-ChildItem -LiteralPath $root -Directory |
        ForEach-Object { Get-ChildItem -LiteralPath $_.FullName -File -Filter '*.baa' } |
        Where-Object { $_.Extension -eq '.baa' } |
        Sort-Object Name |
        ForEach-Object { $_.FullName }
)
if ($sourceFiles.Count -ne 3) {
    throw "Expected exactly three top-level Takween source files, found $($sourceFiles.Count)."
}

$versionSource = $sourceFiles |
    Where-Object { (Get-Content -Raw -Encoding utf8 -LiteralPath $_) -match [regex]::Escape($Version) } |
    Select-Object -First 1
if (-not $versionSource) {
    throw "Version mismatch: no Takween source reports version $Version."
}

New-Item -ItemType Directory -Force $binDir | Out-Null

$oldBaaStdlib = $env:BAA_STDLIB
Push-Location $root
try {
    if ($BaaStdlibPath) {
        $env:BAA_STDLIB = (Resolve-Path -LiteralPath $BaaStdlibPath).Path
    }
    Write-Output "Baa compiler: $BaaPath"
    & $BaaPath -I $root @sourceFiles -o $outputExeLegacy
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to build takween.exe (exit code $LASTEXITCODE)."
    }

    Copy-Item -Force $outputExeLegacy $outputExeArabic
}
finally {
    Pop-Location
    $env:BAA_STDLIB = $oldBaaStdlib
}

Set-Content -Encoding ascii (Join-Path $distDir "VERSION.txt") $Version
Write-Output "Build complete: $outputExeArabic (primary), $outputExeLegacy (alias)"
