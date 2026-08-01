from __future__ import annotations

import json
import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parent
FRAMES = ROOT / "frames"
QA = ROOT / "qa"
MANIFEST = ROOT / "sprite-sequence.json"
BASELINE = 472

# Diagnostic-only factors. These are applied to complete drawings copied from
# the current final frames; production sources remain untouched.
SCALE = {
    **{index: 0.86 for index in range(4, 24)},
    24: 0.93,
    25: 0.873,
    26: 0.93,
    27: 0.924,
}


def alpha_bbox(image: Image.Image) -> tuple[int, int, int, int]:
    bbox = image.getchannel("A").point(lambda value: 255 if value >= 8 else 0).getbbox()
    if bbox is None:
        raise ValueError("empty frame")
    return bbox


def whole_scale(image: Image.Image, factor: float) -> Image.Image:
    if factor == 1.0:
        return image.copy()
    bbox = alpha_bbox(image)
    center_x = (bbox[0] + bbox[2] - 1) / 2
    resized = image.resize(
        (round(image.width * factor), round(image.height * factor)),
        Image.Resampling.LANCZOS,
    )
    resized_bbox = alpha_bbox(resized)
    resized_center_x = (resized_bbox[0] + resized_bbox[2] - 1) / 2
    dx = round(256 - resized_center_x)
    dy = BASELINE - (resized_bbox[3] - 1)
    canvas = Image.new("RGBA", image.size, (0, 0, 0, 0))
    canvas.alpha_composite(resized, (dx, dy))
    return canvas


def checker(size: tuple[int, int], tile: int = 16) -> Image.Image:
    image = Image.new("RGBA", size, (58, 61, 68, 255))
    draw = ImageDraw.Draw(image)
    for y in range(0, size[1], tile):
        for x in range(0, size[0], tile):
            if (x // tile + y // tile) % 2:
                draw.rectangle((x, y, x + tile - 1, y + tile - 1), fill=(44, 47, 53, 255))
    return image


def main() -> None:
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    frames: list[Image.Image] = []
    for entry in manifest["frames"]:
        with Image.open(FRAMES / entry["file"]) as image:
            frame = image.convert("RGBA")
        frames.append(whole_scale(frame, SCALE.get(entry["index"], 1.0)))

    columns = 5
    panel = 320
    label = 38
    rows = math.ceil(len(frames) / columns)
    sheet = Image.new("RGBA", (columns * panel, rows * (panel + label)), (35, 38, 44, 255))
    draw = ImageDraw.Draw(sheet)
    font_path = Path("C:/Windows/Fonts/segoeui.ttf")
    font = ImageFont.truetype(str(font_path), 15) if font_path.exists() else ImageFont.load_default()
    for index, frame in enumerate(frames):
        x = (index % columns) * panel
        y = (index // columns) * (panel + label)
        background = checker((panel, panel))
        thumb = frame.resize((panel, panel), Image.Resampling.LANCZOS)
        background.alpha_composite(thumb)
        sheet.alpha_composite(background, (x, y + label))
        factor = SCALE.get(index, 1.0)
        bbox = alpha_bbox(frame)
        draw.text(
            (x + 8, y + 9),
            f"F{index:02d} scale={factor:.3f} h={bbox[3]-bbox[1]}",
            font=font,
            fill=(245, 245, 245, 255),
        )
        baseline_y = y + label + round(BASELINE * panel / 512)
        draw.line((x + 4, baseline_y, x + panel - 4, baseline_y), fill=(108, 215, 255, 160), width=1)

    QA.mkdir(parents=True, exist_ok=True)
    sheet.save(QA / "drift-normalization-experiment-contact.png", optimize=True)

    gif_frames: list[Image.Image] = []
    for frame in frames:
        background = checker(frame.size)
        background.alpha_composite(frame)
        gif_frames.append(background.convert("RGB"))
    gif_frames[0].save(
        QA / "drift-normalization-experiment-slow.gif",
        save_all=True,
        append_images=gif_frames[1:],
        duration=330,
        loop=0,
        disposal=2,
        optimize=False,
    )


if __name__ == "__main__":
    main()
