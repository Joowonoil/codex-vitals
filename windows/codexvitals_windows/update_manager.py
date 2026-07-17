from __future__ import annotations

import ctypes
import json
import os
import sys
from pathlib import Path
from typing import Callable

from .app_settings import APP_VERSION


APPCAST_URL = "https://ramterstudio.com/codex-vitals/windows-appcast.xml"
EDDSA_PUBLIC_KEY = "UZmFpP6KECwaK1HTD5G6CiEsx8m/rOAK+0ZyTMkrclk="
UPDATE_CHECK_INTERVAL_SECONDS = 24 * 60 * 60
DIRECT_CHANNEL = "direct"
STORE_CHANNEL = "store"


class UpdateManagerError(RuntimeError):
    pass


def bundle_root() -> Path:
    frozen_root = getattr(sys, "_MEIPASS", None)
    if frozen_root:
        return Path(frozen_root)
    return Path(__file__).resolve().parents[1]


def distribution_channel(root: Path | None = None) -> str:
    override = os.environ.get("CODEX_VITALS_DISTRIBUTION_CHANNEL")
    if override in {DIRECT_CHANNEL, STORE_CHANNEL}:
        return override

    config_path = (root or bundle_root()) / "build-config" / "distribution.json"
    try:
        payload = json.loads(config_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return DIRECT_CHANNEL
    channel = payload.get("channel") if isinstance(payload, dict) else None
    return channel if channel in {DIRECT_CHANNEL, STORE_CHANNEL} else DIRECT_CHANNEL


class UpdateManager:
    def __init__(
        self,
        *,
        on_shutdown_requested: Callable[[], None],
        on_status: Callable[[str], None],
        root: Path | None = None,
        channel: str | None = None,
        library_loader: Callable[[str], object] = ctypes.CDLL,
    ) -> None:
        self.root = root or bundle_root()
        self.channel = channel or distribution_channel(self.root)
        self.on_shutdown_requested = on_shutdown_requested
        self.on_status = on_status
        self.library_loader = library_loader
        self._library: object | None = None
        self._initialized = False
        self._callbacks: list[object] = []
        self.last_error: str | None = None

    @property
    def is_store_build(self) -> bool:
        return self.channel == STORE_CHANNEL

    @property
    def is_available(self) -> bool:
        return self._initialized

    def initialize(self, automatically_check: bool) -> bool:
        if self.is_store_build:
            return False
        dll_path = self.root / "WinSparkle.dll"
        if not dll_path.exists():
            self.last_error = "The update component is unavailable in this build."
            return False

        try:
            library = self.library_loader(str(dll_path))
            self._configure_library(library, automatically_check)
            library.win_sparkle_init()
        except (OSError, AttributeError, TypeError, ValueError, UpdateManagerError) as error:
            self.last_error = f"Could not initialize updates: {error}"
            self._library = None
            self._initialized = False
            return False

        self._library = library
        self._initialized = True
        self.last_error = None
        return True

    def set_automatic_checks(self, enabled: bool) -> None:
        if not self._initialized or self._library is None:
            raise UpdateManagerError(self.last_error or "The update component is unavailable.")
        self._library.win_sparkle_set_automatic_check_for_updates(1 if enabled else 0)

    def check_now(self) -> None:
        if not self._initialized or self._library is None:
            raise UpdateManagerError(self.last_error or "The update component is unavailable.")
        self.on_status("Checking for updates...")
        self._library.win_sparkle_check_update_with_ui()

    def cleanup(self) -> None:
        if not self._initialized or self._library is None:
            return
        try:
            self._library.win_sparkle_cleanup()
        finally:
            self._initialized = False

    def _configure_library(self, library: object, automatically_check: bool) -> None:
        self._set_signature(library.win_sparkle_set_appcast_url, [ctypes.c_char_p])
        self._set_signature(library.win_sparkle_set_eddsa_public_key, [ctypes.c_char_p], ctypes.c_int)
        self._set_signature(
            library.win_sparkle_set_app_details,
            [ctypes.c_wchar_p, ctypes.c_wchar_p, ctypes.c_wchar_p],
        )
        self._set_signature(library.win_sparkle_set_app_build_version, [ctypes.c_wchar_p])
        self._set_signature(library.win_sparkle_set_registry_path, [ctypes.c_char_p])
        self._set_signature(library.win_sparkle_set_automatic_check_for_updates, [ctypes.c_int])
        self._set_signature(library.win_sparkle_set_update_check_interval, [ctypes.c_int])
        self._set_signature(library.win_sparkle_check_update_with_ui, [])
        self._set_signature(library.win_sparkle_init, [])
        self._set_signature(library.win_sparkle_cleanup, [])

        callback_factory = getattr(ctypes, "WINFUNCTYPE", ctypes.CFUNCTYPE)
        shutdown_callback = callback_factory(None)(self.on_shutdown_requested)
        found_callback = callback_factory(None)(lambda: self.on_status("Update available."))
        current_callback = callback_factory(None)(lambda: self.on_status("Codex Vitals is up to date."))
        error_callback = callback_factory(None)(lambda: self.on_status("Could not check for updates."))
        self._callbacks = [shutdown_callback, found_callback, current_callback, error_callback]

        self._set_signature(library.win_sparkle_set_shutdown_request_callback, [type(shutdown_callback)])
        self._set_signature(library.win_sparkle_set_did_find_update_callback, [type(found_callback)])
        self._set_signature(library.win_sparkle_set_did_not_find_update_callback, [type(current_callback)])
        self._set_signature(library.win_sparkle_set_error_callback, [type(error_callback)])

        library.win_sparkle_set_appcast_url(APPCAST_URL.encode("utf-8"))
        if library.win_sparkle_set_eddsa_public_key(EDDSA_PUBLIC_KEY.encode("ascii")) != 1:
            raise UpdateManagerError("The Windows update public key is invalid.")
        library.win_sparkle_set_app_details("RamterStudio", "Codex Vitals", APP_VERSION)
        library.win_sparkle_set_app_build_version(APP_VERSION)
        library.win_sparkle_set_registry_path(b"Software\\RamterStudio\\Codex Vitals\\WinSparkle")
        library.win_sparkle_set_automatic_check_for_updates(1 if automatically_check else 0)
        library.win_sparkle_set_update_check_interval(UPDATE_CHECK_INTERVAL_SECONDS)
        library.win_sparkle_set_shutdown_request_callback(shutdown_callback)
        library.win_sparkle_set_did_find_update_callback(found_callback)
        library.win_sparkle_set_did_not_find_update_callback(current_callback)
        library.win_sparkle_set_error_callback(error_callback)

    @staticmethod
    def _set_signature(function: object, argtypes: list[object], restype: object = None) -> None:
        function.argtypes = argtypes
        function.restype = restype
