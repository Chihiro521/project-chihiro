from __future__ import annotations

import argparse
import json
import math
import shutil
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parent
RAW = ROOT / "direct-frame-sources-raw"
CHROMA = ROOT / "direct-frame-sources"
ALPHA_1024 = ROOT / "direct-frame-alpha-1024"
FRAMES = ROOT / "frames"
QA = ROOT / "qa"
MANIFEST = ROOT / "sprite-sequence.json"
NORMALIZATION = ROOT / "direct-frame-normalization.json"

KEY_SOURCES = {
    0: "k00_tired_prepare",
    4: "k04_lowered_sit",
    8: "k08_sleep_master",
    12: "k12_sleep_breath_opposite",
    16: "k16_wake_notice",
    18: "k18_eye_rub",
    21: "k21_small_yawn",
    23: "k23_rise_preparation",
    29: "k29_standing_recovery",
}
DIRECT_INDICES = [1, 2, 3, 5, 6, 7, 9, 10, 11, 13, 14, 15, 17, 19, 20, 22, 24, 25, 26, 27, 28]


def _save_png(image: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path, format="PNG", optimize=True)


def prepare_keys() -> None:
    source_root = ROOT / "key-poses-normalized"
    scale_corrections, translation_overrides = _normalization_config()
    FRAMES.mkdir(parents=True, exist_ok=True)
    for index, stem in KEY_SOURCES.items():
        source = source_root / f"{stem}.png"
        if not source.exists():
            raise FileNotFoundError(source)
        with Image.open(source) as image:
            rgba = image.convert("RGBA")
        if rgba.size != (512, 512):
            raise ValueError(f"{source.name} must be 512x512, got {rgba.size}")
        corrected, _ = _place_complete_drawing(
            rgba,
            index,
            scale_corrections,
            translation_overrides,
        )
        _save_png(corrected, FRAMES / f"frame_{index:03d}.png")


def standardize_sources() -> None:
    CHROMA.mkdir(parents=True, exist_ok=True)
    for index in DIRECT_INDICES:
        source = RAW / f"frame_{index:03d}_raw.png"
        if not source.exists():
            continue
        with Image.open(source) as image:
            rgb = image.convert("RGB")
            if rgb.size != (1024, 1024):
                rgb = rgb.resize((1024, 1024), Image.Resampling.LANCZOS)
            _save_png(rgb, CHROMA / f"frame_{index:03d}_chroma.png")


def _normalization_config() -> tuple[dict[str, float], dict[str, list[int]]]:
    if not NORMALIZATION.exists():
        return {}, {}
    data = json.loads(NORMALIZATION.read_text(encoding="utf-8"))
    return data.get("scale_corrections", {}), data.get("translation_overrides", {})


def _place_complete_drawing(
    reduced: Image.Image,
    index: int,
    scale_corrections: dict[str, float],
    translation_overrides: dict[str, list[int]],
) -> tuple[Image.Image, dict[str, object]]:
    correction = float(scale_corrections.get(str(index), 1.0))
    if correction != 1.0:
        size = round(512 * correction)
        reduced = reduced.resize((size, size), Image.Resampling.LANCZOS)

    threshold_alpha = reduced.getchannel("A").point(lambda value: 255 if value >= 8 else 0)
    bbox = threshold_alpha.getbbox()
    if bbox is None:
        raise ValueError(f"frame {index:03d} has no visible alpha bounds")
    center_x = (bbox[0] + bbox[2] - 1) / 2.0
    dx = round(256 - center_x)
    dy = 472 - (bbox[3] - 1)
    override = translation_overrides.get(str(index), [0, 0])
    dx += int(override[0])
    dy += int(override[1])

    canvas = Image.new("RGBA", (512, 512), (0, 0, 0, 0))
    canvas.alpha_composite(reduced, (dx, dy))
    normalized_bbox = canvas.getchannel("A").point(
        lambda value: 255 if value >= 8 else 0
    ).getbbox()
    histogram = canvas.getchannel("A").histogram()
    record = {
        "index": index,
        "whole_drawing_scale": correction,
        "whole_sprite_translation": [dx, dy],
        "alpha_bbox": list(normalized_bbox) if normalized_bbox else None,
        "alpha_coverage": round(sum(histogram[8:]) / (512 * 512), 6),
        "visible_baseline_y": normalized_bbox[3] - 1 if normalized_bbox else None,
    }
    return canvas, record


