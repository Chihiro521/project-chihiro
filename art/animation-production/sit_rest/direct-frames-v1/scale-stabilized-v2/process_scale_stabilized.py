from __future__ import annotations

import argparse
import importlib.util
import json
import shutil
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parent
DIRECT = ROOT.parent
SIT_REST = DIRECT.parent
KEY_POSES = SIT_REST / "key-poses"
FRAMES = ROOT / "frames"
QA = ROOT / "qa"
TARGET_HEAD_WIDTH = 107.0
TARGET_HEAD_CENTER_X = 256.0
TARGET_BASELINE_Y = 472

HELPER_PATH = KEY_POSES / "seated-loop-v3-root-locked" / "process_root_locked.py"
HELPER_SPEC = importlib.util.spec_from_file_location("sit_rest_scale_helpers", HELPER_PATH)
if HELPER_SPEC is None or HELPER_SPEC.loader is None:
    raise RuntimeError(f"Cannot load helpers: {HELPER_PATH}")
helpers = importlib.util.module_from_spec(HELPER_SPEC)
HELPER_SPEC.loader.exec_module(helpers)

LOCAL_PATH = DIRECT / "local_identity_qa.py"
LOCAL_SPEC = importlib.util.spec_from_file_location("sit_rest_scale_identity", LOCAL_PATH)
if LOCAL_SPEC is None or LOCAL_SPEC.loader is None:
    raise RuntimeError(f"Cannot load identity measurements: {LOCAL_PATH}")
identity = importlib.util.module_from_spec(LOCAL_SPEC)
LOCAL_SPEC.loader.exec_module(identity)

REVIEW_PATH = DIRECT / "process_direct_frames.py"
REVIEW_SPEC = importlib.util.spec_from_file_location("sit_rest_scale_review", REVIEW_PATH)
if REVIEW_SPEC is None or REVIEW_SPEC.loader is None:
    raise RuntimeError(f"Cannot load review helpers: {REVIEW_PATH}")
review = importlib.util.module_from_spec(REVIEW_SPEC)
REVIEW_SPEC.loader.exec_module(review)


def source_for(index: int) -> Path:
    if index in (0, 25):
        return KEY_POSES / "transition-keys-v1" / "normalized" / "frame_000.png"
    if index in (4, 22):
        return KEY_POSES / "transition-keys-v1" / "alpha" / f"frame_{index:03d}.png"
    if 8 <= index <= 17:
        return SIT_REST / "seated-loop-master-v1" / "direct-frame-sources" / f"frame_{index:03d}_alpha.png"
    if 19 <= index <= 21:
        return KEY_POSES / "stand-up-prep-v1" / "alpha" / f"frame_{index:03d}.png"
    return DIRECT / "alpha" / f"frame_{index:03d}.png"


