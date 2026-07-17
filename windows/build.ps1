param(
    [switch]$Clean,
    [ValidateSet("Direct", "Store")]
    [string]$Channel = "Direct",
    [string]$Version = "1.0.0"
)

$ErrorActionPreference = "Stop"

$windowsRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent $windowsRoot
Set-Location $repoRoot

$pythonCommand = Get-Command python -ErrorAction SilentlyContinue
$pythonLauncherArgs = @()
if ($pythonCommand) {
    $pythonExecutable = $pythonCommand.Source
} else {
    $pyCommand = Get-Command py -ErrorAction SilentlyContinue
    if (-not $pyCommand) {
        throw "Python was not found on PATH."
    }
    $pythonExecutable = $pyCommand.Source
    $pythonLauncherArgs = @("-3")
}

if (-not [Environment]::Is64BitProcess) {
    throw "Codex Vitals requires a 64-bit Python build."
}

$distDir = Join-Path $windowsRoot "dist"
$workDir = Join-Path $windowsRoot "build"
$generatedDir = Join-Path $windowsRoot "build-generated"
$venvDir = Join-Path $windowsRoot ".venv-build"
if ($Clean) {
    Remove-Item -LiteralPath $workDir -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $distDir -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $generatedDir -Recurse -Force -ErrorAction SilentlyContinue
}

if (-not (Test-Path -LiteralPath (Join-Path $venvDir "Scripts\python.exe"))) {
    & $pythonExecutable @pythonLauncherArgs -m venv $venvDir
    if ($LASTEXITCODE -ne 0) {
        throw "Could not create the Windows build environment."
    }
}
$buildPython = Join-Path $venvDir "Scripts\python.exe"
& $buildPython -m pip install -r (Join-Path $windowsRoot "requirements-build.txt")
if ($LASTEXITCODE -ne 0) {
    throw "Could not install Windows build dependencies."
}
& $buildPython (Join-Path $windowsRoot "tools\generate_app_icon.py")
if ($LASTEXITCODE -ne 0) {
    throw "Could not generate the Windows app icon."
}

$channelName = $Channel.ToLowerInvariant()
$configDir = Join-Path $generatedDir "build-config"
New-Item -ItemType Directory -Force -Path $configDir | Out-Null
$distributionConfig = Join-Path $configDir "distribution.json"
@{
    channel = $channelName
    version = $Version
} | ConvertTo-Json | Set-Content -LiteralPath $distributionConfig -Encoding UTF8

$versionParts = @($Version.Split(".") | ForEach-Object { [int]$_ })
while ($versionParts.Count -lt 4) {
    $versionParts += 0
}
$fileVersion = ($versionParts[0..3] -join ", ")
$dottedFileVersion = ($versionParts[0..3] -join ".")
$versionFile = Join-Path $generatedDir "CodexVitals.version.txt"
New-Item -ItemType Directory -Force -Path $generatedDir | Out-Null
@"
VSVersionInfo(
  ffi=FixedFileInfo(
    filevers=($fileVersion),
    prodvers=($fileVersion),
    mask=0x3F,
    flags=0x0,
    OS=0x40004,
    fileType=0x1,
    subtype=0x0,
    date=(0, 0)
  ),
  kids=[
    StringFileInfo([
      StringTable(
        '040904B0',
        [
          StringStruct('CompanyName', 'RamterStudio'),
          StringStruct('FileDescription', 'Codex Vitals for Windows'),
          StringStruct('FileVersion', '$dottedFileVersion'),
          StringStruct('InternalName', 'CodexVitals'),
          StringStruct('LegalCopyright', 'Copyright 2026 RamterStudio'),
          StringStruct('OriginalFilename', 'CodexVitals.exe'),
          StringStruct('ProductName', 'Codex Vitals'),
          StringStruct('ProductVersion', '$Version')
        ]
      )
    ]),
    VarFileInfo([VarStruct('Translation', [1033, 1200])])
  ]
)
"@ | Set-Content -LiteralPath $versionFile -Encoding UTF8

