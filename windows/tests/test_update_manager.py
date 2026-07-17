from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path

from codexvitals_windows.update_manager import (
    DIRECT_CHANNEL,
    STORE_CHANNEL,
    UpdateManager,
    UpdateManagerError,
    distribution_channel,
)


class FakeFunction:
    def __init__(self, result=None) -> None:
        self.result = result
        self.calls: list[tuple[object, ...]] = []
        self.argtypes = None
        self.restype = None

    def __call__(self, *args):
        self.calls.append(args)
        return self.result


class FakeWinSparkle:
    def __init__(self) -> None:
        names = (
            "win_sparkle_set_appcast_url",
            "win_sparkle_set_app_details",
            "win_sparkle_set_app_build_version",
            "win_sparkle_set_registry_path",
            "win_sparkle_set_automatic_check_for_updates",
            "win_sparkle_set_update_check_interval",
            "win_sparkle_set_shutdown_request_callback",
            "win_sparkle_set_did_find_update_callback",
            "win_sparkle_set_did_not_find_update_callback",
            "win_sparkle_set_error_callback",
            "win_sparkle_check_update_with_ui",
            "win_sparkle_init",
            "win_sparkle_cleanup",
        )
        for name in names:
            setattr(self, name, FakeFunction())
        self.win_sparkle_set_eddsa_public_key = FakeFunction(1)


class UpdateManagerTests(unittest.TestCase):
    def test_distribution_channel_reads_build_config(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            root = Path(temporary_directory)
            config = root / "build-config" / "distribution.json"
            config.parent.mkdir(parents=True)
            config.write_text(json.dumps({"channel": STORE_CHANNEL}), encoding="utf-8")
            self.assertEqual(distribution_channel(root), STORE_CHANNEL)

    def test_store_build_does_not_load_updater(self) -> None:
        manager = UpdateManager(
            on_shutdown_requested=lambda: None,
            on_status=lambda _: None,
            channel=STORE_CHANNEL,
            library_loader=lambda _: self.fail("Store build loaded WinSparkle"),
        )
        self.assertFalse(manager.initialize(True))
        self.assertFalse(manager.is_available)

    def test_direct_build_initializes_and_checks(self) -> None:
        statuses: list[str] = []
        fake_library = FakeWinSparkle()
        with tempfile.TemporaryDirectory() as temporary_directory:
            root = Path(temporary_directory)
            (root / "WinSparkle.dll").write_bytes(b"test")
            manager = UpdateManager(
                on_shutdown_requested=lambda: None,
                on_status=statuses.append,
                root=root,
                channel=DIRECT_CHANNEL,
                library_loader=lambda _: fake_library,
            )
            self.assertTrue(manager.initialize(True))
            manager.check_now()
            manager.set_automatic_checks(False)
            manager.cleanup()

        self.assertEqual(statuses, ["Checking for updates..."])
        self.assertEqual(len(fake_library.win_sparkle_init.calls), 1)
        self.assertEqual(len(fake_library.win_sparkle_check_update_with_ui.calls), 1)
        self.assertEqual(fake_library.win_sparkle_set_automatic_check_for_updates.calls[-1], (0,))
        self.assertEqual(len(fake_library.win_sparkle_cleanup.calls), 1)

    def test_manual_check_fails_when_component_is_missing(self) -> None:
        manager = UpdateManager(
            on_shutdown_requested=lambda: None,
            on_status=lambda _: None,
            channel=DIRECT_CHANNEL,
        )
        with self.assertRaises(UpdateManagerError):
            manager.check_now()


if __name__ == "__main__":
    unittest.main()
