from __future__ import annotations

import json
import os
import shutil
from pathlib import Path


def appdata_directory() -> Path:
    appdata = os.environ.get("APPDATA")
    if appdata:
        return Path(appdata)
    return Path.home() / "AppData" / "Roaming"


def localappdata_directory() -> Path:
    localappdata = os.environ.get("LOCALAPPDATA")
    if localappdata:
        return Path(localappdata)
    return Path.home() / "AppData" / "Local"


APP_SUPPORT_DIRECTORY = appdata_directory() / "CodexVitals"
LEGACY_APP_SUPPORT_DIRECTORIES = [
    appdata_directory() / "".join(["Codex", "Control"]),
    appdata_directory() / "".join(["Codex", "Gauge"]),
    appdata_directory() / "".join(["Codex", "Accounts"]),
]
ACCOUNTS_FILE = APP_SUPPORT_DIRECTORY / "accounts.json"
SNAPSHOTS_FILE = APP_SUPPORT_DIRECTORY / "snapshots.json"
MANAGED_HOMES_DIRECTORY = APP_SUPPORT_DIRECTORY / "managed-homes"
AUTH_BACKUPS_DIRECTORY = APP_SUPPORT_DIRECTORY / "auth-backups"
AMBIENT_CODEX_HOME = Path.home() / ".codex"
DESKTOP_SESSION_SNAPSHOT_DIRECTORY_NAME = "desktop-session"
DESKTOP_SESSION_STATE_ENTRIES = (
    "blob_storage",
    "DIPS",
    "DIPS-wal",
    "Local State",
    "Local Storage",
    "Network",
    "Partitions",
    "Preferences",
    "Session Storage",
    "SharedStorage",
    "SharedStorage-wal",
    "shared_proto_db",
)


def codex_desktop_package_directories() -> list[Path]:
    packages_root = localappdata_directory() / "Packages"
    if not packages_root.exists():
        return []

    candidates = [path for path in packages_root.glob("OpenAI.Codex*") if path.is_dir()]
    return sorted(candidates, key=lambda path: (path.name.lower(), str(path)))


def codex_desktop_session_root() -> Path | None:
    for package_directory in codex_desktop_package_directories():
        session_root = package_directory / "LocalCache" / "Roaming" / "Codex"
        if session_root.exists():
            return session_root
    return None


def _replace_directory_prefix(value: str, source: Path, destination: Path) -> str:
    source_text = str(source).rstrip("\\/")
    if not source_text:
        return value

    prefix = value[: len(source_text)]
    suffix = value[len(source_text) :]
    if prefix.casefold() != source_text.casefold():
        return value
    if suffix and suffix[0] not in ("\\", "/"):
        return value
    destination_text = str(destination).rstrip("\\/")
    return f"{destination_text}{suffix}"


def _rewrite_migrated_account_paths(source: Path, destination: Path) -> None:
    accounts_file = destination / "accounts.json"
    if not accounts_file.exists():
        return

    payload = json.loads(accounts_file.read_text(encoding="utf-8"))
    changed = False
    for collection_name in ("accounts", "removedAccounts"):
        collection = payload.get(collection_name, [])
        if not isinstance(collection, list):
            continue
        for item in collection:
            if not isinstance(item, dict):
                continue
            path = item.get("codexHomePath")
            if not isinstance(path, str):
                continue
            migrated_path = _replace_directory_prefix(path, source, destination)
            if migrated_path != path:
                item["codexHomePath"] = migrated_path
                changed = True

    if changed:
        temporary_file = accounts_file.with_suffix(".json.tmp")
        temporary_file.write_text(json.dumps(payload, indent=2, sort_keys=True), encoding="utf-8")
        temporary_file.replace(accounts_file)


def ensure_directories() -> None:
    migrated_from: Path | None = None
    if not APP_SUPPORT_DIRECTORY.exists():
        for legacy_directory in LEGACY_APP_SUPPORT_DIRECTORIES:
            if legacy_directory.exists():
                shutil.move(str(legacy_directory), str(APP_SUPPORT_DIRECTORY))
                migrated_from = legacy_directory
                break

    if migrated_from is not None:
        _rewrite_migrated_account_paths(migrated_from, APP_SUPPORT_DIRECTORY)

    APP_SUPPORT_DIRECTORY.mkdir(parents=True, exist_ok=True)
    MANAGED_HOMES_DIRECTORY.mkdir(parents=True, exist_ok=True)
    AUTH_BACKUPS_DIRECTORY.mkdir(parents=True, exist_ok=True)
