param(
    [string]$Version = "0.1.0",
    [string]$IsccPath = ""
)

$ErrorActionPreference = "Stop"

$root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$setupScript = Join-Path $root "setup.iss"
$buildScript = Join-Path $PSScriptRoot "build_takween.ps1"

if (-not (Test-Path $setupScript)) {
    throw "setup.iss not found at: $setupScript"
}

& $buildScript -Version $Version

if ([string]::IsNullOrWhiteSpace($IsccPath)) {
    $defaultCandidates = @(
        "C:\\Program Files (x86)\\Inno Setup 6\\ISCC.exe",
        "C:\\Program Files\\Inno Setup 6\\ISCC.exe"
    )

    foreach ($candidate in $defaultCandidates) {
        if (Test-Path $candidate) {
            $IsccPath = $candidate
            break
        }
    }
}

if ([string]::IsNullOrWhiteSpace($IsccPath) -or -not (Test-Path $IsccPath)) {
    throw "Inno Setup Compiler (ISCC.exe) was not found. Install Inno Setup 6 or pass -IsccPath explicitly."
}

& $IsccPath "/DMyAppVersion=$Version" $setupScript
if ($LASTEXITCODE -ne 0) {
    throw "ISCC failed with exit code $LASTEXITCODE"
}

Write-Output "Installer build complete. Check dist\\installer"
