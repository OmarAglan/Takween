param(
    [string]$Installer = "",
    [string]$InstallDirectory = "",
    [string]$BaaDirectory = "",
    [string]$NazmDirectory = ""
)

$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
if ([string]::IsNullOrWhiteSpace($Installer)) {
    $Installer = Join-Path $root "dist\installer\takween-setup-0.1.0-x64.exe"
}
if ([string]::IsNullOrWhiteSpace($InstallDirectory)) {
    $InstallDirectory = Join-Path $env:LOCALAPPDATA "Temp\TakweenInstallerContract"
}
if ([string]::IsNullOrWhiteSpace($BaaDirectory)) {
    $BaaDirectory = Join-Path $root "..\Baa\build"
}
if ([string]::IsNullOrWhiteSpace($NazmDirectory)) {
    $NazmDirectory = Join-Path $root "..\Nazm\build\windows-release"
}

$Installer = (Resolve-Path -LiteralPath $Installer).Path
$BaaDirectory = (Resolve-Path -LiteralPath $BaaDirectory).Path
$NazmDirectory = (Resolve-Path -LiteralPath $NazmDirectory).Path
$checksumPath = $Installer + ".sha256"
if (-not (Test-Path -LiteralPath $checksumPath -PathType Leaf)) {
    throw "Installer checksum file was not found: $checksumPath"
}
$checksumLine = [IO.File]::ReadAllText($checksumPath, [Text.Encoding]::ASCII).Trim()
if ($checksumLine -notmatch '^([0-9A-Fa-f]{64}) \*(.+)$') {
    throw "Installer checksum file has an invalid format."
}
if ($Matches[2] -cne [IO.Path]::GetFileName($Installer)) {
    throw "Installer checksum names the wrong file."
}
$actualInstallerHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $Installer).Hash
if ($Matches[1] -ine $actualInstallerHash) {
    throw "Installer SHA-256 verification failed."
}

$takweenName = (-join [char[]](0x062A, 0x0643, 0x0648, 0x064A, 0x0646)) + ".exe"
$nazmName = (-join [char[]](0x0646, 0x0638, 0x0645)) + ".exe"
$initCommand = -join [char[]](0x062A, 0x0647, 0x064A, 0x0626, 0x0629)
$checkCommand = -join [char[]](0x0641, 0x062D, 0x0635)
$buildCommand = -join [char[]](0x0628, 0x0646, 0x0627, 0x0621)
$runCommand = -join [char[]](0x062A, 0x0634, 0x063A, 0x064A, 0x0644)
$cleanCommand = -join [char[]](0x062A, 0x0646, 0x0638, 0x064A, 0x0641)
$projectName = (-join [char[]](0x0645, 0x0634, 0x0631, 0x0648, 0x0639)) + " Takween Installer"

$baaExecutable = Join-Path $BaaDirectory "baa.exe"
$nazmExecutable = Join-Path $NazmDirectory $nazmName
foreach ($required in @($baaExecutable, $nazmExecutable)) {
    if (-not (Test-Path -LiteralPath $required -PathType Leaf)) {
        throw "Required installer dependency was not found: $required"
    }
}

$baaHome = $BaaDirectory
if (-not (Test-Path -LiteralPath (Join-Path $baaHome "stdlib\baalib.baahd") -PathType Leaf)) {
    $baaHome = Split-Path -Parent $BaaDirectory
}
$baaStdlib = Join-Path $baaHome "stdlib"
if (-not (Test-Path -LiteralPath (Join-Path $baaStdlib "baalib.baahd") -PathType Leaf)) {
    throw "Baa standard library was not found relative to $BaaDirectory."
}

