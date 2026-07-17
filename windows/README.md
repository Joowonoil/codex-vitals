# Codex Vitals for Windows

This folder contains the Windows implementation of Codex Vitals.

## What It Does

- Tracks Codex account quota from local `auth.json` state
- Shows live 5-hour and 1-week windows when available
- Supports account switching, add account, refresh, reauthenticate, open folder, and remove
- Runs as a tray app with a dashboard window
- Includes in-window settings for launch at login, auto-refresh timing, signed updates, version, and project links
- Persists accounts and snapshots under `%APPDATA%\\CodexVitals`
- Migrates local data from previous local app directories automatically
- Syncs Codex global state and Codex Desktop session cache during account switches

## Run Locally

```powershell
python -m pip install -r .\windows\requirements.txt
python .\windows\CodexVitalsWindows.pyw
```

## Build the App

```powershell
powershell -ExecutionPolicy Bypass -File .\windows\build.ps1 -Channel Direct -Version 1.0.0
```

This produces:

- `%REPO%\\windows\\dist\\CodexVitals.exe`

The direct build pins WinSparkle 0.9.3, verifies the official archive SHA-256,
and bundles its x64 DLL. A Store build can be produced with `-Channel Store`;
that build omits WinSparkle because Microsoft Store manages updates.

## Build the Microsoft Store Package

The Store package uses the identity reserved in Partner Center and is built as
an unsigned x64 MSIX. Microsoft Store signs the accepted package during
publication.

```powershell
powershell -ExecutionPolicy Bypass -File .\windows\package_store.ps1 -Clean -Version 1.0.0.0
```

This produces:

- `%REPO%\ReleaseArtifacts\Store\CodexVitals-Windows-Store-1.0.0.0-x64.msix`
- the package SHA-256 file

The package requires Windows 10 version 2004 (build 19041) or newer. It declares
the `runFullTrust` restricted capability because Codex Vitals is a packaged
desktop application that reads and updates the user's local Codex state.

## Build the Installer

```powershell
powershell -ExecutionPolicy Bypass -File .\windows\package_release.ps1 -Clean -Version 1.0.0
```

This produces:

- `%REPO%\\ReleaseArtifacts\\CodexVitals-Windows-1.0.0-Setup.exe`
- the installer SHA-256 file
- a signed `windows-appcast.xml`
- GitHub release notes

The Inno Setup installer places the app under:

- `%LocalAppData%\\Programs\\CodexVitals`

and can register a startup shortcut so the tray app launches hidden at sign-in.
Saved accounts and settings remain under `%APPDATA%\\CodexVitals` when the app is
updated or uninstalled.

The update signing key is not stored in this repository. The release script
expects it at `%APPDATA%\\RamterStudio\\ReleaseKeys\\CodexVitals\\windows-update-private.key`
unless `-PrivateKeyPath` is provided.

## Source of Truth and Windows Sync

The canonical source is the same GitHub repository used by the macOS app. Keep
the full repository cloned on both platforms; Git transfers only changed
objects, so a separate Taildrop mirror is unnecessary.

- macOS working copy: `/Users/ramster/Developer/codex-vitals`
- Windows working copy: `C:\Users\calor\Developer\codex-vitals`

Before a Windows build:

```powershell
Set-Location C:\Users\calor\Developer\codex-vitals
git pull --ff-only
git status --short
```

Commit source changes on one machine, push them to GitHub, then use
`git pull --ff-only` on the other machine. Do not copy the `windows/` directory
over an unrelated checkout because that loses useful history and can leave
stale renamed files behind.

## Tests

```powershell
$env:PYTHONPATH = (Resolve-Path .\windows)
python -m unittest discover .\windows\tests
```

## Technical Notes

- Account-switching fix details: [ACCOUNT_SWITCH_FIX.md](./ACCOUNT_SWITCH_FIX.md)
- The switch fix is covered by `windows/tests/test_account_manager.py` and `windows/tests/test_codex_desktop.py`
