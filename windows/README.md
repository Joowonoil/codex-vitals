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

## Tests

```powershell
$env:PYTHONPATH = (Resolve-Path .\windows)
python -m unittest discover .\windows\tests
```

## Technical Notes

- Account-switching fix details: [ACCOUNT_SWITCH_FIX.md](./ACCOUNT_SWITCH_FIX.md)
- The switch fix is covered by `windows/tests/test_account_manager.py` and `windows/tests/test_codex_desktop.py`
