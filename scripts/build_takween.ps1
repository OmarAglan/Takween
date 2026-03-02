param(
    [string]$Version = "0.1.0",
    [switch]$KeepTemp
)

$ErrorActionPreference = "Stop"

$root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$distDir = Join-Path $root "dist"
$binDir = Join-Path $distDir "bin"
$tmpDir = Join-Path $distDir "_build_tmp"
$outputExe = Join-Path $binDir "takween.exe"

if (-not (Get-Command baa.exe -ErrorAction SilentlyContinue)) {
    throw "baa.exe not found in PATH. Install Baa compiler first."
}

Remove-Item -Recurse -Force $tmpDir -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force $tmpDir | Out-Null
New-Item -ItemType Directory -Force $binDir | Out-Null

$sourceMap = @{
    "main.baa"      = "المصدر\\الرئيسية.baa"
    "parser.baa"    = "المصدر\\محلل_النصوص.baa"
    "executor.baa"  = "المصدر\\منفذ_الأوامر.baa"
    "takween.baahd" = "المصدر\\تكوين.baahd"
}

foreach ($entry in $sourceMap.GetEnumerator()) {
    $src = Join-Path $root $entry.Value
    $dst = Join-Path $tmpDir $entry.Key

    if (-not (Test-Path $src)) {
        throw "Missing source file: $src"
    }

    $content = Get-Content -Raw $src
    $content = $content.Replace('#تضمين "المصدر/تكوين.baahd"', '#تضمين "takween.baahd"')
    Set-Content -Encoding utf8 $dst $content
}

Push-Location $tmpDir
try {
    & baa .\\main.baa .\\parser.baa .\\executor.baa -I . -o $outputExe
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to build takween.exe (exit code $LASTEXITCODE)."
    }
}
finally {
    Pop-Location
}

if (-not $KeepTemp) {
    Remove-Item -Recurse -Force $tmpDir -ErrorAction SilentlyContinue
}

Set-Content -Encoding ascii (Join-Path $distDir "VERSION.txt") $Version
Write-Output "Build complete: $outputExe"