def normalize_available() -> None:
    scale_corrections, translation_overrides = _normalization_config()
    FRAMES.mkdir(parents=True, exist_ok=True)
    records: list[dict[str, object]] = []

    for index in DIRECT_INDICES:
        source = ALPHA_1024 / f"frame_{index:03d}_alpha.png"
        if not source.exists():
            continue
        with Image.open(source) as image:
            rgba = image.convert("RGBA")
            if rgba.size != (1024, 1024):
                raise ValueError(f"{source.name} must be 1024x1024, got {rgba.size}")
            reduced = rgba.resize((512, 512), Image.Resampling.LANCZOS)

        canvas, record = _place_complete_drawing(
            reduced,
            index,
            scale_corrections,
            translation_overrides,
        )
        output = FRAMES / f"frame_{index:03d}.png"
        _save_png(canvas, output)
        record["source"] = source.name
        record["whole_drawing_scale"] = round(0.5 * float(record["whole_drawing_scale"]), 6)
        record["pose_family_scale_correction"] = float(
            scale_corrections.get(str(index), 1.0)
        )
        records.append(record)

    QA.mkdir(parents=True, exist_ok=True)
    (QA / "direct-frame-normalization-report.json").write_text(
        json.dumps({"status": "IN_PROGRESS", "frames": records}, indent=2),
        encoding="utf-8",
    )


def build_contact_sheet() -> None:
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    entries = manifest["frames"]
    columns = 5
    rows = math.ceil(len(entries) / columns)
    panel = 320
    label_height = 42
    panel_height = panel + label_height
    sheet = Image.new("RGBA", (columns * panel, rows * panel_height), (48, 51, 57, 255))
    draw = ImageDraw.Draw(sheet)
    font_path = Path("C:/Windows/Fonts/segoeui.ttf")
    font = ImageFont.truetype(str(font_path), 16) if font_path.exists() else ImageFont.load_default()

    for idx, entry in enumerate(entries):
        source = FRAMES / entry["file"]
        if not source.exists():
            continue
        with Image.open(source) as image:
            frame = image.convert("RGBA").resize((panel, panel), Image.Resampling.LANCZOS)
        column = idx % columns
        row = idx // columns
        x = column * panel
        y = row * panel_height
        checker = Image.new("RGBA", (panel, panel), (58, 61, 68, 255))
        checker_draw = ImageDraw.Draw(checker)
        tile = 16
        for cy in range(0, panel, tile):
            for cx in range(0, panel, tile):
                if ((cx // tile) + (cy // tile)) % 2:
                    checker_draw.rectangle((cx, cy, cx + tile - 1, cy + tile - 1), fill=(44, 47, 53, 255))
        sheet.alpha_composite(checker, (x, y + label_height))
        sheet.alpha_composite(frame, (x, y + label_height))
        draw.text((x + 10, y + 11), f"F{idx:02d} · {entry['segment']} · {entry['role']}", fill=(245, 245, 245, 255), font=font)
        baseline_y = y + label_height + round(472 * panel / 512)
        draw.line((x + 5, baseline_y, x + panel - 5, baseline_y), fill=(108, 215, 255, 150), width=1)

    QA.mkdir(parents=True, exist_ok=True)
    _save_png(sheet, QA / "nap-contact-sheet.png")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("stage", choices=("prepare-keys", "standardize", "normalize", "contact", "all"))
    args = parser.parse_args()
    if args.stage in ("prepare-keys", "all"):
        prepare_keys()
    if args.stage in ("standardize", "all"):
        standardize_sources()
    if args.stage in ("normalize", "all"):
        normalize_available()
    if args.stage in ("contact", "all"):
        build_contact_sheet()


if __name__ == "__main__":
    main()
