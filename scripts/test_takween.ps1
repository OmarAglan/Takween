[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$BaaPath
)

$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$buildScript = Join-Path $PSScriptRoot 'build_takween.ps1'
$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("takween-tests-" + [guid]::NewGuid().ToString('N'))

function Invoke-ExpectedSuccess([string]$Program, [string[]]$Arguments, [string]$Label) {
    $output = & $Program @Arguments 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0) {
        throw "$Label failed with exit code $LASTEXITCODE`n$output"
    }
    return $output
}

function Invoke-ExpectedFailure([string]$Program, [string[]]$Arguments, [string]$Label) {
    $output = & $Program @Arguments 2>&1 | Out-String
    if ($LASTEXITCODE -eq 0) {
        throw "$Label unexpectedly succeeded.`n$output"
    }
    return $output
}

$resolvedBaa = (Get-Command $BaaPath -ErrorAction Stop).Source
$baaDirectory = Split-Path -Parent $resolvedBaa
$oldPath = $env:PATH
$baaStdlib = $null
$probe = Get-Item -LiteralPath $baaDirectory
while ($probe -and -not $baaStdlib) {
    $candidate = Join-Path $probe.FullName 'stdlib'
    if (Test-Path -LiteralPath (Join-Path $candidate 'baalib.baahd')) {
        $baaStdlib = $candidate
        break
    }
    $probe = $probe.Parent
}
if (-not $baaStdlib) {
    throw 'Unable to locate Baa stdlib beside an ancestor of the selected compiler.'
}

try {
    $env:PATH = "$baaDirectory;$oldPath"
    Write-Output "Testing with Baa: $resolvedBaa"
    & $resolvedBaa --version
    if ($LASTEXITCODE -ne 0) {
        throw "Unable to execute the selected Baa compiler."
    }

    & $buildScript -Version '0.1.0' -BaaPath $resolvedBaa -BaaStdlibPath $baaStdlib
    $takween = Join-Path $root 'dist\bin\takween.exe'
    if (-not (Test-Path -LiteralPath $takween)) {
        throw "Takween executable was not produced: $takween"
    }

    $help = Invoke-ExpectedSuccess $takween @('--help') 'help contract'
    if ($help -notmatch 'Takween') { throw 'Help output does not contain the portable command name.' }

    $version = Invoke-ExpectedSuccess $takween @('--version') 'version contract'
    if ($version -notmatch '0\.1\.0') { throw 'Version output does not contain 0.1.0.' }

    New-Item -ItemType Directory -Force $tempRoot | Out-Null
    Push-Location $tempRoot
    try {
        Invoke-ExpectedSuccess $takween @('init') 'init workflow' | Out-Null
        $manifestPath = Get-ChildItem -LiteralPath $tempRoot -File | Select-Object -First 1
        $sourcePath = Get-ChildItem -LiteralPath $tempRoot -Recurse -File -Filter '*.baa' |
            Where-Object { $_.Extension -eq '.baa' } |
            Select-Object -First 1
        if (-not $manifestPath) { throw 'init did not create a project manifest.' }
        if (-not $sourcePath) { throw 'init did not create the main source.' }

        Invoke-ExpectedSuccess $takween @('build') 'build workflow' | Out-Null
        $builtExe = Get-ChildItem -LiteralPath $tempRoot -Recurse -File -Filter '*.exe' | Select-Object -First 1
        if (-not $builtExe) { throw 'build did not create an executable.' }
        $buildDirectory = $builtExe.Directory.FullName

        Invoke-ExpectedSuccess $takween @('run') 'run workflow' | Out-Null
        Invoke-ExpectedSuccess $takween @('clean') 'clean workflow' | Out-Null
        if (Test-Path -LiteralPath $buildDirectory) { throw 'clean did not remove the build directory.' }

        Add-Content -Encoding ascii -LiteralPath $manifestPath.FullName -Value 'unknown_key: value'
        Invoke-ExpectedFailure $takween @('build') 'unknown-key rejection' | Out-Null

        $manifestLines = @(Get-Content -Encoding utf8 -LiteralPath $manifestPath.FullName)
        $manifestLines = @($manifestLines | Where-Object { $_ -notmatch '^unknown_key:' })
        if ($manifestLines.Count -lt 5 -or $manifestLines[4] -notmatch ':') {
            throw 'Generated manifest does not have the expected v0 field order.'
        }
        $manifestLines[4] = ($manifestLines[4] -split ':', 2)[0] + ': .'
        Set-Content -Encoding utf8 -LiteralPath $manifestPath.FullName -Value $manifestLines
        Invoke-ExpectedFailure $takween @('clean') 'unsafe-clean rejection' | Out-Null
    } finally {
        Pop-Location
    }

    Write-Output 'Takween smoke tests passed.'
    $global:LASTEXITCODE = 0
} finally {
    $env:PATH = $oldPath
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -Recurse -Force -LiteralPath $tempRoot
    }
}
