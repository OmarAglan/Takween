param(
    [string]$Version = "0.1.0",
    [string]$BaaPath = "",
    [string]$BaaStdlibPath = "",
    [string]$NazmPath = "",
    [string]$IsccPath = "",
    [switch]$SkipBuild
)

$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$setupScript = Join-Path $root "setup.iss"
$buildScript = Join-Path $PSScriptRoot "build_takween.ps1"

if ([string]::IsNullOrWhiteSpace($BaaPath)) {
    $candidate = Join-Path $root "..\Baa\build\baa.exe"
    if (Test-Path -LiteralPath $candidate -PathType Leaf) { $BaaPath = $candidate }
    else { $BaaPath = "baa" }
}
if ([string]::IsNullOrWhiteSpace($BaaStdlibPath)) {
    $candidate = Join-Path $root "..\Baa\stdlib"
    if (Test-Path -LiteralPath (Join-Path $candidate "baalib.baahd") -PathType Leaf) {
        $BaaStdlibPath = $candidate
    }
}
if ([string]::IsNullOrWhiteSpace($NazmPath)) {
    foreach ($candidate in @(
        (Join-Path $root "..\Nazm\build\windows-release\nazm.exe"),
        (Join-Path $root "..\Nazm\build\nazm.exe")
    )) {
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            $NazmPath = $candidate
            break
        }
    }
}

if (-not $SkipBuild) {
    $oldNazm = $env:BAA_NAZM
    try {
        if (-not [string]::IsNullOrWhiteSpace($NazmPath)) {
            $env:BAA_NAZM = (Resolve-Path -LiteralPath $NazmPath).Path
        }
        & $buildScript -Version $Version -BaaPath $BaaPath -BaaStdlibPath $BaaStdlibPath
        if ($LASTEXITCODE -ne 0) { throw "Takween build failed with exit code $LASTEXITCODE." }
    }
    finally {
        $env:BAA_NAZM = $oldNazm
    }
}

$binaryDirectory = Join-Path $root "dist\bin"
$arabicCommand = (-join [char[]](0x062A, 0x0643, 0x0648, 0x064A, 0x0646)) + ".exe"
foreach ($required in @($arabicCommand, "takween.exe")) {
    $path = Join-Path $binaryDirectory $required
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Required Takween installer input is missing: $path"
    }
}

if ([string]::IsNullOrWhiteSpace($IsccPath)) {
    $command = Get-Command ISCC.exe -ErrorAction SilentlyContinue
    if ($command) { $IsccPath = $command.Source }
}
if ([string]::IsNullOrWhiteSpace($IsccPath)) {
    $IsccPath = @(
        "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe",
        "C:\Program Files (x86)\Inno Setup 6\ISCC.exe",
        "C:\Program Files\Inno Setup 6\ISCC.exe"
    ) | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1
}
if ([string]::IsNullOrWhiteSpace($IsccPath) -or
    -not (Test-Path -LiteralPath $IsccPath -PathType Leaf)) {
    throw "Inno Setup 6 compiler was not found. Pass -IsccPath explicitly."
}

Push-Location $root
try {
    & $IsccPath "/DMyAppVersion=$Version" "/DTakweenBinaryDir=$binaryDirectory" $setupScript
    if ($LASTEXITCODE -ne 0) { throw "ISCC failed with exit code $LASTEXITCODE." }
}
finally {
    Pop-Location
}

$installer = Join-Path $root "dist\installer\takween-setup-$Version-x64.exe"
if (-not (Test-Path -LiteralPath $installer -PathType Leaf)) {
    throw "Takween installer was not produced at $installer"
}
$installerHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $installer).Hash
$checksum = $installer + ".sha256"
[IO.File]::WriteAllText(
    $checksum,
    "$installerHash *$([IO.Path]::GetFileName($installer))`n",
    [Text.Encoding]::ASCII)
Write-Output $installer
Write-Output $checksum
