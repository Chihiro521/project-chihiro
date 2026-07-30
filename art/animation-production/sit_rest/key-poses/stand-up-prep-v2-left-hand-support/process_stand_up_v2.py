from __future__ import annotations

import argparse
import importlib.util
import json
import shutil
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parent
KEY_POSES = ROOT.parent
SIT_REST = KEY_POSES.parent
CHROMA = ROOT / "chroma"
ALPHA = ROOT / "alpha"
NORMALIZED = ROOT / "normalized"
QA = ROOT / "qa"
FRAMES = [
    (17, "F17 seated authority"),
    (19, "F19 left hand reaches"),
    (20, "F20 left palm supports"),
    (21, "F21 hand releases"),
    (22, "F22 arm counterbalances"),
    (25, "F25 exact stand return"),
]
TARGET_VISIBLE_HEIGHTS = {19: 325, 20: 330, 21: 375, 22: 410}
TARGET_HEAD_CENTER_X = 256.0
TARGET_BASELINE_Y = 472

HELPER_PATH = KEY_POSES / "seated-loop-v3-root-locked" / "process_root_locked.py"
SPEC = importlib.util.spec_from_file_location("sit_rest_stand_up_v2_helpers", HELPER_PATH)
if SPEC is None or SPEC.loader is None:
    raise RuntimeError(f"Cannot load helpers: {HELPER_PATH}")
helpers = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(helpers)


def standardize_sources() -> None:
    for index in (19, 20, 21, 22):
        path = CHROMA / f"frame_{index:03d}.png"
        with Image.open(path) as source:
            rgb = source.convert("RGB")
            if rgb.size != (1024, 1024):
                rgb = rgb.resize((1024, 1024), Image.Resampling.LANCZOS)
            helpers._save_png(rgb, path)


def _source_for(index: int) -> Path:
    if index == 17:
        return SIT_REST / "seated-loop-master-v1" / "frames" / "frame_017.png"
    if index == 25:
        return KEY_POSES / "transition-keys-v1" / "normalized" / "frame_025.png"
    return ALPHA / f"frame_{index:03d}.png"


def normalize() -> None:
    NORMALIZED.mkdir(parents=True, exist_ok=True)
    QA.mkdir(parents=True, exist_ok=True)
    records: list[dict[str, object]] = []

    for index, label in FRAMES:
        source_path = _source_for(index)
        with Image.open(source_path) as source:
            rgba = source.convert("RGBA")
        output_path = NORMALIZED / f"frame_{index:03d}.png"

        if index in (17, 25):
            if rgba.size != (512, 512):
                raise ValueError(f"approved {source_path.name} must be 512x512, got {rgba.size}")
            shutil.copyfile(source_path, output_path)
            canvas = rgba
            dx = 0
            dy = 0
            scale = 1.0
        else:
            if rgba.size != (1024, 1024):
                raise ValueError(f"generated {source_path.name} must be 1024x1024, got {rgba.size}")
            source_bbox = helpers._binary_bbox(rgba)
            source_visible_height = source_bbox[3] - source_bbox[1]
            scale = TARGET_VISIBLE_HEIGHTS[index] / source_visible_height
            scaled_side = round(1024 * scale)
            scaled = rgba.resize((scaled_side, scaled_side), Image.Resampling.LANCZOS)
            bbox = helpers._binary_bbox(scaled)
            head_center_x = helpers._head_center_x(scaled, bbox)
            dx = round(TARGET_HEAD_CENTER_X - head_center_x)
            dy = TARGET_BASELINE_Y - (bbox[3] - 1)
            canvas = Image.new("RGBA", (512, 512), (0, 0, 0, 0))
            canvas.alpha_composite(scaled, (dx, dy))
            helpers._save_png(canvas, output_path)

        final_bbox = helpers._binary_bbox(canvas)
        final_head_center_x = helpers._head_center_x(canvas, final_bbox)
        final_shoe_midpoint_x, final_shoe_spans = helpers._shoe_midpoint(canvas, final_bbox)
        records.append(
            {
                "frame": index,
                "label": label,
                "uniform_whole_character_scale": round(scale, 8),
                "whole_character_translation": [dx, dy],
                "alpha_bbox": list(final_bbox),
                "visible_height_px": final_bbox[3] - final_bbox[1],
                "visible_baseline_y": final_bbox[3] - 1,
                "head_center_x": round(final_head_center_x, 3),
                "shoe_midpoint_x": round(final_shoe_midpoint_x, 3),
                "shoe_spans": [list(span) for span in final_shoe_spans],
                "pivot": [256, 492],
            }
        )

    head_values = [float(record["head_center_x"]) for record in records]
    baseline_values = [int(record["visible_baseline_y"]) for record in records]
    summary = {
        "head_center_range_px": round(max(head_values) - min(head_values), 3),
        "baseline_range_px": max(baseline_values) - min(baseline_values),
    }
    status = "PASS" if summary["head_center_range_px"] <= 1.0 and summary["baseline_range_px"] == 0 else "FAIL"
    (QA / "normalization-report.json").write_text(
        json.dumps({"status": status, "summary": summary, "frames": records}, indent=2),
        encoding="utf-8",
    )
    if status != "PASS":
        raise SystemExit(2)