$iconPath = Join-Path $windowsRoot "build-assets\CodexVitals.ico"
$iconSource = Join-Path $windowsRoot "build-assets\CodexVitals-1024.png"
$studioLogoSource = Join-Path $windowsRoot "build-assets\RamterStudioLogo.png"
$entryPath = Join-Path $windowsRoot "CodexVitalsWindows.pyw"
$pyInstallerExtraArgs = @(
    "--add-data", "$iconSource;build-assets",
    "--add-data", "$studioLogoSource;build-assets",
    "--add-data", "$distributionConfig;build-config"
)

if ($Channel -eq "Direct") {
    $winSparkleVersion = "0.9.3"
    $winSparkleArchiveHash = "745985f41d2ab26b2d5a1cf87d76e4ed851039db19038e50610eb25ea0b73772"
    $winSparkleRoot = Join-Path $env:LOCALAPPDATA "RamterStudio\BuildTools\WinSparkle-$winSparkleVersion"
    $winSparkleArchive = Join-Path $winSparkleRoot "WinSparkle-$winSparkleVersion.zip"
    $winSparklePackage = Join-Path $winSparkleRoot "WinSparkle-$winSparkleVersion"
    $winSparkleDll = Join-Path $winSparklePackage "x64\Release\WinSparkle.dll"
    New-Item -ItemType Directory -Force -Path $winSparkleRoot | Out-Null

    $downloadArchive = $true
    if (Test-Path -LiteralPath $winSparkleArchive) {
        $archiveHash = (Get-FileHash -Algorithm SHA256 $winSparkleArchive).Hash.ToLowerInvariant()
        $downloadArchive = $archiveHash -ne $winSparkleArchiveHash
    }
    if ($downloadArchive) {
        Remove-Item -LiteralPath $winSparkleArchive -Force -ErrorAction SilentlyContinue
        Invoke-WebRequest `
            -Uri "https://github.com/vslavik/winsparkle/releases/download/v$winSparkleVersion/WinSparkle-$winSparkleVersion.zip" `
            -OutFile $winSparkleArchive
        $archiveHash = (Get-FileHash -Algorithm SHA256 $winSparkleArchive).Hash.ToLowerInvariant()
        if ($archiveHash -ne $winSparkleArchiveHash) {
            Remove-Item -LiteralPath $winSparkleArchive -Force -ErrorAction SilentlyContinue
            throw "WinSparkle archive hash mismatch."
        }
    }
    if (-not (Test-Path -LiteralPath $winSparkleDll)) {
        Remove-Item -LiteralPath $winSparklePackage -Recurse -Force -ErrorAction SilentlyContinue
        Expand-Archive -LiteralPath $winSparkleArchive -DestinationPath $winSparkleRoot -Force
    }
    if (-not (Test-Path -LiteralPath $winSparkleDll)) {
        throw "WinSparkle.dll was not found after extraction."
    }
    $pyInstallerExtraArgs += @("--add-binary", "$winSparkleDll;.")
}

& $buildPython -m PyInstaller `
  --noconfirm `
  --clean `
  --onefile `
  --windowed `
  --name CodexVitals `
  --distpath $distDir `
  --workpath $workDir `
  --specpath $windowsRoot `
  --paths $windowsRoot `
  --icon $iconPath `
  --version-file $versionFile `
  @pyInstallerExtraArgs `
  --hidden-import pystray._win32 `
  --hidden-import PIL._tkinter_finder `
  $entryPath

if ($LASTEXITCODE -ne 0) {
    throw "PyInstaller failed."
}
if (-not (Test-Path -LiteralPath (Join-Path $distDir "CodexVitals.exe"))) {
    throw "PyInstaller did not produce CodexVitals.exe."
}

Write-Output "Built ($channelName): $(Join-Path $distDir 'CodexVitals.exe')"
