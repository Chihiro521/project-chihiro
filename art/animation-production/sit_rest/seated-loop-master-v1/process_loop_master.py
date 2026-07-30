from __future__ import annotations

import argparse
import importlib.util
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parent
SOURCES = ROOT / "direct-frame-sources"
FRAMES_DIR = ROOT / "frames"
QA = ROOT / "qa"
FRAME_INDICES = list(range(8, 18))
MISSING_INDICES = [9, 11, 13, 15, 17]
TARGET_VISIBLE_HEIGHT = 311
TARGET_HEAD_CENTER_X = 256.0
TARGET_BASELINE_Y = 472

HELPER_PATH = ROOT.parent / "key-poses" / "seated-loop-v3-root-locked" / "process_root_locked.py"
SPEC = importlib.util.spec_from_file_location("sit_rest_loop_helpers", HELPER_PATH)
if SPEC is None or SPEC.loader is None:
    raise RuntimeError(f"Cannot load helpers: {HELPER_PATH}")
helpers = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(helpers)


def standardize_missing_sources() -> None:
    for index in MISSING_INDICES:
        path = SOURCES / f"frame_{index:03d}_chroma.png"
        with Image.open(path) as source:
            rgb = source.convert("RGB")
            if rgb.size != (1024, 1024):
                rgb = rgb.resize((1024, 1024), Image.Resampling.LANCZOS)
            helpers._save_png(rgb, path)


def normalize_all() -> None:
    FRAMES_DIR.mkdir(parents=True, exist_ok=True)
    QA.mkdir(parents=True, exist_ok=True)
    records: list[dict[str, object]] = []

    for index in FRAME_INDICES:
        source_path = SOURCES / f"frame_{index:03d}_alpha.png"
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
        helpers._save_png(canvas, FRAMES_DIR / f"frame_{index:03d}.png")

        records.append(
            {
                "frame": index,
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
        and summary["shoe_midpoint_range_px"] <= 3.0
        and summary["visible_height_range_px"] <= 1
        and summary["baseline_range_px"] == 0
    ) else "FAIL"
    (QA / "stabilization-report.json").write_text(
        json.dumps({"status": status, "summary": summary, "frames": records}, indent=2),
        encoding="utf-8",
    )
    if status != "PASS":
        raise SystemExit(2)


def build_contact_sheet() -> None:
    columns = 5
    rows = 2
    panel_width = 512
    label_height = 46
    panel_height = 512 + label_height
    sheet = helpers._checkerboard((panel_width * columns, panel_height * rows))
    draw = ImageDraw.Draw(sheet)
    font_path = Path("C:/Windows/Fonts/segoeui.ttf")
    font = ImageFont.truetype(str(font_path), 20) if font_path.exists() else ImageFont.load_default()
    for panel, index in enumerate(FRAME_INDICES):
        with Image.open(FRAMES_DIR / f"frame_{index:03d}.png") as source:
            frame = source.convert("RGBA")
        x = (panel % columns) * panel_width
        y = (panel // columns) * panel_height
        sheet.alpha_composite(frame, (x, y + label_height))
        role = "approved" if index % 2 == 0 else "direct"
        draw.text((x + 14, y + 11), f"F{index:02d} {role}", fill=(245, 245, 245, 255), font=font)
    helpers._save_png(sheet, QA / "seated-loop-master-contact-sheet.png")


def build_slow_preview() -> None:
    rendered: list[Image.Image] = []
    for index in FRAME_INDICES:
        background = helpers._checkerboard((512, 512))
        with Image.open(FRAMES_DIR / f"frame_{index:03d}.png") as source:
            background.alpha_composite(source.convert("RGBA"))
        rendered.append(background.convert("RGB"))
    rendered[0].save(
        QA / "preview-slow.gif",
        save_all=True,
        append_images=rendered[1:],
        duration=333,
        loop=0,
        optimize=False,
        disposal=2,
    )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("stage", choices=("standardize", "normalize", "contact", "preview", "all"))
    args = parser.parse_args()
    if args.stage in ("standardize", "all"):
        standardize_missing_sources()
    if args.stage in ("normalize", "all"):
        normalize_all()
    if args.stage in ("contact", "all"):
        build_contact_sheet()
    if args.stage in ("preview", "all"):
        build_slow_preview()


if __name__ == "__main__":
    main()