def contact_sheets() -> None:
    label_height = 50
    columns = 3
    rows = 2
    sheet = helpers._checkerboard((columns * 512, rows * (512 + label_height)))
    draw = ImageDraw.Draw(sheet)
    font_path = Path("C:/Windows/Fonts/segoeui.ttf")
    font = ImageFont.truetype(str(font_path), 20) if font_path.exists() else ImageFont.load_default()

    frames: dict[int, Image.Image] = {}
    for panel, (index, label) in enumerate(FRAMES):
        with Image.open(NORMALIZED / f"frame_{index:03d}.png") as source:
            frame = source.convert("RGBA")
        frames[index] = frame
        column = panel % columns
        row = panel // columns
        x = column * 512
        y = row * (512 + label_height)
        sheet.alpha_composite(frame, (x, y + label_height))
        draw.text((x + 14, y + 13), label, fill=(245, 245, 245, 255), font=font)
    helpers._save_png(sheet, QA / "stand-up-v2-contact-sheet.png")

    hand_indices = (19, 20, 21, 22)
    crop_box = (256, 190, 512, 512)
    crop_size = (384, 483)
    close = helpers._checkerboard((len(hand_indices) * crop_size[0], crop_size[1] + label_height))
    close_draw = ImageDraw.Draw(close)
    labels = {
        19: "F19 reach",
        20: "F20 support",
        21: "F21 release",
        22: "F22 counterbalance",
    }
    for panel, index in enumerate(hand_indices):
        crop = frames[index].crop(crop_box).resize(crop_size, Image.Resampling.LANCZOS)
        x = panel * crop_size[0]
        close.alpha_composite(crop, (x, label_height))
        close_draw.text((x + 12, 13), labels[index], fill=(245, 245, 245, 255), font=font)
    helpers._save_png(close, QA / "left-hand-contact-closeup.png")


def slow_preview() -> None:
    images: list[Image.Image] = []
    for index, _ in FRAMES:
        with Image.open(NORMALIZED / f"frame_{index:03d}.png") as source:
            rgba = source.convert("RGBA")
        background = helpers._checkerboard((512, 512)).convert("RGBA")
        background.alpha_composite(rgba)
        images.append(background.convert("P", palette=Image.Palette.ADAPTIVE))
    images[0].save(
        QA / "preview-slow.gif",
        save_all=True,
        append_images=images[1:],
        duration=333,
        loop=0,
        disposal=2,
    )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("stage", choices=("standardize", "normalize", "contact", "slow", "all"))
    args = parser.parse_args()
    if args.stage in ("standardize", "all"):
        standardize_sources()
    if args.stage in ("normalize", "all"):
        normalize()
    if args.stage in ("contact", "all"):
        contact_sheets()
    if args.stage in ("slow", "all"):
        slow_preview()


if __name__ == "__main__":
    main()
