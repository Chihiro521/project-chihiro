from __future__ import annotations

import argparse
import importlib.util
import json
import shutil
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parent
SIT_REST = ROOT.parent
KEY_POSES = SIT_REST / "key-poses"
CHROMA = ROOT / "chroma"
ALPHA = ROOT / "alpha"
FRAMES = ROOT / "frames"
QA = ROOT / "qa"
GENERATED_INDICES = (1, 2, 3, 5, 6, 7, 18, 23, 24)
TARGET_VISIBLE_HEIGHTS = {
    1: 446,
    2: 430,
    3: 404,
    5: 350,
    6: 332,
    7: 318,
    18: 315,
    23: 420,
    24: 441,
}
TARGET_HEAD_CENTER_X = 256.0
TARGET_BASELINE_Y = 472

HELPER_PATH = KEY_POSES / "seated-loop-v3-root-locked" / "process_root_locked.py"
SPEC = importlib.util.spec_from_file_location("sit_rest_direct_helpers", HELPER_PATH)
if SPEC is None or SPEC.loader is None:
    raise RuntimeError(f"Cannot load helpers: {HELPER_PATH}")
helpers = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(helpers)


def _approved_source(index: int) -> Path:
    if index in (0, 4, 25):
        return KEY_POSES / "transition-keys-v1" / "normalized" / f"frame_{index:03d}.png"
    if 8 <= index <= 17:
        return SIT_REST / "seated-loop-master-v1" / "frames" / f"frame_{index:03d}.png"
    if 19 <= index <= 22:
        return KEY_POSES / "stand-up-prep-v1" / "normalized" / f"frame_{index:03d}.png"
    raise ValueError(f"frame {index} is not an approved source")


def standardize_sources() -> None:
    for index in GENERATED_INDICES:
        path = CHROMA / f"frame_{index:03d}.png"
        if not path.exists():
            continue
        with Image.open(path) as source:
            rgb = source.convert("RGB")
            if rgb.size != (1024, 1024):
                rgb = rgb.resize((1024, 1024), Image.Resampling.LANCZOS)
            helpers._save_png(rgb, path)


def build_frames() -> None:
    FRAMES.mkdir(parents=True, exist_ok=True)
    QA.mkdir(parents=True, exist_ok=True)
    records: list[dict[str, object]] = []

    for index in range(26):
        output = FRAMES / f"frame_{index:03d}.png"
        if index not in GENERATED_INDICES:
            source_path = _approved_source(index)
            shutil.copyfile(source_path, output)
            with Image.open(output) as source:
                canvas = source.convert("RGBA")
            scale = 1.0
            translation = [0, 0]
            source_kind = "approved_frozen"
        else:
            source_path = ALPHA / f"frame_{index:03d}.png"
            with Image.open(source_path) as source:
                rgba = source.convert("RGBA")
            if rgba.size != (1024, 1024):
                raise ValueError(f"{source_path.name} must be 1024x1024, got {rgba.size}")
            source_bbox = helpers._binary_bbox(rgba)
            source_height = source_bbox[3] - source_bbox[1]
            scale = TARGET_VISIBLE_HEIGHTS[index] / source_height
            scaled_side = round(1024 * scale)
            scaled = rgba.resize((scaled_side, scaled_side), Image.Resampling.LANCZOS)
            scaled_bbox = helpers._binary_bbox(scaled)
            head_center_x = helpers._head_center_x(scaled, scaled_bbox)
            dx = round(TARGET_HEAD_CENTER_X - head_center_x)
            dy = TARGET_BASELINE_Y - (scaled_bbox[3] - 1)
            canvas = Image.new("RGBA", (512, 512), (0, 0, 0, 0))
            canvas.alpha_composite(scaled, (dx, dy))
            helpers._save_png(canvas, output)
            translation = [dx, dy]
            source_kind = "generated_complete_character"

        bbox = helpers._binary_bbox(canvas)
        head_center_x = helpers._head_center_x(canvas, bbox)
        shoe_midpoint_x, shoe_spans = helpers._shoe_midpoint(canvas, bbox)
        records.append(
            {
                "frame": index,
                "source": str(source_path.relative_to(SIT_REST)).replace("\\", "/"),
                "source_kind": source_kind,
                "uniform_whole_character_scale": round(scale, 8),
                "whole_character_translation": translation,
                "alpha_bbox": list(bbox),
                "visible_height_px": bbox[3] - bbox[1],
                "visible_baseline_y": bbox[3] - 1,
                "head_center_x": round(head_center_x, 3),
                "shoe_midpoint_x": round(shoe_midpoint_x, 3),
                "shoe_spans": [list(span) for span in shoe_spans],
                "pivot": [256, 492],
            }
        )

    baselines = [int(record["visible_baseline_y"]) for record in records]
    generated_head_centers = [
        float(record["head_center_x"])
        for record in records
        if int(record["frame"]) in GENERATED_INDICES
    ]
    enter_heights = [int(record["visible_height_px"]) for record in records[:9]]
    exit_heights = [int(record["visible_height_px"]) for record in records[17:]]
    enter_monotonic = all(a >= b for a, b in zip(enter_heights, enter_heights[1:]))
    exit_monotonic = all(a <= b for a, b in zip(exit_heights, exit_heights[1:]))
    summary = {
        "frame_count": len(records),
        "baseline_range_px": max(baselines) - min(baselines),
        "generated_head_center_range_px": round(max(generated_head_centers) - min(generated_head_centers), 3),
        "enter_visible_height_nonincreasing": enter_monotonic,
        "exit_visible_height_nondecreasing": exit_monotonic,
    }
    status = "PASS" if (
        summary["frame_count"] == 26
        and summary["baseline_range_px"] == 0
        and summary["generated_head_center_range_px"] <= 1.5
        and enter_monotonic
        and exit_monotonic
    ) else "FAIL"
    (QA / "normalization-report.json").write_text(
        json.dumps({"status": status, "summary": summary, "frames": records}, indent=2),
        encoding="utf-8",
    )
    if status != "PASS":
        raise SystemExit(2)


