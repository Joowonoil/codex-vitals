from __future__ import annotations

import tempfile
import unittest
import xml.etree.ElementTree as ET
from pathlib import Path

from PIL import Image

from tools.generate_store_assets import ASSET_SIZES, generate_assets


WINDOWS_ROOT = Path(__file__).resolve().parents[1]
MANIFEST_TEMPLATE = WINDOWS_ROOT / "store" / "AppxManifest.xml.in"
ICON_SOURCE = WINDOWS_ROOT / "build-assets" / "CodexVitals-1024.png"
FOUNDATION_NAMESPACE = "http://schemas.microsoft.com/appx/manifest/foundation/windows10"


class StorePackageTests(unittest.TestCase):
    def test_manifest_uses_reserved_store_identity(self) -> None:
        manifest = MANIFEST_TEMPLATE.read_text(encoding="utf-8").replace(
            "__PACKAGE_VERSION__",
            "1.0.0.0",
        )
        root = ET.fromstring(manifest)
        identity = root.find(f"{{{FOUNDATION_NAMESPACE}}}Identity")
        self.assertIsNotNone(identity)
        assert identity is not None
        self.assertEqual(identity.attrib["Name"], "RamterStudio.CodexVitals")
        self.assertEqual(
            identity.attrib["Publisher"],
            "CN=BF8622C6-0906-4367-85D0-B818738D0F29",
        )
        self.assertEqual(identity.attrib["ProcessorArchitecture"], "x64")
        self.assertEqual(identity.attrib["Version"], "1.0.0.0")

    def test_store_assets_have_manifest_dimensions(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory)
            generate_assets(ICON_SOURCE, output)
            for filename, size in ASSET_SIZES.items():
                with self.subTest(filename=filename), Image.open(output / filename) as image:
                    self.assertEqual(image.size, (size, size))
                    self.assertEqual(image.mode, "RGBA")


if __name__ == "__main__":
    unittest.main()
