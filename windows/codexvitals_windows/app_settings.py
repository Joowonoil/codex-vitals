from __future__ import annotations

import base64
import json
import os
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path

from .file_locations import APP_SUPPORT_DIRECTORY, ensure_directories


APP_VERSION = "1.0.0"
AUTO_REFRESH_OPTIONS = (5, 15, 30, 60)
DEFAULT_AUTO_REFRESH_MINUTES = 5
SETTINGS_FILE = APP_SUPPORT_DIRECTORY / "settings.json"


class AppSettingsError(RuntimeError):
    pass


@dataclass(slots=True)
class AppSettings:
    auto_refresh_minutes: int = DEFAULT_AUTO_REFRESH_MINUTES
    automatically_check_for_updates: bool = True

    @classmethod
    def from_dict(cls, payload: object) -> "AppSettings":
        if not isinstance(payload, dict):
            return cls()
        value = payload.get("autoRefreshMinutes")
        try:
            interval = int(value)
        except (TypeError, ValueError):
            interval = DEFAULT_AUTO_REFRESH_MINUTES
        if interval not in AUTO_REFRESH_OPTIONS:
            interval = DEFAULT_AUTO_REFRESH_MINUTES
        automatic_updates = payload.get("automaticallyCheckForUpdates", True)
        if not isinstance(automatic_updates, bool):
            automatic_updates = True
        return cls(
            auto_refresh_minutes=interval,
            automatically_check_for_updates=automatic_updates,
        )

    def to_dict(self) -> dict[str, int | bool]:
        return {
            "autoRefreshMinutes": self.auto_refresh_minutes,
            "automaticallyCheckForUpdates": self.automatically_check_for_updates,
        }


class AppSettingsStore:
    def __init__(self, path: Path = SETTINGS_FILE) -> None:
        self.path = path

    def load(self) -> AppSettings:
        ensure_directories()
        if not self.path.exists():
            return AppSettings()
        try:
            payload = json.loads(self.path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError):
            return AppSettings()
        return AppSettings.from_dict(payload)

    def save(self, settings: AppSettings) -> None:
        ensure_directories()
        temporary_path = self.path.with_suffix(".json.tmp")
        temporary_path.write_text(
            json.dumps(settings.to_dict(), indent=2, sort_keys=True),
            encoding="utf-8",
        )
        temporary_path.replace(self.path)


def startup_shortcut_path(appdata: Path | None = None) -> Path:
    root = appdata or Path(os.environ.get("APPDATA", Path.home() / "AppData" / "Roaming"))
    return root / "Microsoft" / "Windows" / "Start Menu" / "Programs" / "Startup" / "Codex Vitals.lnk"


def is_startup_enabled() -> bool:
    return startup_shortcut_path().exists()


def set_startup_enabled(enabled: bool) -> None:
    shortcut_path = startup_shortcut_path()
    if not enabled:
        try:
            shortcut_path.unlink(missing_ok=True)
        except OSError as error:
            raise AppSettingsError(f"Could not disable launch at login: {error}") from error
        return

    target, arguments, working_directory = _startup_command()
    script = _build_shortcut_script(
        shortcut_path=shortcut_path,
        target=target,
        arguments=arguments,
        working_directory=working_directory,
    )
    encoded_script = base64.b64encode(script.encode("utf-16le")).decode("ascii")
    creation_flags = getattr(subprocess, "CREATE_NO_WINDOW", 0)
    try:
        result = subprocess.run(
            [
                "powershell.exe",
                "-NoProfile",
                "-NonInteractive",
                "-ExecutionPolicy",
                "Bypass",
                "-EncodedCommand",
                encoded_script,
            ],
            capture_output=True,
            text=True,
            check=False,
            creationflags=creation_flags,
        )
    except OSError as error:
        raise AppSettingsError(f"Could not enable launch at login: {error}") from error
    if result.returncode != 0:
        detail = result.stderr.strip() or result.stdout.strip() or "PowerShell returned an error."
        raise AppSettingsError(f"Could not enable launch at login: {detail}")


def _startup_command() -> tuple[Path, str, Path]:
    if getattr(sys, "frozen", False):
        executable = Path(sys.executable).resolve()
        return executable, "--hidden", executable.parent

    script_path = Path(sys.argv[0]).resolve()
    executable = Path(sys.executable).resolve()
    return executable, f'"{script_path}" --hidden', script_path.parent


def _powershell_literal(value: str) -> str:
    return "'" + value.replace("'", "''") + "'"


def _build_shortcut_script(
    *,
    shortcut_path: Path,
    target: Path,
    arguments: str,
    working_directory: Path,
) -> str:
    shortcut_parent = _powershell_literal(str(shortcut_path.parent))
    shortcut = _powershell_literal(str(shortcut_path))
    target_literal = _powershell_literal(str(target))
    arguments_literal = _powershell_literal(arguments)
    working_directory_literal = _powershell_literal(str(working_directory))
    description = _powershell_literal("Launch Codex Vitals at sign-in")
    icon = _powershell_literal(f"{target},0")
    return "\n".join(
        [
            "$ErrorActionPreference = 'Stop'",
            f"New-Item -ItemType Directory -Path {shortcut_parent} -Force | Out-Null",
            "$shell = New-Object -ComObject WScript.Shell",
            f"$shortcut = $shell.CreateShortcut({shortcut})",
            f"$shortcut.TargetPath = {target_literal}",
            f"$shortcut.Arguments = {arguments_literal}",
            f"$shortcut.WorkingDirectory = {working_directory_literal}",
            f"$shortcut.IconLocation = {icon}",
            f"$shortcut.Description = {description}",
            "$shortcut.Save()",
        ]
    )
