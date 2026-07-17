param(
    [switch]$Clean,
    [string]$Version = "1.0.0.0"
)

$ErrorActionPreference = "Stop"

if ($env:OS -ne "Windows_NT") {
    throw "Microsoft Store packages must be built on Windows."
}

$windowsRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent $windowsRoot
$manifestTemplatePath = Join-Path $windowsRoot "store\AppxManifest.xml.in"
$iconSourcePath = Join-Path $windowsRoot "build-assets\CodexVitals-1024.png"
$storeRoot = Join-Path $windowsRoot "build-store"
$packageRoot = Join-Path $storeRoot "package"
$assetsRoot = Join-Path $packageRoot "Assets"
$artifactRoot = Join-Path $repoRoot "ReleaseArtifacts\Store"

function Normalize-PackageVersion([string]$Value) {
    $parts = @($Value.Split("."))
    if ($parts.Count -lt 1 -or $parts.Count -gt 4) {
        throw "Store package version must contain one to four numeric parts."
    }
    $normalized = @()
    foreach ($part in $parts) {
        $parsed = 0
        if (-not [int]::TryParse($part, [ref]$parsed) -or $parsed -lt 0 -or $parsed -gt 65535) {
            throw "Invalid Store package version part: $part"
        }
        $normalized += $parsed
    }
    while ($normalized.Count -lt 4) {
        $normalized += 0
    }
    return ($normalized -join ".")
}

function Find-MakeAppx {
    $kitsRoot = Join-Path ${env:ProgramFiles(x86)} "Windows Kits\10\bin"
    $directPath = Join-Path $kitsRoot "x64\makeappx.exe"
    if (Test-Path -LiteralPath $directPath) {
        return $directPath
    }
    $candidate = Get-ChildItem -LiteralPath $kitsRoot -Filter makeappx.exe -File -Recurse -ErrorAction SilentlyContinue |
        Where-Object { $_.Directory.Name -eq "x64" } |
        Sort-Object FullName -Descending |
        Select-Object -First 1
    if (-not $candidate) {
        throw "MakeAppx.exe was not found. Install the Windows SDK before building the Store package."
    }
    return $candidate.FullName
}

$packageVersion = Normalize-PackageVersion $Version

& (Join-Path $windowsRoot "build.ps1") -Clean:$Clean -Channel Store -Version $packageVersion
if ($LASTEXITCODE -ne 0) {
    throw "The Store-channel executable build failed."
}

$builtExecutable = Join-Path $windowsRoot "dist\CodexVitals.exe"
$buildPython = Join-Path $windowsRoot ".venv-build\Scripts\python.exe"
if (-not (Test-Path -LiteralPath $builtExecutable)) {
    throw "Store-channel executable was not found: $builtExecutable"
}
if (-not (Test-Path -LiteralPath $buildPython)) {
    throw "Windows build Python was not found: $buildPython"
}

Remove-Item -LiteralPath $packageRoot -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $assetsRoot | Out-Null
New-Item -ItemType Directory -Force -Path $artifactRoot | Out-Null
Copy-Item -LiteralPath $builtExecutable -Destination (Join-Path $packageRoot "CodexVitals.exe") -Force

& $buildPython (Join-Path $windowsRoot "tools\generate_store_assets.py") `
    --source $iconSourcePath `
    --output $assetsRoot
if ($LASTEXITCODE -ne 0) {
    throw "Microsoft Store asset generation failed."
}

$manifest = Get-Content -LiteralPath $manifestTemplatePath -Raw
$manifest = $manifest.Replace("__PACKAGE_VERSION__", $packageVersion)
$utf8WithoutBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText(
    (Join-Path $packageRoot "AppxManifest.xml"),
    $manifest,
    $utf8WithoutBom
)

$makeAppx = Find-MakeAppx
$artifactName = "CodexVitals-Windows-Store-$packageVersion-x64.msix"
$artifactPath = Join-Path $artifactRoot $artifactName
Remove-Item -LiteralPath $artifactPath -Force -ErrorAction SilentlyContinue

& $makeAppx pack /d $packageRoot /p $artifactPath /o
if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $artifactPath)) {
    throw "MakeAppx failed to produce the Store package."
}

$hash = (Get-FileHash -LiteralPath $artifactPath -Algorithm SHA256).Hash.ToLowerInvariant()
$hashPath = "$artifactPath.sha256"
"$hash *$artifactName" | Set-Content -LiteralPath $hashPath -Encoding ASCII

Write-Output "Built Store package: $artifactPath"
Write-Output "SHA-256: $hash"