if (Test-Path -LiteralPath $InstallDirectory) {
    throw "Installer test directory already exists: $InstallDirectory"
}
$projectDirectory = Join-Path $env:LOCALAPPDATA ("Temp\" + $projectName)
if (Test-Path -LiteralPath $projectDirectory) {
    throw "Installer project test directory already exists: $projectDirectory"
}

$takweenBin = Join-Path $InstallDirectory "bin"
$takweenExecutable = Join-Path $takweenBin $takweenName
$takweenAlias = Join-Path $takweenBin "takween.exe"
$uninstaller = Join-Path $InstallDirectory "unins000.exe"
$markerKey = "HKCU:\Software\BaaEcosystem\Takween"
$installed = $false

function Wait-InstallerState {
    param([string]$Description, [scriptblock]$Condition)
    for ($attempt = 0; $attempt -lt 300; $attempt++) {
        if (& $Condition) { return }
        Start-Sleep -Milliseconds 200
    }
    throw "Timed out waiting for $Description."
}

function Invoke-TakweenInstaller {
    $setupProcess = Start-Process -FilePath $Installer -ArgumentList @(
        "/VERYSILENT", "/SUPPRESSMSGBOXES", "/NORESTART", "/SP-",
        "/CURRENTUSER", "/DIR=$InstallDirectory"
    ) -WindowStyle Hidden -Wait -PassThru
    if ($setupProcess.ExitCode -ne 0) {
        throw "Takween installer failed with exit code $($setupProcess.ExitCode)."
    }
}

try {
    Invoke-TakweenInstaller
    $installed = $true
    Wait-InstallerState "Takween installation" {
        (Test-Path -LiteralPath $takweenExecutable -PathType Leaf) -and
        (Test-Path -LiteralPath $takweenAlias -PathType Leaf) -and
        (Test-Path -LiteralPath $uninstaller -PathType Leaf) -and
        (Test-Path -LiteralPath $markerKey)
    }
    Invoke-TakweenInstaller

    $pathValue = (Get-ItemProperty -Path "HKCU:\Environment" -Name Path).Path
    $pathMatches = @($pathValue -split ";" | Where-Object {
        $_.Trim().Trim('"').TrimEnd('\') -ieq $takweenBin.TrimEnd('\')
    })
    if ($pathMatches.Count -ne 1) { throw "Takween PATH entry was not added exactly once." }
    if ((Get-ItemPropertyValue -Path $markerKey -Name PathOwned) -ne 1) {
        throw "Takween installer did not record PATH ownership."
    }
    if ((Get-ItemPropertyValue -Path "HKCU:\Environment" -Name TAKWEEN_HOME) -ine
        $InstallDirectory) {
        throw "TAKWEEN_HOME does not point to the installation."
    }

    & $takweenExecutable --version
    if ($LASTEXITCODE -ne 0) { throw "Installed Arabic Takween version probe failed." }
    & $takweenAlias --version
    if ($LASTEXITCODE -ne 0) { throw "Installed Takween alias version probe failed." }

    [IO.Directory]::CreateDirectory($projectDirectory) | Out-Null
    $oldPath = $env:PATH
    $oldBaaHome = $env:BAA_HOME
    $oldBaaStdlib = $env:BAA_STDLIB
    $oldTakweenHome = $env:TAKWEEN_HOME
    $hadNazmOverride = Test-Path Env:BAA_NAZM
    $oldNazmOverride = $env:BAA_NAZM
    try {
        $env:PATH = "$takweenBin;$BaaDirectory;$NazmDirectory;$env:SystemRoot\System32;$env:SystemRoot"
        $env:BAA_HOME = $baaHome
        $env:BAA_STDLIB = $baaStdlib
        $env:TAKWEEN_HOME = $InstallDirectory
        Remove-Item Env:BAA_NAZM -ErrorAction SilentlyContinue
        Push-Location $projectDirectory
        try {
            & $takweenExecutable $initCommand
            if ($LASTEXITCODE -ne 0) { throw "Installed Takween init failed." }
            & $takweenExecutable $checkCommand
            if ($LASTEXITCODE -ne 0) { throw "Installed Takween check failed." }
            & $takweenExecutable $buildCommand
            if ($LASTEXITCODE -ne 0) { throw "Installed Takween build failed." }
            & $takweenExecutable $runCommand
            if ($LASTEXITCODE -ne 0) { throw "Installed Takween run failed." }
            & $takweenExecutable $cleanCommand
            if ($LASTEXITCODE -ne 0) { throw "Installed Takween clean failed." }
        }
        finally {
            Pop-Location
        }
    }
    finally {
        $env:PATH = $oldPath
        $env:BAA_HOME = $oldBaaHome
        $env:BAA_STDLIB = $oldBaaStdlib
        $env:TAKWEEN_HOME = $oldTakweenHome
        if ($hadNazmOverride) { $env:BAA_NAZM = $oldNazmOverride }
        else { Remove-Item Env:BAA_NAZM -ErrorAction SilentlyContinue }
    }
}
finally {
    if ($installed -and (Test-Path -LiteralPath $uninstaller -PathType Leaf)) {
        $uninstallProcess = Start-Process -FilePath $uninstaller -ArgumentList @(
            "/VERYSILENT", "/SUPPRESSMSGBOXES", "/NORESTART"
        ) -WindowStyle Hidden -Wait -PassThru
        if ($uninstallProcess.ExitCode -ne 0) {
            throw "Takween uninstaller failed with exit code $($uninstallProcess.ExitCode)."
        }
        Wait-InstallerState "Takween uninstall cleanup" {
            -not (Test-Path -LiteralPath $InstallDirectory) -and
            -not (Test-Path -LiteralPath $markerKey)
        }
    }
    foreach ($directory in @($projectDirectory)) {
        if (Test-Path -LiteralPath $directory) {
            $resolved = [IO.Path]::GetFullPath($directory)
            $tempRoot = [IO.Path]::GetFullPath((Join-Path $env:LOCALAPPDATA "Temp"))
            if (-not $resolved.StartsWith($tempRoot, [StringComparison]::OrdinalIgnoreCase)) {
                throw "Refusing to remove test output outside the user Temp directory."
            }
            Remove-Item -LiteralPath $resolved -Recurse -Force
        }
    }
}

$remainingPath = (Get-ItemProperty -Path "HKCU:\Environment" -Name Path).Path
$remainingMatches = @($remainingPath -split ";" | Where-Object {
    $_.Trim().Trim('"').TrimEnd('\') -ieq $takweenBin.TrimEnd('\')
})
if ($remainingMatches.Count -ne 0) { throw "Takween uninstaller left its PATH entry." }
if (Test-Path -LiteralPath $InstallDirectory) { throw "Takween uninstaller left installation files." }
if (Test-Path -LiteralPath $markerKey) { throw "Takween uninstaller left its ownership marker." }
$remainingEnvironment = Get-ItemProperty -Path "HKCU:\Environment"
if ($remainingEnvironment.TAKWEEN_HOME -ieq $InstallDirectory) {
    throw "Takween uninstaller left its owned TAKWEEN_HOME value."
}

Write-Output "Takween installer contract passed."