def build_frames() -> None:
    FRAMES.mkdir(parents=True, exist_ok=True)
    QA.mkdir(parents=True, exist_ok=True)
    records: list[dict[str, object]] = []

    for index in range(26):
        source_path = source_for(index)
        output_path = FRAMES / f"frame_{index:03d}.png"
        with Image.open(source_path) as source:
            rgba = source.convert("RGBA")

        if index in (0, 25):
            if rgba.size != (512, 512):
                raise ValueError(f"standing authority must be 512x512, got {rgba.size}")
            shutil.copyfile(source_path, output_path)
            canvas = rgba
            uniform_scale = 1.0
            translation = [0, 0]
        else:
            if rgba.size != (1024, 1024):
                raise ValueError(f"{source_path.name} must be 1024x1024, got {rgba.size}")
            source_measure = identity.measure(rgba)
            source_head_width = float(source_measure["head_width_proxy_px"])
            uniform_scale = TARGET_HEAD_WIDTH / source_head_width
            scaled_side = round(rgba.width * uniform_scale)
            scaled = rgba.resize((scaled_side, scaled_side), Image.Resampling.LANCZOS)
            scaled_bbox = helpers._binary_bbox(scaled)
            head_center_x = helpers._head_center_x(scaled, scaled_bbox)
            dx = round(TARGET_HEAD_CENTER_X - head_center_x)
            dy = TARGET_BASELINE_Y - (scaled_bbox[3] - 1)
            canvas = Image.new("RGBA", (512, 512), (0, 0, 0, 0))
            canvas.alpha_composite(scaled, (dx, dy))
            helpers._save_png(canvas, output_path)
            translation = [dx, dy]

        bbox = helpers._binary_bbox(canvas)
        final_measure = identity.measure(canvas)
        records.append(
            {
                "frame": index,
                "source": str(source_path.relative_to(SIT_REST)).replace("\\", "/"),
                "uniform_whole_character_scale": round(uniform_scale, 8),
                "whole_character_translation": translation,
                "alpha_bbox": list(bbox),
                "visible_height_px": bbox[3] - bbox[1],
                "visible_baseline_y": bbox[3] - 1,
                "head_center_x": round(helpers._head_center_x(canvas, bbox), 3),
                "head_width_proxy_px": int(final_measure["head_width_proxy_px"]),
                "face_width_proxy_px": int(final_measure["face_width_proxy_px"]),
                "face_height_proxy_px": int(final_measure["face_height_proxy_px"]),
                "pivot": [256, 492],
            }
        )

    head_widths = [int(record["head_width_proxy_px"]) for record in records]
    head_centers = [float(record["head_center_x"]) for record in records]
    baselines = [int(record["visible_baseline_y"]) for record in records]
    adjacent_head_deltas = [abs(a - b) for a, b in zip(head_widths, head_widths[1:])]
    summary = {
        "frame_count": len(records),
        "target_head_width_px": TARGET_HEAD_WIDTH,
        "head_width_range_px": max(head_widths) - min(head_widths),
        "max_adjacent_head_width_delta_px": max(adjacent_head_deltas),
        "head_center_range_px": round(max(head_centers) - min(head_centers), 3),
        "baseline_range_px": max(baselines) - min(baselines),
    }
    status = "PASS" if (
        summary["frame_count"] == 26
        and summary["head_width_range_px"] <= 2
        and summary["max_adjacent_head_width_delta_px"] <= 2
        and summary["head_center_range_px"] <= 1.5
        and summary["baseline_range_px"] == 0
    ) else "FAIL"
    (QA / "scale-normalization-report.json").write_text(
        json.dumps({"status": status, "summary": summary, "frames": records}, indent=2),
        encoding="utf-8",
    )
    if status != "PASS":
        raise SystemExit(2)


def build_review() -> None:
    review.FRAMES = FRAMES
    review.QA = QA
    review.build_contact_sheet()
    review.build_segment_contact_sheet(list(range(0, 9)), "sit_rest-enter-guided-contact-sheet.png")
    review.build_segment_contact_sheet(list(range(17, 26)), "sit_rest-exit-guided-contact-sheet.png")
    review.build_preview("preview.gif", 167)
    review.build_preview("preview-slow.gif", 333)
    build_comparison("scale-before-after.gif", 167)
    build_comparison("scale-before-after-slow.gif", 333)


def build_comparison(name: str, duration_ms: int) -> None:
    rendered: list[Image.Image] = []
    font_path = Path("C:/Windows/Fonts/segoeui.ttf")
    font = ImageFont.truetype(str(font_path), 19) if font_path.exists() else ImageFont.load_default()
    for index in range(26):
        canvas = helpers._checkerboard((1024, 512))
        with Image.open(DIRECT / "frames" / f"frame_{index:03d}.png") as source:
            canvas.alpha_composite(source.convert("RGBA"), (0, 0))
        with Image.open(FRAMES / f"frame_{index:03d}.png") as source:
            canvas.alpha_composite(source.convert("RGBA"), (512, 0))
        draw = ImageDraw.Draw(canvas)
        draw.rectangle((0, 0, 511, 34), fill=(24, 26, 30, 210))
        draw.rectangle((512, 0, 1023, 34), fill=(24, 26, 30, 210))
        draw.line((511, 0, 511, 511), fill=(230, 230, 230, 180), width=2)
        draw.text((12, 7), f"F{index:02d} v1 visible-height normalization", fill=(245, 245, 245, 255), font=font)
        draw.text((524, 7), f"F{index:02d} v2 head-scale lock", fill=(245, 245, 245, 255), font=font)
        rendered.append(canvas.convert("RGB"))
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
    parser.add_argument("stage", choices=("frames", "review", "all"))
    args = parser.parse_args()
    if args.stage in ("frames", "all"):
        build_frames()
    if args.stage in ("review", "all"):
        build_review()


if __name__ == "__main__":
    main()
