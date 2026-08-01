from __future__ import annotations

import argparse
import json
import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parent
RAW = ROOT / "key-poses-raw"
CHROMA = ROOT / "key-poses"
ALPHA_1024 = ROOT / "key-poses-alpha-1024"
NORMALIZED = ROOT / "key-poses-normalized"
QA = ROOT / "key-qa"

KEYS = [
    ("k00_tired_prepare", "K00 · fatigue preparation"),
    ("k04_lowered_sit", "K04 · lowered / first sit"),
    ("k08_sleep_master", "K08 · sleep family mother"),
    ("k12_sleep_breath_opposite", "K12 · opposite breath"),
    ("k16_wake_notice", "K16 · interrupted wake"),
    ("k18_eye_rub", "K18 · gentle eye rub"),
    ("k21_small_yawn", "K21 · small covered yawn"),
    ("k23_rise_preparation", "K23 · rise preparation"),
    ("k29_standing_recovery", "K29 · standing recovery"),
]

# Built-in generation can vary the amount of empty padding even when the
# character anatomy is stable. These are full-drawing, uniform corrections
# measured against the relevant pose-family authority; no body part is moved.
WHOLE_DRAWING_SCALE = {
    "k00_tired_prepare": 1.039,
    "k04_lowered_sit": 0.98,
    "k21_small_yawn": 1.064,
    "k23_rise_preparation": 1.125,
}


def _save_png(image: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path, format="PNG", optimize=True)


def standardize_sources() -> None:
    """Resize every complete built-in output as a whole to the fixed 1024 source cell."""
    CHROMA.mkdir(parents=True, exist_ok=True)
    for stem, _ in KEYS:
        source_path = RAW / f"{stem}_raw.png"
        if not source_path.exists():
            continue
        with Image.open(source_path) as source:
            rgb = source.convert("RGB")
            if rgb.size != (1024, 1024):
                rgb = rgb.resize((1024, 1024), Image.Resampling.LANCZOS)
            _save_png(rgb, CHROMA / f"{stem}_chroma.png")


def normalize_alpha() -> None:
    """Downsample each complete drawing uniformly and align only its whole-frame ground placement."""
    NORMALIZED.mkdir(parents=True, exist_ok=True)
    records: list[dict[str, object]] = []

    for stem, label in KEYS:
        source_path = ALPHA_1024 / f"{stem}_alpha.png"
        if not source_path.exists():
            continue
        with Image.open(source_path) as source:
            rgba = source.convert("RGBA")
            if rgba.size != (1024, 1024):
                raise ValueError(f"{source_path.name} must be 1024x1024, got {rgba.size}")
            reduced = rgba.resize((512, 512), Image.Resampling.LANCZOS)

        scale_correction = WHOLE_DRAWING_SCALE.get(stem, 1.0)
        if scale_correction != 1.0:
            corrected_size = round(512 * scale_correction)
            reduced = reduced.resize(
                (corrected_size, corrected_size), Image.Resampling.LANCZOS
            )

        alpha = reduced.getchannel("A")
        bbox = alpha.point(lambda value: 255 if value >= 8 else 0).getbbox()
        if bbox is None:
            raise ValueError(f"{source_path.name} has no visible alpha bounds")

        center_x = (bbox[0] + bbox[2] - 1) / 2.0
        visible_bottom = bbox[3] - 1
        dx = round(256 - center_x)
        dy = 472 - visible_bottom
        canvas = Image.new("RGBA", (512, 512), (0, 0, 0, 0))
        canvas.alpha_composite(reduced, (dx, dy))
        output_path = NORMALIZED / f"{stem}.png"
        _save_png(canvas, output_path)

        normalized_bbox = canvas.getchannel("A").point(
            lambda value: 255 if value >= 8 else 0
        ).getbbox()
        alpha_histogram = canvas.getchannel("A").histogram()
        coverage = sum(alpha_histogram[8:]) / (512 * 512)
        records.append(
            {
                "name": stem,
                "label": label,
                "source_size": [1024, 1024],
                "final_size": [512, 512],
                "whole_drawing_scale": round(0.5 * scale_correction, 6),
                "pose_family_scale_correction": scale_correction,
                "whole_sprite_translation": [dx, dy],
                "alpha_bbox": list(normalized_bbox) if normalized_bbox else None,
                "alpha_coverage": round(coverage, 6),
                "visible_baseline_y": normalized_bbox[3] - 1 if normalized_bbox else None,
                "pivot": [256, 492],
            }
        )

    QA.mkdir(parents=True, exist_ok=True)
    (QA / "key-geometry-report.json").write_text(
        json.dumps(
            {
                "status": "PENDING_SEMANTIC_REVIEW" if records else "INCOMPLETE",
                "note": "Sparse keys intentionally contain large pose changes; geometry is reported for review and is not a continuity PASS.",
                "frames": records,
            },
            indent=2,
        ),
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
    available = [(stem, label) for stem, label in KEYS if (NORMALIZED / f"{stem}.png").exists()]
    if not available:
        raise ValueError("No normalized key poses are available")

    panel_width = 512
    label_height = 58
    columns = 3 if len(available) > 6 else len(available)
    rows = math.ceil(len(available) / columns)
    panel_height = 512 + label_height
    sheet = _checkerboard((panel_width * columns, panel_height * rows))
    draw = ImageDraw.Draw(sheet)
    font_path = Path("C:/Windows/Fonts/segoeui.ttf")
    font = ImageFont.truetype(str(font_path), 20) if font_path.exists() else ImageFont.load_default()

    for index, (stem, label) in enumerate(available):
        with Image.open(NORMALIZED / f"{stem}.png") as source:
            frame = source.convert("RGBA")
        column = index % columns
        row = index // columns
        x = column * panel_width
        y = row * panel_height
        sheet.alpha_composite(frame, (x, y + label_height))
        draw.text((x + 14, y + 16), label, fill=(245, 245, 245, 255), font=font)
        draw.line((x + 8, y + label_height + 472, x + panel_width - 8, y + label_height + 472), fill=(108, 215, 255, 150), width=1)

    QA.mkdir(parents=True, exist_ok=True)
    _save_png(sheet, QA / "nap-key-contact-sheet.png")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("stage", choices=("standardize", "normalize", "contact", "all"))
    args = parser.parse_args()

    if args.stage in ("standardize", "all"):
        standardize_sources()
    if args.stage in ("normalize", "all"):
        normalize_alpha()
    if args.stage in ("contact", "all"):
        build_contact_sheet()


if __name__ == "__main__":
    main()
