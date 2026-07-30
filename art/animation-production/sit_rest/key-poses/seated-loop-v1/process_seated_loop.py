from __future__ import annotations

import argparse
import json
import shutil
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parent
KEY_POSES = ROOT.parent
CHROMA = ROOT / "chroma"
ALPHA = ROOT / "alpha"
NORMALIZED = ROOT / "normalized"
QA = ROOT / "qa"
FRAMES = [
    (8, "K06 v3 / F08 contact"),
    (10, "F10 quiet inhale"),
    (12, "F12 relaxed sit"),
    (14, "F14 slow blink"),
    (16, "F16 exhale return"),
]


def _save_png(image: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path, format="PNG", optimize=True)


def standardize_sources() -> None:
    CHROMA.mkdir(parents=True, exist_ok=True)
    shutil.copy2(KEY_POSES / "k06_seated_contact_chroma.png", CHROMA / "frame_008.png")
    for index, _ in FRAMES[1:]:
        path = CHROMA / f"frame_{index:03d}.png"
        with Image.open(path) as source:
            rgb = source.convert("RGB")
            if rgb.size != (1024, 1024):
                rgb = rgb.resize((1024, 1024), Image.Resampling.LANCZOS)
            _save_png(rgb, path)


def seed_approved_alpha() -> None:
    ALPHA.mkdir(parents=True, exist_ok=True)
    shutil.copy2(KEY_POSES / "k06_seated_contact_alpha.png", ALPHA / "frame_008.png")


def normalize_alpha() -> None:
    NORMALIZED.mkdir(parents=True, exist_ok=True)
    records: list[dict[str, object]] = []
    motion_scale = 0.89

    for index, label in FRAMES:
        source_path = ALPHA / f"frame_{index:03d}.png"
        output_path = NORMALIZED / f"frame_{index:03d}.png"
        with Image.open(source_path) as source:
            rgba = source.convert("RGBA")
            if rgba.size != (1024, 1024):
                raise ValueError(f"{source_path.name} must be 1024x1024, got {rgba.size}")
            reduced_size = round(512 * motion_scale)
            reduced = rgba.resize((reduced_size, reduced_size), Image.Resampling.LANCZOS)
            sprite = Image.new("RGBA", (512, 512), (0, 0, 0, 0))
            inset = (512 - reduced_size) // 2
            sprite.alpha_composite(reduced, (inset, inset))

        alpha = sprite.getchannel("A")
        bbox = alpha.point(lambda value: 255 if value >= 8 else 0).getbbox()
        if bbox is None:
            raise ValueError(f"{source_path.name} has no visible alpha bounds")
        center_x = (bbox[0] + bbox[2] - 1) / 2.0
        visible_bottom = bbox[3] - 1
        dx = round(256 - center_x)
        dy = 472 - visible_bottom
        canvas = Image.new("RGBA", (512, 512), (0, 0, 0, 0))
        canvas.alpha_composite(sprite, (dx, dy))
        _save_png(canvas, output_path)

        normalized_bbox = canvas.getchannel("A").point(
            lambda value: 255 if value >= 8 else 0
        ).getbbox()
        records.append(
            {
                "frame": index,
                "label": label,
                "source_size": [1024, 1024],
                "final_size": [512, 512],
                "whole_drawing_scale": motion_scale,
                "whole_sprite_translation": [dx, dy],
                "alpha_bbox": list(normalized_bbox) if normalized_bbox else None,
                "visible_baseline_y": normalized_bbox[3] - 1 if normalized_bbox else None,
                "pivot": [256, 492],
            }
        )

    QA.mkdir(parents=True, exist_ok=True)
    (QA / "normalization-report.json").write_text(
        json.dumps({"status": "PASS", "frames": records}, indent=2),
        encoding="utf-8",
    )


def _checkerboard(size: tuple[int, int], tile: int = 16) -> Image.Image:
    width, height = size
    image = Image.new("RGBA", size, (58, 61, 68, 255))
    draw = ImageDraw.Draw(image)
    colors = ((58, 61, 68, 255), (44, 47, 53, 255))
    for y in range(0, height, tile):
        for x in range(0, width, tile):
            draw.rectangle(
                (x, y, min(x + tile - 1, width - 1), min(y + tile - 1, height - 1)),
                fill=colors[((x // tile) + (y // tile)) % 2],
            )
    return image


def build_contact_sheet() -> None:
    panel_width = 512
    label_height = 50
    panel_height = 512 + label_height
    columns = 3
    rows = (len(FRAMES) + columns - 1) // columns
    sheet = _checkerboard((panel_width * columns, panel_height * rows))
    draw = ImageDraw.Draw(sheet)
    font_path = Path("C:/Windows/Fonts/segoeui.ttf")
    font = ImageFont.truetype(str(font_path), 21) if font_path.exists() else ImageFont.load_default()
    for panel, (index, label) in enumerate(FRAMES):
        with Image.open(NORMALIZED / f"frame_{index:03d}.png") as source:
            frame = source.convert("RGBA")
        x = (panel % columns) * panel_width
        y = (panel // columns) * panel_height
        sheet.alpha_composite(frame, (x, y + label_height))
        draw.text((x + 14, y + 13), label, fill=(245, 245, 245, 255), font=font)
    _save_png(sheet, QA / "sit_rest-seated-loop-reference-contact-sheet.png")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("stage", choices=("standardize", "seed", "normalize", "contact", "all"))
    args = parser.parse_args()
    if args.stage in ("standardize", "all"):
        standardize_sources()
    if args.stage in ("seed", "all"):
        seed_approved_alpha()
    if args.stage in ("normalize", "all"):
        normalize_alpha()
    if args.stage in ("contact", "all"):
        build_contact_sheet()


if __name__ == "__main__":
    main()
