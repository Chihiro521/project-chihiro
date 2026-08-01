from __future__ import annotations

import json
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parent
FRAMES = ROOT / "frames"


def main() -> None:
    records: list[dict[str, object]] = []
    for path in sorted(FRAMES.glob("frame_*.png")):
        with Image.open(path) as image:
            rgba = image.convert("RGBA")
        alpha = rgba.getchannel("A").point(lambda value: 255 if value >= 8 else 0)
        bbox = alpha.getbbox()
        if bbox is None:
            continue
        records.append(
            {
                "frame": path.name,
                "bbox": list(bbox),
                "width": bbox[2] - bbox[0],
                "height": bbox[3] - bbox[1],
                "baseline": bbox[3] - 1,
            }
        )
    print(json.dumps(records, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
