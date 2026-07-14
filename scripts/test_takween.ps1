[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$BaaPath
)

$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$buildScript = Join-Path $PSScriptRoot 'build_takween.ps1'
$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("takween-tests-" + [guid]::NewGuid().ToString('N'))
$utf8NoBom = New-Object Text.UTF8Encoding($false)

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

function Invoke-ExpectedExitCode(
    [string]$Program,
    [string[]]$Arguments,
    [int]$ExpectedExitCode,
    [string]$Label
) {
    $output = & $Program @Arguments 2>&1 | Out-String
    $actualExitCode = $LASTEXITCODE
    if ($actualExitCode -ne $ExpectedExitCode) {
        throw "$Label returned $actualExitCode instead of $ExpectedExitCode.`n$output"
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
    $env:PATH = "$baaDirectory$([IO.Path]::PathSeparator)$oldPath"
    Write-Output "Testing with Baa: $resolvedBaa"
    & $resolvedBaa --version
    if ($LASTEXITCODE -ne 0) {
        throw "Unable to execute the selected Baa compiler."
    }

    $targetInfoText = & $resolvedBaa --target-info=json 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0) {
        throw "Baa target discovery failed.`n$targetInfoText"
    }
    $targetInfo = $targetInfoText | ConvertFrom-Json
    if ($targetInfo.schema_version -ne 'target-info-v1') {
        throw 'Baa target discovery did not return target-info-v1.'
    }
    $hostTarget = @($targetInfo.targets | Where-Object { $_.name -eq $targetInfo.host_target })[0]
    if (-not $hostTarget -or -not $hostTarget.capabilities.link) {
        throw 'Baa host target is missing or does not support linking.'
    }
    $hostSuffix = [string]$hostTarget.executable_suffix

    & $buildScript -Version '0.1.0' -BaaPath $resolvedBaa -BaaStdlibPath $baaStdlib
    $takween = Join-Path $root ("dist/bin/takween" + $hostSuffix)
    if (-not (Test-Path -LiteralPath $takween)) {
        throw "Takween executable was not produced: $takween"
    }

    $executorSource = Get-ChildItem -LiteralPath $root -Directory |
        ForEach-Object { Get-ChildItem -LiteralPath $_.FullName -File -Filter '*.baa' } |
        ForEach-Object { Get-Content -Raw -Encoding utf8 -LiteralPath $_.FullName } |
        Out-String
    $legacyExecute = -join [char[]](0x0646, 0x0641, 0x0630, 0x005F, 0x0623, 0x0645, 0x0631)
    if ($executorSource -match 'cmd\s+/c' -or $executorSource.Contains($legacyExecute)) {
        throw 'Takween executor regressed to shell command strings.'
    }

    $help = Invoke-ExpectedSuccess $takween @('--help') 'help contract'
    if ($help -notmatch 'Takween') { throw 'Help output does not contain the portable command name.' }

    Invoke-ExpectedExitCode $takween @() 2 'missing command exit contract' | Out-Null
    Invoke-ExpectedExitCode $takween @('unknown-command') 2 'unknown command exit contract' | Out-Null

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

        $check = Invoke-ExpectedSuccess $takween @('check') 'check workflow'
        $checkData = $check | ConvertFrom-Json
        if ($checkData.schema_version -ne 'diagnostics-json-v1') {
            throw 'check did not forward the diagnostics-json-v1 contract.'
        }
        if (@($checkData.diagnostics).Count -ne 0) {
            throw 'check reported diagnostics for the generated valid project.'
        }

        Invoke-ExpectedSuccess $takween @('build') 'build workflow' | Out-Null
        $buildManifestItem = Get-ChildItem -LiteralPath $tempRoot -Recurse -File -Filter 'build-manifest.json' |
            Select-Object -First 1
        if (-not $buildManifestItem) {
            throw 'build did not emit build-manifest.json.'
        }
        $buildManifest = $buildManifestItem.FullName
        $buildDirectory = $buildManifestItem.Directory.FullName
        $builtExe = Get-ChildItem -LiteralPath $buildDirectory -File |
            Where-Object { $_.Name -ne 'build-manifest.json' -and $_.Name.EndsWith($hostSuffix) } |
            Select-Object -First 1
        if (-not $builtExe) { throw 'build did not create an executable with the discovered host suffix.' }
        $discoveryManifest = Join-Path $buildDirectory '.takween-cache/target-info.json'
        $discoveryData = Get-Content -Raw -Encoding utf8 -LiteralPath $discoveryManifest | ConvertFrom-Json
        if ($discoveryData.schema_version -ne 'target-info-v1') {
            throw 'Takween did not cache the Baa target-info-v1 discovery document.'
        }
        $firstBuildData = Get-Content -Raw -Encoding utf8 -LiteralPath $buildManifest | ConvertFrom-Json
        if ($firstBuildData.schema -ne 1 -or -not $firstBuildData.incremental) {
            throw 'build manifest does not expose schema 1 incremental state.'
        }

        Invoke-ExpectedSuccess $takween @('build') 'incremental rebuild workflow' | Out-Null
        $secondBuildData = Get-Content -Raw -Encoding utf8 -LiteralPath $buildManifest | ConvertFrom-Json
        $cacheHits = @($secondBuildData.units | Where-Object { $_.cache.hit })
        if ($cacheHits.Count -lt 1) {
            throw 'incremental rebuild did not report a cache hit.'
        }

        Invoke-ExpectedSuccess $takween @('run') 'run workflow' | Out-Null
        Invoke-ExpectedSuccess $takween @('clean') 'clean workflow' | Out-Null
        if (Test-Path -LiteralPath $buildDirectory) { throw 'clean did not remove the build directory.' }

        $manifestLines = @(Get-Content -Encoding utf8 -LiteralPath $manifestPath.FullName)
        if ($manifestLines.Count -lt 5 -or $manifestLines[4] -notmatch ':') {
            throw 'Generated manifest does not have the expected v0 field order.'
        }
        $originalOutputLine = $manifestLines[4]
        $manifestLines[4] = ($manifestLines[4] -split ':', 2)[0] + ': build & safe space/'
        Set-Content -Encoding utf8 -LiteralPath $manifestPath.FullName -Value $manifestLines
        Invoke-ExpectedSuccess $takween @('build') 'structured metacharacter path build' | Out-Null
        $structuredDirectory = Join-Path $tempRoot 'build & safe space'
        if (-not (Test-Path -LiteralPath $structuredDirectory)) {
            throw 'Structured argv build did not preserve the metacharacter output path.'
        }
        Invoke-ExpectedSuccess $takween @('run') 'structured metacharacter path run' | Out-Null
        Invoke-ExpectedSuccess $takween @('clean') 'structured metacharacter path clean' | Out-Null
        if (Test-Path -LiteralPath $structuredDirectory) {
            throw 'Structured clean did not remove the metacharacter output path.'
        }

        $manifestLines[4] = $originalOutputLine
        Set-Content -Encoding utf8 -LiteralPath $manifestPath.FullName -Value $manifestLines

        Add-Content -Encoding utf8 -LiteralPath $manifestPath.FullName -Value 'أعلام_إضافية: & whoami'
        Invoke-ExpectedFailure $takween @('build') 'free-form flag rejection' | Out-Null
        $manifestLines = @(Get-Content -Encoding utf8 -LiteralPath $manifestPath.FullName)
        $manifestLines = @($manifestLines | Where-Object { $_ -notmatch '^أعلام_إضافية:' })
        Set-Content -Encoding utf8 -LiteralPath $manifestPath.FullName -Value $manifestLines

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

    $v1Root = Join-Path $tempRoot 'v1-path-dependency'
    New-Item -ItemType Directory -Force $v1Root | Out-Null
    Get-ChildItem -Force -LiteralPath (Join-Path $root 'tests/fixtures/v1_path_dependency') |
        Copy-Item -Destination $v1Root -Recurse -Force
    Push-Location $v1Root
    try {
        $v1Check = Invoke-ExpectedSuccess $takween @('check') 'v1 typed check workflow'
        $v1CheckData = $v1Check | ConvertFrom-Json
        if ($v1CheckData.schema_version -ne 'diagnostics-json-v1' -or
            @($v1CheckData.diagnostics).Count -ne 0) {
            throw 'v1 typed check did not preserve the diagnostics contract.'
        }

        Invoke-ExpectedSuccess $takween @('build') 'v1 typed path dependency build' | Out-Null
        $v1BuildDirectory = Join-Path $v1Root 'build & typed safe'
        $v1BuildManifest = Join-Path $v1BuildDirectory 'build-manifest.json'
        if (-not (Test-Path -LiteralPath $v1BuildManifest)) {
            throw 'v1 build did not emit a build manifest in the typed output path.'
        }
        $v1BuildData = Get-Content -Raw -Encoding utf8 -LiteralPath $v1BuildManifest | ConvertFrom-Json
        if (@($v1BuildData.units).Count -lt 3) {
            throw 'v1 path dependency sources were not included in the compiler build plan.'
        }

        $v1LockPath = Join-Path $v1Root 'تكوين.قفل'
        $v1LockHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $v1LockPath).Hash
        $originalV1Manifest = Get-Content -Raw -Encoding utf8 -LiteralPath (Join-Path $v1Root 'مشروع.تكوين')
        Invoke-ExpectedSuccess $takween @('check', '--locked') 'matching locked path resolution' | Out-Null
        if ((Get-FileHash -Algorithm SHA256 -LiteralPath $v1LockPath).Hash -ne $v1LockHash) {
            throw '--locked changed the existing deterministic lock.'
        }
        $changedV1Manifest = $originalV1Manifest.Replace('الإصدار = "1.0.0"', 'الإصدار = "1.0.1"')
        [IO.File]::WriteAllText((Join-Path $v1Root 'مشروع.تكوين'), $changedV1Manifest, $utf8NoBom)
        $lockedMismatch = Invoke-ExpectedFailure $takween @('check', '--locked') 'stale locked path rejection'
        if ($lockedMismatch -notmatch 'مقفل|locked') {
            throw 'Stale lock rejection did not report the typed locked-mode diagnostic.'
        }
        if ((Get-FileHash -Algorithm SHA256 -LiteralPath $v1LockPath).Hash -ne $v1LockHash) {
            throw 'Failed --locked verification replaced the existing lock.'
        }
        if (Test-Path -LiteralPath (Join-Path $v1Root '.takween/lock-candidate.json')) {
            throw '--locked left its candidate lock behind.'
        }
        [IO.File]::WriteAllText((Join-Path $v1Root 'مشروع.تكوين'), $originalV1Manifest, $utf8NoBom)

        $v1Run = Invoke-ExpectedSuccess $takween @('run') 'v1 typed path dependency run'
        if ($v1Run -notmatch 'typed path dependency ok') {
            throw 'v1 path dependency executable did not run the dependency-backed behavior.'
        }
        Invoke-ExpectedSuccess $takween @('clean') 'v1 typed clean' | Out-Null
        if (Test-Path -LiteralPath $v1BuildDirectory) {
            throw 'v1 typed clean did not remove the configured output tree.'
        }

        $nonHostTarget = @($targetInfo.targets | Where-Object { $_.name -ne $targetInfo.host_target })[0].name
        $crossTargetManifest = $originalV1Manifest.Replace(
            "[البناء]", "[البناء]`nالهدف = `"$nonHostTarget`"")
        [IO.File]::WriteAllText((Join-Path $v1Root 'مشروع.تكوين'), $crossTargetManifest, $utf8NoBom)
        $crossCheck = Invoke-ExpectedSuccess $takween @('check') 'cross-target typed check'
        $crossCheckData = $crossCheck | ConvertFrom-Json
        if ($crossCheckData.schema_version -ne 'diagnostics-json-v1' -or
            @($crossCheckData.diagnostics).Count -ne 0) {
            throw 'Cross-target check did not preserve diagnostics-json-v1.'
        }
        $crossLock = Get-Content -Raw -Encoding utf8 -LiteralPath (Join-Path $v1Root 'تكوين.قفل') | ConvertFrom-Json
        if ($crossLock.baa.target -ne $nonHostTarget) {
            throw 'Cross-target check did not record the requested Baa target in تكوين.قفل.'
        }
        [IO.File]::WriteAllText((Join-Path $v1Root 'مشروع.تكوين'), $originalV1Manifest, $utf8NoBom)
    } finally {
        Pop-Location
    }

    $invalidV1Root = Join-Path $tempRoot 'v1-invalid'
    New-Item -ItemType Directory -Force $invalidV1Root | Out-Null
    Get-ChildItem -Force -LiteralPath (Join-Path $root 'tests/fixtures/v1_invalid_unknown_key') |
        Copy-Item -Destination $invalidV1Root -Recurse -Force
    Push-Location $invalidV1Root
    try {
        Invoke-ExpectedFailure $takween @('check') 'v1 unknown-key rejection' | Out-Null
    } finally {
        Pop-Location
    }

    $archiveRoot = Join-Path $tempRoot 'local-archive-index'
    $archiveFiles = Join-Path $archiveRoot 'archives'
    $archiveCache = Join-Path $archiveRoot 'sha256'
    New-Item -ItemType Directory -Force $archiveFiles, $archiveCache | Out-Null
    $indexRows = [Collections.Generic.List[string]]::new()
    $archiveRecords = @{}
    foreach ($candidate in @(
        @{ Version = '2.0.0'; Value = '200' },
        @{ Version = '1.0.0'; Value = '100' },
        @{ Version = '1.1.0-alpha.1'; Value = '110' },
        @{ Version = '1.2.0'; Value = '120' },
        @{ Version = '1.2.0+build.1'; Value = '121' }
    )) {
        $archivePath = Join-Path $archiveFiles ("archive_lib-$($candidate.Version).tkw")
        [IO.File]::WriteAllText($archivePath, "takween-archive-v1:$($candidate.Version)`n", $utf8NoBom)
        $digest = (Get-FileHash -Algorithm SHA256 -LiteralPath $archivePath).Hash.ToLowerInvariant()
        $contentRoot = Join-Path $archiveCache $digest
        New-Item -ItemType Directory -Force (Join-Path $contentRoot 'src'), (Join-Path $contentRoot 'include') | Out-Null
        $packageManifest = @"
[المشروع]
الاسم = "archive_lib"
الإصدار = "$($candidate.Version)"

[الأهداف.archive_lib]
النوع = "مكتبة"
المدخل = "src/lib.baa"
مسارات_التضمين = ["include"]

[البناء]
المخرج = "build"
النمط = "dev"

[الأنماط.dev]
التحسين = 1
التحقق = خطأ
"@
        [IO.File]::WriteAllText((Join-Path $contentRoot 'مشروع.تكوين'), $packageManifest, $utf8NoBom)
        [IO.File]::WriteAllText(
            (Join-Path $contentRoot 'include/archive_lib.baahd'),
            "صحيح قيمة_أرشيف().`n",
            $utf8NoBom)
        [IO.File]::WriteAllText(
            (Join-Path $contentRoot 'src/lib.baa'),
            "صحيح قيمة_أرشيف() { إرجع $($candidate.Value). }`n",
            $utf8NoBom)
        $indexRows.Add("archive_lib`t$($candidate.Version)`t$digest`t$archivePath`t$contentRoot")
        $archiveRecords[$candidate.Version] = @{
            Archive = $archivePath
            Digest = $digest
            Content = $contentRoot
            Bytes = [IO.File]::ReadAllBytes($archivePath)
        }
    }
    $indexPath = Join-Path $archiveRoot 'index.tsv'
    [IO.File]::WriteAllText(
        $indexPath,
        "takween-index-v1`n" + (($indexRows -join "`n") + "`n"),
        $utf8NoBom)

    $archiveProject = Join-Path $tempRoot 'v1-archive-dependency'
    New-Item -ItemType Directory -Force (Join-Path $archiveProject 'src') | Out-Null
    $archiveProjectManifest = @'
[المشروع]
الاسم = "archive_app"
الإصدار = "1.0.0"
إصدار_باء = ">=0.6.0 <0.8.0"

[الأهداف.archive_app]
النوع = "تنفيذي"
المدخل = "src/main.baa"

[البناء]
المخرج = "build"
النمط = "dev"

[الأنماط.dev]
التحسين = 1
التحقق = صواب

[الاعتماديات.archive_lib]
الإصدار = "^1.0.0"
'@
    [IO.File]::WriteAllText((Join-Path $archiveProject 'مشروع.تكوين'), $archiveProjectManifest, $utf8NoBom)
    $archiveMain = @'
#تضمين "archive_lib.baahd"

صحيح الرئيسية() {
    إذا (قيمة_أرشيف() != ١٢١) { إرجع ١. }
    اطبع "semver archive dependency ok".
    إرجع ٠.
}
'@
    [IO.File]::WriteAllText((Join-Path $archiveProject 'src/main.baa'), $archiveMain, $utf8NoBom)

    $oldPackageIndex = $env:TAKWEEN_PACKAGE_INDEX
    $env:TAKWEEN_PACKAGE_INDEX = $indexPath
    Push-Location $archiveProject
    try {
        Invoke-ExpectedSuccess $takween @('build') 'SemVer local archive build' | Out-Null
        $archiveRun = Invoke-ExpectedSuccess $takween @('run', '--locked') 'locked offline archive run'
        if ($archiveRun -notmatch 'semver archive dependency ok') {
            throw 'The highest compatible local archive was not selected and linked.'
        }
        $archiveLockPath = Join-Path $archiveProject 'تكوين.قفل'
        $archiveLockHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $archiveLockPath).Hash
        $archiveLock = Get-Content -Raw -Encoding utf8 -LiteralPath $archiveLockPath | ConvertFrom-Json
        $archiveNode = @($archiveLock.packages | Where-Object { $_.source.kind -eq 'archive' })[0]
        if (-not $archiveNode -or $archiveNode.version -ne '1.2.0+build.1' -or
            $archiveNode.source.constraint -ne '^1.0.0' -or
            $archiveNode.source.sha256 -ne $archiveRecords['1.2.0+build.1'].Digest -or
            $archiveNode.source.index -ne $indexPath -or
            $archiveNode.source.archive -ne $archiveRecords['1.2.0+build.1'].Archive) {
            throw 'Archive lock node does not preserve the exact SemVer choice and immutable SHA-256 source.'
        }
        if ((Get-FileHash -Algorithm SHA256 -LiteralPath $archiveLockPath).Hash -ne $archiveLockHash) {
            throw 'Locked offline archive resolution changed the lock bytes.'
        }

        [IO.File]::WriteAllBytes($archiveRecords['1.2.0+build.1'].Archive, [byte[]](1, 2, 3, 4))
        $tamperFailure = Invoke-ExpectedFailure $takween @('check', '--locked') 'tampered archive rejection'
        if ($tamperFailure -notmatch 'SHA-256') {
            throw 'Tampered archive rejection did not identify the immutable hash contract.'
        }
        [IO.File]::WriteAllBytes($archiveRecords['1.2.0+build.1'].Archive, $archiveRecords['1.2.0+build.1'].Bytes)

        foreach ($rangeCase in @(
            @{ Constraint = '>=1.0.0 <2.0.0'; Expected = '1.2.0+build.1' },
            @{ Constraint = '~1.0.0'; Expected = '1.0.0' },
            @{ Constraint = '1.1.0-alpha.1'; Expected = '1.1.0-alpha.1' }
        )) {
            $rangeManifest = $archiveProjectManifest.Replace('^1.0.0', $rangeCase.Constraint)
            [IO.File]::WriteAllText((Join-Path $archiveProject 'مشروع.تكوين'), $rangeManifest, $utf8NoBom)
            Invoke-ExpectedSuccess $takween @('check') "SemVer range $($rangeCase.Constraint)" | Out-Null
            $rangeLock = Get-Content -Raw -Encoding utf8 -LiteralPath $archiveLockPath | ConvertFrom-Json
            $rangeNode = @($rangeLock.packages | Where-Object { $_.source.kind -eq 'archive' })[0]
            if (-not $rangeNode -or $rangeNode.version -ne $rangeCase.Expected) {
                throw "SemVer range $($rangeCase.Constraint) selected '$($rangeNode.version)' instead of '$($rangeCase.Expected)'."
            }
        }

        $incompatibleManifest = $archiveProjectManifest.Replace('^1.0.0', '<1.0.0')
        [IO.File]::WriteAllText((Join-Path $archiveProject 'مشروع.تكوين'), $incompatibleManifest, $utf8NoBom)
        $conflictFailure = Invoke-ExpectedFailure $takween @('check') 'SemVer conflict rejection'
        if ($conflictFailure -notmatch 'إصدار|version') {
            throw 'SemVer conflict did not produce an explicit resolution diagnostic.'
        }

        $invalidRangeManifest = $archiveProjectManifest.Replace('^1.0.0', '1.x')
        [IO.File]::WriteAllText((Join-Path $archiveProject 'مشروع.تكوين'), $invalidRangeManifest, $utf8NoBom)
        $invalidRangeFailure = Invoke-ExpectedFailure $takween @('check') 'invalid SemVer range rejection'
        if ($invalidRangeFailure -notmatch 'قيد|Semantic') {
            throw 'Invalid SemVer range did not fail at the typed manifest boundary.'
        }
        [IO.File]::WriteAllText((Join-Path $archiveProject 'مشروع.تكوين'), $archiveProjectManifest, $utf8NoBom)
    } finally {
        Pop-Location
        $env:TAKWEEN_PACKAGE_INDEX = $oldPackageIndex
    }

    $gitProgram = (Get-Command git -ErrorAction Stop).Source
    $gitPackageRoot = Join-Path $tempRoot 'git-package-source'
    New-Item -ItemType Directory -Force $gitPackageRoot | Out-Null
    Get-ChildItem -Force -LiteralPath (Join-Path $root 'tests/fixtures/v1_git_package') |
        Copy-Item -Destination $gitPackageRoot -Recurse -Force
    Push-Location $gitPackageRoot
    try {
        Invoke-ExpectedSuccess $gitProgram @('init', '--quiet') 'local Git package init' | Out-Null
        Invoke-ExpectedSuccess $gitProgram @('config', 'user.name', 'Takween Smoke') 'local Git user name' | Out-Null
        Invoke-ExpectedSuccess $gitProgram @('config', 'user.email', 'takween-smoke@example.invalid') 'local Git user email' | Out-Null
        Invoke-ExpectedSuccess $gitProgram @('config', 'core.autocrlf', 'false') 'local Git line endings' | Out-Null
        Invoke-ExpectedSuccess $gitProgram @('add', '.') 'local Git package add' | Out-Null
        Invoke-ExpectedSuccess $gitProgram @('commit', '--quiet', '-m', 'fixture package') 'local Git package commit' | Out-Null
        $gitCommit = (Invoke-ExpectedSuccess $gitProgram @('rev-parse', 'HEAD') 'local Git package HEAD').Trim()
    } finally {
        Pop-Location
    }
    if ($gitCommit -notmatch '^[0-9a-f]{40}([0-9a-f]{24})?$') {
        throw "Local Git fixture did not produce an exact commit id: $gitCommit"
    }

    $gitProjectRoot = Join-Path $tempRoot 'v1-git-dependency'
    New-Item -ItemType Directory -Force (Join-Path $gitProjectRoot 'src') | Out-Null
    $gitSourceForManifest = $gitPackageRoot.Replace('\', '/')
    $gitManifest = @"
[المشروع]
الاسم = "git_dep_app"
الإصدار = "1.0.0"
إصدار_باء = ">=0.6.0 <0.8.0"

[الأهداف.git_dep_app]
النوع = "تنفيذي"
المدخل = "src/main.baa"

[البناء]
المخرج = "build git"
النمط = "dev"

[الأنماط.dev]
التحسين = 1
التحقق = صواب

[الاعتماديات.git_lib]
git = "$gitSourceForManifest"
commit = "$gitCommit"
"@
    [IO.File]::WriteAllText((Join-Path $gitProjectRoot 'مشروع.تكوين'), $gitManifest, $utf8NoBom)
    $gitMain = @'
#تضمين "git_lib.baahd"

صحيح الرئيسية() {
    إذا (قيمة_جت() != ٨٤) { إرجع ١. }
    اطبع "pinned git dependency ok".
    إرجع ٠.
}
'@
    [IO.File]::WriteAllText((Join-Path $gitProjectRoot 'src/main.baa'), $gitMain, $utf8NoBom)

    Push-Location $gitProjectRoot
    try {
        $gitCheck = Invoke-ExpectedSuccess $takween @('check') 'pinned Git dependency check'
        $gitCheckData = $gitCheck | ConvertFrom-Json
        if ($gitCheckData.schema_version -ne 'diagnostics-json-v1' -or
            @($gitCheckData.diagnostics).Count -ne 0) {
            throw 'Pinned Git dependency check did not preserve diagnostics-json-v1.'
        }
        Invoke-ExpectedSuccess $takween @('build') 'pinned Git dependency build' | Out-Null
        $gitRun = Invoke-ExpectedSuccess $takween @('run') 'pinned Git dependency run'
        if ($gitRun -notmatch 'pinned git dependency ok') {
            throw 'Pinned Git dependency executable did not run transitive package behavior.'
        }

        $lockPath = Join-Path $gitProjectRoot 'تكوين.قفل'
        if (-not (Test-Path -LiteralPath $lockPath)) { throw 'Pinned Git resolution did not create تكوين.قفل.' }
        $lockBytes = [IO.File]::ReadAllBytes($lockPath)
        if ([Array]::IndexOf($lockBytes, [byte]13) -ge 0) {
            throw 'تكوين.قفل must use canonical LF bytes on every platform.'
        }
        $firstLockHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $lockPath).Hash
        $lockData = Get-Content -Raw -Encoding utf8 -LiteralPath $lockPath | ConvertFrom-Json
        if ($lockData.schema_version -ne 'takween-lock-v1' -or
            $lockData.resolver_version -ne '0.2.0' -or
            $lockData.baa.target -ne $targetInfo.selected_target) {
            throw 'تكوين.قفل metadata does not match the stable lock/target contracts.'
        }
        if (@($lockData.packages).Count -ne 2) {
            throw 'The deterministic lock must include the Git package and its transitive path package.'
        }
        $lockedGit = @($lockData.packages | Where-Object { $_.source.kind -eq 'git' })[0]
        $lockedNested = @($lockData.packages | Where-Object { $_.source.kind -eq 'path' })[0]
        if (-not $lockedGit -or $lockedGit.source.commit -ne $gitCommit -or
            $lockedGit.source.url -ne $gitSourceForManifest -or $lockedGit.parent -ne 'root') {
            throw 'The Git lock node does not preserve its exact source, commit, and root edge.'
        }
        if (-not $lockedNested -or $lockedNested.parent -ne 'root/git_lib' -or
            $lockedNested.source.path -notmatch ([regex]::Escape(".takween/packages/$gitCommit/nested"))) {
            throw 'The transitive path lock node is missing or not attached to the Git package.'
        }
        $cachedCheckout = Join-Path $gitProjectRoot ".takween/packages/$gitCommit"
        if (-not (Test-Path -LiteralPath (Join-Path $cachedCheckout 'مشروع.تكوين'))) {
            throw 'Pinned Git dependency was not materialized in the commit-addressed cache.'
        }
        $cacheJunk = Join-Path $cachedCheckout 'untracked-junk.tmp'
        [IO.File]::WriteAllText($cacheJunk, 'junk', [Text.Encoding]::ASCII)
        [IO.File]::WriteAllText((Join-Path $cachedCheckout 'src/lib.baa'), 'corrupted cache', [Text.Encoding]::ASCII)

        $unavailableSource = Join-Path $tempRoot 'git-package-source-unavailable'
        Move-Item -LiteralPath $gitPackageRoot -Destination $unavailableSource
        Invoke-ExpectedSuccess $takween @('build') 'offline pinned Git cache reuse' | Out-Null
        if (Test-Path -LiteralPath $cacheJunk) {
            throw 'Pinned Git cache reuse did not clean untracked content.'
        }
        $secondLockHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $lockPath).Hash
        if ($secondLockHash -ne $firstLockHash) {
            throw 'Repeated offline resolution changed deterministic تكوين.قفل bytes.'
        }
        $cachedRun = Invoke-ExpectedSuccess $takween @('run') 'offline pinned Git run'
        if ($cachedRun -notmatch 'pinned git dependency ok') {
            throw 'Commit-addressed cache reuse did not preserve executable behavior.'
        }
    } finally {
        Pop-Location
    }

    $branchManifestRoot = Join-Path $tempRoot 'v1-git-branch-invalid'
    Copy-Item -LiteralPath $gitProjectRoot -Destination $branchManifestRoot -Recurse -Force
    $branchManifestPath = Join-Path $branchManifestRoot 'مشروع.تكوين'
    $branchManifestText = (Get-Content -Raw -Encoding utf8 -LiteralPath $branchManifestPath).Replace(
        "commit = `"$gitCommit`"", 'commit = main')
    [IO.File]::WriteAllText($branchManifestPath, $branchManifestText, $utf8NoBom)
    Push-Location $branchManifestRoot
    try {
        $branchFailure = Invoke-ExpectedFailure $takween @('check') 'moving Git ref rejection'
        if ($branchFailure -notmatch 'commit') {
            throw 'Moving Git ref rejection did not return the typed commit diagnostic.'
        }
    } finally {
        Pop-Location
    }

    $mixedManifestRoot = Join-Path $tempRoot 'v1-git-mixed-invalid'
    Copy-Item -LiteralPath $gitProjectRoot -Destination $mixedManifestRoot -Recurse -Force
    $mixedManifestPath = Join-Path $mixedManifestRoot 'مشروع.تكوين'
    [IO.File]::AppendAllText($mixedManifestPath, "`nالمسار = `"local`"`n", $utf8NoBom)
    Push-Location $mixedManifestRoot
    try {
        Invoke-ExpectedFailure $takween @('check') 'mixed dependency source rejection' | Out-Null
    } finally {
        Pop-Location
    }

    $multiRoot = Join-Path $tempRoot 'v1-multi-target'
    New-Item -ItemType Directory -Force $multiRoot | Out-Null
    Get-ChildItem -Force -LiteralPath (Join-Path $root 'tests/fixtures/v1_multi_target') |
        Copy-Item -Destination $multiRoot -Recurse -Force
    Push-Location $multiRoot
    try {
        $targetJson = Invoke-ExpectedSuccess $takween @('targets', '--json') 'target status contract'
        $targetData = $targetJson | ConvertFrom-Json
        if ($targetData.schema_version -ne 'takween-targets-v1' -or @($targetData.targets).Count -ne 4) {
            throw 'Multi-target status did not expose takween-targets-v1 with four targets.'
        }
        $tests = @($targetData.targets | Where-Object { $_.test -and $_.status -eq 'ready' })
        $library = @($targetData.targets | Where-Object { $_.kind -eq 'library' })
        if ($tests.Count -ne 2 -or $library.Count -ne 1 -or $library[0].buildable) {
            throw 'Target status kinds/capabilities are inconsistent.'
        }

        Invoke-ExpectedSuccess $takween @('build', 'app') 'selected executable build' | Out-Null
        $appRun = Invoke-ExpectedSuccess $takween @('run', 'app') 'selected executable run'
        if ($appRun -notmatch 'multi target app ok') { throw 'Selected executable did not run.' }

        $oneTest = Invoke-ExpectedSuccess $takween @('test', 'test_a') 'selected test target'
        if ($oneTest -notmatch 'test target a ok' -or $oneTest -match 'test target b ok') {
            throw 'Selected test command did not isolate the requested target.'
        }
        $allTests = Invoke-ExpectedSuccess $takween @('test') 'all test targets'
        if ($allTests -notmatch 'test target a ok' -or $allTests -notmatch 'test target b ok') {
            throw 'Test command did not run every test target.'
        }
        Invoke-ExpectedFailure $takween @('build', 'missing') 'missing target rejection' | Out-Null
        Invoke-ExpectedExitCode $takween @('build', 'helper') 3 'unsupported library target' | Out-Null
        Invoke-ExpectedExitCode $takween @('test', 'missing') 3 'missing test target' | Out-Null

        $fakeBin = Join-Path $multiRoot 'fake-baa-bin'
        $fakeSource = Join-Path $multiRoot 'fake-baa.baa'
        $fakeBaa = Join-Path $fakeBin ("baa" + $hostSuffix)
        New-Item -ItemType Directory -Force $fakeBin | Out-Null
        $activePath = $env:PATH
        $arabicExitDigits = @('١', '٢', '٣', '٤', '٥')
        try {
            foreach ($compilerExitCode in 1..5) {
                $digit = $arabicExitDigits[$compilerExitCode - 1]
                $fakeSourceText = "صحيح الرئيسية() { إرجع $digit. }`n"
                [IO.File]::WriteAllText($fakeSource, $fakeSourceText, $utf8NoBom)
                $env:PATH = $activePath
                Invoke-ExpectedSuccess $resolvedBaa @($fakeSource, '-o', $fakeBaa) `
                    "fake Baa exit $compilerExitCode build" | Out-Null
                $env:PATH = "$fakeBin$([IO.Path]::PathSeparator)$activePath"

                $contractCommands = @(
                    @{ Name = 'check'; Arguments = @('check') },
                    @{ Name = 'build'; Arguments = @('build', 'app') },
                    @{ Name = 'run'; Arguments = @('run', 'app') },
                    @{ Name = 'test'; Arguments = @('test', 'test_a') }
                )
                foreach ($command in $contractCommands) {
                    Invoke-ExpectedExitCode $takween $command.Arguments $compilerExitCode `
                        "compiler-cli-v1 code $compilerExitCode through $($command.Name)" | Out-Null
                }
            }
        } finally {
            $env:PATH = $activePath
        }
        Invoke-ExpectedSuccess $takween @('clean') 'multi-target clean' | Out-Null
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
