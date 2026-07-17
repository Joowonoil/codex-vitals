from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image


ASSET_SIZES = {
    "StoreLogo.png": 50,
    "Square44x44Logo.png": 44,
    "Square150x150Logo.png": 150,
}


def generate_assets(source: Path, output_dir: Path) -> None:
    output_dir.mkdir(parents=True, exist_ok=True)
    with Image.open(source) as image:
        icon = image.convert("RGBA")
        for filename, size in ASSET_SIZES.items():
            resized = icon.resize((size, size), Image.Resampling.LANCZOS)
            resized.save(output_dir / filename, format="PNG", optimize=True)


def main() -> None:
    parser = argparse.ArgumentParser(description="Generate Microsoft Store package assets.")
    parser.add_argument("--source", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    generate_assets(args.source, args.output)


if __name__ == "__main__":
    main()
