param(
    [string]$TakweenPath = "",
    [string]$IndexPath = ""
)

# Tests each official library, then packs it into a local takween-index-v1.
# A version already in the index with other bytes is rejected: bump the library version.
$ErrorActionPreference = "Stop"

$root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
if (-not $TakweenPath) {
    $suffix = if ($IsLinux -or $IsMacOS) { "" } else { ".exe" }
    $TakweenPath = Join-Path $root "dist/bin/takween$suffix"
}
$takween = (Get-Command $TakweenPath -ErrorAction Stop).Source
if (-not $IndexPath) {
    $IndexPath = Join-Path $root "dist/حزم/index.tsv"
}
$IndexPath = [IO.Path]::GetFullPath($IndexPath)
New-Item -ItemType Directory -Force (Split-Path -Parent $IndexPath) | Out-Null

$libraries = @(Get-ChildItem -LiteralPath (Join-Path $root "مكتبات") -Directory | Sort-Object Name)
foreach ($library in $libraries) {
    Push-Location -LiteralPath $library.FullName
    try {
        & $takween test
        if ($LASTEXITCODE -ne 0) { throw "Tests failed for $($library.Name)." }
        & $takween pack --index $IndexPath
        if ($LASTEXITCODE -ne 0) { throw "Packing failed for $($library.Name)." }
    } finally {
        Pop-Location
    }
}
Write-Output "Official packages: $IndexPath"
