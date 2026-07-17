from __future__ import annotations

from pathlib import Path

from PIL import Image


def main() -> None:
    root = Path(__file__).resolve().parents[1]
    assets_dir = root / "build-assets"
    assets_dir.mkdir(parents=True, exist_ok=True)
    source_path = assets_dir / "CodexVitals-1024.png"
    output_path = assets_dir / "CodexVitals.ico"

    with Image.open(source_path) as source:
        base = source.convert("RGBA")
    sizes = [(256, 256), (128, 128), (64, 64), (48, 48), (32, 32), (24, 24), (16, 16)]
    base.save(output_path, format="ICO", sizes=sizes)
    print(output_path)


if __name__ == "__main__":
    main()