def build_contact_sheet() -> None:
    columns = 6
    rows = 5
    panel_width = 512
    label_height = 46
    panel_height = 512 + label_height
    sheet = helpers._checkerboard((columns * panel_width, rows * panel_height))
    draw = ImageDraw.Draw(sheet)
    font_path = Path("C:/Windows/Fonts/segoeui.ttf")
    font = ImageFont.truetype(str(font_path), 19) if font_path.exists() else ImageFont.load_default()
    generated = set(GENERATED_INDICES)
    for index in range(26):
        with Image.open(FRAMES / f"frame_{index:03d}.png") as source:
            frame = source.convert("RGBA")
        x = (index % columns) * panel_width
        y = (index // columns) * panel_height
        sheet.alpha_composite(frame, (x, y + label_height))
        role = "direct" if index in generated else "approved"
        draw.text((x + 12, y + 10), f"F{index:02d} {role}", fill=(245, 245, 245, 255), font=font)
    helpers._save_png(sheet, QA / "sit_rest-full-contact-sheet.png")


def build_segment_contact_sheet(indices: list[int], name: str) -> None:
    columns = 5
    rows = 2
    panel_width = 512
    label_height = 46
    panel_height = 512 + label_height
    sheet = helpers._checkerboard((columns * panel_width, rows * panel_height))
    draw = ImageDraw.Draw(sheet)
    font_path = Path("C:/Windows/Fonts/segoeui.ttf")
    font = ImageFont.truetype(str(font_path), 19) if font_path.exists() else ImageFont.load_default()
    generated = set(GENERATED_INDICES)
    for panel, index in enumerate(indices):
        with Image.open(FRAMES / f"frame_{index:03d}.png") as source:
            frame = source.convert("RGBA")
        x = (panel % columns) * panel_width
        y = (panel // columns) * panel_height
        frame_y = y + label_height
        draw.line((x + 256, frame_y, x + 256, frame_y + 511), fill=(84, 214, 255, 120), width=1)
        draw.line((x, frame_y + 472, x + 511, frame_y + 472), fill=(255, 196, 84, 150), width=1)
        sheet.alpha_composite(frame, (x, frame_y))
        role = "direct" if index in generated else "approved"
        draw.text((x + 12, y + 10), f"F{index:02d} {role}", fill=(245, 245, 245, 255), font=font)
    helpers._save_png(sheet, QA / name)


def build_preview(name: str, duration_ms: int) -> None:
    rendered: list[Image.Image] = []
    for index in range(26):
        background = helpers._checkerboard((512, 512))
        with Image.open(FRAMES / f"frame_{index:03d}.png") as source:
            background.alpha_composite(source.convert("RGBA"))
        rendered.append(background.convert("RGB"))
    rendered[0].save(
        QA / name,
        save_all=True,
        append_images=rendered[1:],
        duration=duration_ms,
        loop=0,
        optimize=False,
        disposal=2,
    )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("stage", choices=("standardize", "frames", "contact", "preview", "all"))
    args = parser.parse_args()
    if args.stage in ("standardize", "all"):
        standardize_sources()
    if args.stage in ("frames", "all"):
        build_frames()
    if args.stage in ("contact", "all"):
        build_contact_sheet()
        build_segment_contact_sheet(list(range(0, 9)), "sit_rest-enter-guided-contact-sheet.png")
        build_segment_contact_sheet(list(range(17, 26)), "sit_rest-exit-guided-contact-sheet.png")
    if args.stage in ("preview", "all"):
        build_preview("preview.gif", 167)
        build_preview("preview-slow.gif", 333)


if __name__ == "__main__":
    main()
