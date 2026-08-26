param(
    [string]$Version = "0.1.0",
    [string]$BaaPath = "baa",
    [string]$BaaStdlibPath = ""
)

$ErrorActionPreference = "Stop"

$root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$distDir = Join-Path $root "dist"
$binDir = Join-Path $distDir "bin"
$arabicCommand = -join [char[]](0x062A, 0x0643, 0x0648, 0x064A, 0x0646)

$resolvedBaa = Get-Command $BaaPath -ErrorAction SilentlyContinue
if (-not $resolvedBaa) {
    throw "Baa compiler not found: $BaaPath"
}
$BaaPath = $resolvedBaa.Source

$targetInfoText = & $BaaPath --target-info=json 2>&1 | Out-String
if ($LASTEXITCODE -ne 0) {
    throw "Selected Baa compiler does not provide target-info-v1.`n$targetInfoText"
}
$targetInfo = $targetInfoText | ConvertFrom-Json
if ($targetInfo.schema_version -ne 'target-info-v1') {
    throw "Selected Baa compiler returned an unsupported target discovery contract."
}
$hostTarget = @($targetInfo.targets | Where-Object { $_.name -eq $targetInfo.host_target })[0]
if (-not $hostTarget -or -not $hostTarget.capabilities.link) {
    throw "Selected Baa compiler cannot link its reported host target."
}
$executableSuffix = [string]$hostTarget.executable_suffix
$outputExeLegacy = Join-Path $binDir ("takween" + $executableSuffix)
$outputExeArabic = Join-Path $binDir ($arabicCommand + $executableSuffix)

$sourceFiles = @(
    Get-ChildItem -LiteralPath $root -Directory |
        ForEach-Object { Get-ChildItem -LiteralPath $_.FullName -File -Filter '*.baa' } |
        Where-Object { $_.Extension -eq '.baa' } |
        Sort-Object Name |
        ForEach-Object { $_.FullName }
)
if ($sourceFiles.Count -lt 5) {
    throw "Expected at least five top-level Takween source files, found $($sourceFiles.Count)."
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
        throw "Failed to build Takween (exit code $LASTEXITCODE)."
    }

    if ([Environment]::OSVersion.Platform -eq [PlatformID]::Win32NT) {
        & (Join-Path $PSScriptRoot 'Set-WindowsExecutableIcon.ps1') `
            -Executable $outputExeLegacy `
            -Icon (Join-Path $root 'resources\branding\takween.ico')
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to embed the Takween application icon."
        }
    }

    Copy-Item -Force $outputExeLegacy $outputExeArabic
}
finally {
    Pop-Location
    $env:BAA_STDLIB = $oldBaaStdlib
}

Set-Content -Encoding ascii (Join-Path $distDir "VERSION.txt") $Version
Write-Output "Build complete: $outputExeArabic (primary), $outputExeLegacy (alias)"
