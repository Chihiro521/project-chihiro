from __future__ import annotations

import argparse
import importlib.util
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
    (10, "F10 hand approach"),
    (12, "F12 rabbit pat"),
    (14, "F14 pat + blink"),
    (16, "F16 hand withdraw"),
]
TARGET_VISIBLE_HEIGHT = 311
TARGET_HEAD_CENTER_X = 256.0
TARGET_BASELINE_Y = 472

BASE_SCRIPT = KEY_POSES / "seated-loop-v3-root-locked" / "process_root_locked.py"
SPEC = importlib.util.spec_from_file_location("sit_rest_root_lock_helpers", BASE_SCRIPT)
if SPEC is None or SPEC.loader is None:
    raise RuntimeError(f"Cannot load stabilization helpers: {BASE_SCRIPT}")
helpers = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(helpers)


def standardize_sources() -> None:
    CHROMA.mkdir(parents=True, exist_ok=True)
    ALPHA.mkdir(parents=True, exist_ok=True)
    shutil.copy2(KEY_POSES / "k06_seated_contact_chroma.png", CHROMA / "frame_008.png")
    shutil.copy2(KEY_POSES / "k06_seated_contact_alpha.png", ALPHA / "frame_008.png")
    for index, _ in FRAMES[1:]:
        path = CHROMA / f"frame_{index:03d}.png"
        with Image.open(path) as source:
            rgb = source.convert("RGB")
            if rgb.size != (1024, 1024):
                rgb = rgb.resize((1024, 1024), Image.Resampling.LANCZOS)
            helpers._save_png(rgb, path)


def normalize() -> None:
    NORMALIZED.mkdir(parents=True, exist_ok=True)
    QA.mkdir(parents=True, exist_ok=True)
    records: list[dict[str, object]] = []

    for index, label in FRAMES:
        source_path = ALPHA / f"frame_{index:03d}.png"
        with Image.open(source_path) as source:
            rgba = source.convert("RGBA")
        if rgba.size != (1024, 1024):
            raise ValueError(f"{source_path.name} must be 1024x1024, got {rgba.size}")

        source_bbox = helpers._binary_bbox(rgba)
        source_visible_height = source_bbox[3] - source_bbox[1]
        uniform_scale = TARGET_VISIBLE_HEIGHT / source_visible_height
        scaled_side = round(1024 * uniform_scale)
        scaled = rgba.resize((scaled_side, scaled_side), Image.Resampling.LANCZOS)
        scaled_bbox = helpers._binary_bbox(scaled)
        scaled_head_center_x = helpers._head_center_x(scaled, scaled_bbox)
        dx = round(TARGET_HEAD_CENTER_X - scaled_head_center_x)
        dy = TARGET_BASELINE_Y - (scaled_bbox[3] - 1)

        canvas = Image.new("RGBA", (512, 512), (0, 0, 0, 0))
        canvas.alpha_composite(scaled, (dx, dy))
        final_bbox = helpers._binary_bbox(canvas)
        head_center_x = helpers._head_center_x(canvas, final_bbox)
        shoe_midpoint_x, shoe_spans = helpers._shoe_midpoint(canvas, final_bbox)
        output_path = NORMALIZED / f"frame_{index:03d}.png"
        helpers._save_png(canvas, output_path)

        records.append(
            {
                "frame": index,
                "label": label,
                "uniform_whole_character_scale": round(uniform_scale, 8),
                "whole_character_translation": [dx, dy],
                "alpha_bbox": list(final_bbox),
                "visible_height_px": final_bbox[3] - final_bbox[1],
                "visible_baseline_y": final_bbox[3] - 1,
                "head_center_x": round(head_center_x, 3),
                "shoe_spans": [list(span) for span in shoe_spans],
                "shoe_midpoint_x": round(shoe_midpoint_x, 3),
                "pivot": [256, 492],
            }
        )

    head_values = [float(record["head_center_x"]) for record in records]
    shoe_values = [float(record["shoe_midpoint_x"]) for record in records]
    height_values = [int(record["visible_height_px"]) for record in records]
    baseline_values = [int(record["visible_baseline_y"]) for record in records]
    summary = {
        "head_center_range_px": round(max(head_values) - min(head_values), 3),
        "shoe_midpoint_range_px": round(max(shoe_values) - min(shoe_values), 3),
        "visible_height_range_px": max(height_values) - min(height_values),
        "baseline_range_px": max(baseline_values) - min(baseline_values),
    }
    status = "PASS" if (
        summary["head_center_range_px"] <= 1.0
        and summary["shoe_midpoint_range_px"] <= 6.0
        and summary["visible_height_range_px"] <= 1
        and summary["baseline_range_px"] == 0
    ) else "FAIL"
    (QA / "stabilization-report.json").write_text(
        json.dumps({"status": status, "summary": summary, "frames": records}, indent=2),
        encoding="utf-8",
    )
    if status != "PASS":
        raise SystemExit(2)


def contact_sheet() -> None:
    panel_width = 512
    label_height = 50
    panel_height = 512 + label_height
    columns = 3
    rows = 2
    sheet = helpers._checkerboard((panel_width * columns, panel_height * rows))
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
    helpers._save_png(sheet, QA / "sit_rest-seated-loop-v4-rabbit-pat-contact-sheet.png")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("stage", choices=("standardize", "normalize", "contact", "all"))
    args = parser.parse_args()
    if args.stage in ("standardize", "all"):
        standardize_sources()
    if args.stage in ("normalize", "all"):
        normalize()
    if args.stage in ("contact", "all"):
        contact_sheet()


if __name__ == "__main__":
    main()
