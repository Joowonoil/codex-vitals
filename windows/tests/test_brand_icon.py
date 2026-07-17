from __future__ import annotations

import unittest

from PIL import Image

from codexvitals_windows.brand_icon import (
    build_codex_vitals_icon,
    build_ramter_studio_logo,
    codex_vitals_icon_path,
    ramter_studio_logo_path,
)


class BrandIconTests(unittest.TestCase):
    def test_icon_matches_codex_vitals_source_asset(self) -> None:
        image = build_codex_vitals_icon(64)
        with Image.open(codex_vitals_icon_path()) as source:
            expected = source.convert("RGBA").resize((64, 64), Image.Resampling.LANCZOS)

        self.assertEqual(image.tobytes(), expected.tobytes())
        self.assertEqual(image.getpixel((0, 0))[3], 0)
        self.assertGreater(image.getpixel((32, 32))[3], 200)

    def test_ramter_studio_logo_is_a_tinted_template_of_the_source_asset(self) -> None:
        color = "#f1f2f4"
        image = build_ramter_studio_logo(150, 24, color)

        with Image.open(ramter_studio_logo_path()) as source:
            self.assertEqual(source.size, (2361, 355))

        self.assertEqual(image.size, (150, 24))
        alpha = image.getchannel("A")
        self.assertIsNotNone(alpha.getbbox())
        self.assertEqual(alpha.getextrema()[1], 255)

        opaque_index = list(alpha.getdata()).index(255)
        x = opaque_index % image.width
        y = opaque_index // image.width
        self.assertEqual(image.getpixel((x, y))[:3], (241, 242, 244))

    def test_ramter_studio_logo_rejects_invalid_dimensions(self) -> None:
        with self.assertRaises(ValueError):
            build_ramter_studio_logo(0, 24, "#ffffff")


if __name__ == "__main__":
    unittest.main()
