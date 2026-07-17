from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from codexvitals_windows import file_locations


class FileLocationMigrationTests(unittest.TestCase):
    def test_moves_legacy_data_and_rewrites_managed_home_paths(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            root = Path(temporary_directory)
            legacy_directory = root / "".join(("Codex", "Control"))
            active_directory = root / "CodexVitals"
            managed_home = legacy_directory / "managed-homes" / "account-1"
            managed_home.mkdir(parents=True)
            (managed_home / "auth.json").write_text("{}", encoding="utf-8")

            unrelated_path = root / "external-home"
            accounts_payload = {
                "accounts": [
                    {"codexHomePath": str(managed_home)},
                    {"codexHomePath": str(unrelated_path)},
                ],
                "removedAccounts": [
                    {"codexHomePath": str(legacy_directory / "managed-homes" / "removed")},
                ],
            }
            (legacy_directory / "accounts.json").write_text(
                json.dumps(accounts_payload),
                encoding="utf-8",
            )

            with patch.multiple(
                file_locations,
                APP_SUPPORT_DIRECTORY=active_directory,
                LEGACY_APP_SUPPORT_DIRECTORIES=[legacy_directory],
                MANAGED_HOMES_DIRECTORY=active_directory / "managed-homes",
                AUTH_BACKUPS_DIRECTORY=active_directory / "auth-backups",
            ):
                file_locations.ensure_directories()

            migrated_payload = json.loads((active_directory / "accounts.json").read_text(encoding="utf-8"))
            self.assertFalse(legacy_directory.exists())
            self.assertTrue((active_directory / "managed-homes" / "account-1" / "auth.json").exists())
            self.assertEqual(
                migrated_payload["accounts"][0]["codexHomePath"],
                str(active_directory / "managed-homes" / "account-1"),
            )
            self.assertEqual(migrated_payload["accounts"][1]["codexHomePath"], str(unrelated_path))
            self.assertEqual(
                migrated_payload["removedAccounts"][0]["codexHomePath"],
                str(active_directory / "managed-homes" / "removed"),
            )


if __name__ == "__main__":
    unittest.main()
