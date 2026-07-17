param(
    [string]$SourceExe = "",
    [switch]$EnableStartup = $true,
    [switch]$Launch
)

$ErrorActionPreference = "Stop"
$legacyProductName = [string]::Concat("Codex", "Control")
$legacyExecutableName = "$legacyProductName.exe"
$legacyEntryName = "$($legacyProductName)Windows.pyw"
$codexVitalsEntryPattern = [regex]::Escape("CodexVitalsWindows.pyw")
$legacyEntryPattern = [regex]::Escape($legacyEntryName)

function Stop-CodexVitalsInstances {
    $processes = Get-CimInstance Win32_Process | Where-Object {
        $_.Name -in @("CodexVitals.exe", $legacyExecutableName) -or (
            $_.Name -match "^pythonw?\.exe$" -and
            ($_.CommandLine -match $codexVitalsEntryPattern -or
             $_.CommandLine -match $legacyEntryPattern)
        )
    }

    foreach ($process in $processes) {
        Stop-Process -Id $process.ProcessId -Force -ErrorAction SilentlyContinue
    }
}

$windowsRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
if ([string]::IsNullOrWhiteSpace($SourceExe)) {
    $SourceExe = Join-Path $windowsRoot "dist\CodexVitals.exe"
}

if (-not (Test-Path -LiteralPath $SourceExe)) {
    throw "EXE not found: $SourceExe"
}

$installDir = Join-Path $env:LOCALAPPDATA "Programs\CodexVitals"
$installedExe = Join-Path $installDir "CodexVitals.exe"
$legacyInstallDir = Join-Path $env:LOCALAPPDATA "Programs\$legacyProductName"
$legacyExe = Join-Path $legacyInstallDir $legacyExecutableName
$startupDir = [Environment]::GetFolderPath("Startup")
$startupShortcut = Join-Path $startupDir "Codex Vitals.lnk"
$legacyStartupShortcut = Join-Path $startupDir "$legacyProductName.lnk"
$programsDir = [Environment]::GetFolderPath("Programs")
$programShortcut = Join-Path $programsDir "Codex Vitals.lnk"

Stop-CodexVitalsInstances
Start-Sleep -Milliseconds 500

New-Item -ItemType Directory -Path $installDir -Force | Out-Null
Copy-Item -LiteralPath $SourceExe -Destination $installedExe -Force

if ($EnableStartup) {
    $shell = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut($startupShortcut)
    $shortcut.TargetPath = $installedExe
    $shortcut.Arguments = "--hidden"
    $shortcut.WorkingDirectory = $installDir
    $shortcut.IconLocation = $installedExe
    $shortcut.Description = "Launch Codex Vitals at sign-in"
    $shortcut.Save()
} elseif (Test-Path -LiteralPath $startupShortcut) {
    Remove-Item -LiteralPath $startupShortcut -Force
}

if (Test-Path -LiteralPath $legacyStartupShortcut) {
    Remove-Item -LiteralPath $legacyStartupShortcut -Force
}

$shell = New-Object -ComObject WScript.Shell
$shortcut = $shell.CreateShortcut($programShortcut)
$shortcut.TargetPath = $installedExe
$shortcut.WorkingDirectory = $installDir
$shortcut.IconLocation = $installedExe
$shortcut.Description = "Open Codex Vitals"
$shortcut.Save()

if (Test-Path -LiteralPath $legacyExe) {
    Remove-Item -LiteralPath $legacyExe -Force
}
if ((Test-Path -LiteralPath $legacyInstallDir) -and -not (Get-ChildItem -LiteralPath $legacyInstallDir -Force)) {
    Remove-Item -LiteralPath $legacyInstallDir -Force
}

if ($Launch) {
    Start-Process -FilePath $installedExe -WorkingDirectory $installDir
}

Write-Output "Installed: $installedExe"
if ($EnableStartup) {
    Write-Output "Startup shortcut: $startupShortcut"
}
