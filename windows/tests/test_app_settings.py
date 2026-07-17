from __future__ import annotations

import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from codexvitals_windows.app_settings import (
    AppSettings,
    AppSettingsStore,
    _build_shortcut_script,
    set_startup_enabled,
    startup_shortcut_path,
)


class AppSettingsTests(unittest.TestCase):
    def test_invalid_refresh_interval_uses_default(self) -> None:
        self.assertEqual(AppSettings.from_dict({"autoRefreshMinutes": 17}).auto_refresh_minutes, 5)
        self.assertEqual(AppSettings.from_dict({"autoRefreshMinutes": "30"}).auto_refresh_minutes, 30)

    def test_store_round_trips_refresh_interval(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            path = Path(temporary_directory) / "settings.json"
            store = AppSettingsStore(path)
            with patch("codexvitals_windows.app_settings.ensure_directories"):
                store.save(AppSettings(auto_refresh_minutes=60, automatically_check_for_updates=False))
                loaded = store.load()
            self.assertEqual(loaded.auto_refresh_minutes, 60)
            self.assertFalse(loaded.automatically_check_for_updates)

    def test_invalid_update_preference_defaults_to_enabled(self) -> None:
        settings = AppSettings.from_dict({"automaticallyCheckForUpdates": "no"})
        self.assertTrue(settings.automatically_check_for_updates)

    def test_startup_shortcut_path_uses_windows_startup_folder(self) -> None:
        path = startup_shortcut_path(Path("C:/Users/test/AppData/Roaming"))
        self.assertEqual(path.name, "Codex Vitals.lnk")
        self.assertIn("Startup", path.parts)

    def test_shortcut_script_uses_hidden_argument_and_escapes_paths(self) -> None:
        script = _build_shortcut_script(
            shortcut_path=Path("C:/Users/test/AppData/Roaming/Start'up/Codex Vitals.lnk"),
            target=Path("C:/Program Files/CodexVitals/CodexVitals.exe"),
            arguments="--hidden",
            working_directory=Path("C:/Program Files/CodexVitals"),
        )
        self.assertIn("--hidden", script)
        self.assertIn("Start''up", script)
        self.assertIn("CodexVitals.exe,0", script)

    def test_disabling_startup_removes_shortcut(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            shortcut = Path(temporary_directory) / "Codex Vitals.lnk"
            shortcut.write_text("test", encoding="utf-8")
            with patch("codexvitals_windows.app_settings.startup_shortcut_path", return_value=shortcut):
                set_startup_enabled(False)
            self.assertFalse(shortcut.exists())


if __name__ == "__main__":
    unittest.main()
