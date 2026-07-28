from __future__ import annotations

from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
SOURCES = [
    ROOT / "skins/little-chihiro/animations/patrol_floor_left/frame_08.png",
    ROOT / "skins/little-chihiro/animations/idle/frame_00.png",
    ROOT / "skins/little-chihiro/animations/patrol_floor_right/frame_08.png",
]
OUTPUT = ROOT / "art/animation-production/character-reference/model-sheet.png"


def main() -> None:
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    sheet = Image.new("RGBA", (1536, 512), (0, 0, 0, 0))
    for index, source in enumerate(SOURCES):
        with Image.open(source).convert("RGBA") as frame:
            if frame.size != (512, 512):
                raise ValueError(f"expected 512x512 reference frame: {source}")
            sheet.alpha_composite(frame, (index * 512, 0))
    sheet.save(OUTPUT, format="PNG", optimize=True)
    print(OUTPUT)


if __name__ == "__main__":
    main()
