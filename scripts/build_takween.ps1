param(
    [string]$Version = "0.1.0"
)

$ErrorActionPreference = "Stop"

$root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$distDir = Join-Path $root "dist"
$binDir = Join-Path $distDir "bin"
$outputExeLegacy = Join-Path $binDir "takween.exe"
$outputExeArabic = Join-Path $binDir "تكوين.exe"

if (-not (Get-Command baa.exe -ErrorAction SilentlyContinue)) {
    throw "baa.exe not found in PATH. Install Baa compiler first."
}

New-Item -ItemType Directory -Force $binDir | Out-Null

$sourceFiles = @(
    ".\\المصدر\\الرئيسية.baa",
    ".\\المصدر\\محلل_النصوص.baa",
    ".\\المصدر\\منفذ_الأوامر.baa"
)

foreach ($srcRel in $sourceFiles) {
    $src = Join-Path $root ($srcRel -replace '^[.][\\]', '')
    if (-not (Test-Path $src)) {
        throw "Missing source file: $src"
    }
}

Push-Location $root
try {
    & baa @sourceFiles -o $outputExeLegacy
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to build takween.exe (exit code $LASTEXITCODE)."
    }

    Copy-Item -Force $outputExeLegacy $outputExeArabic
}
finally {
    Pop-Location
}

Set-Content -Encoding ascii (Join-Path $distDir "VERSION.txt") $Version
Write-Output "Build complete: $outputExeArabic (primary), $outputExeLegacy (alias)"
