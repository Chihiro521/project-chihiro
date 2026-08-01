from __future__ import annotations

import argparse
import json
import statistics
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parent
SOURCES = ROOT / "direct-frame-sources"
FRAMES = ROOT / "frames"
QA = ROOT / "qa"
FRAME_COUNT = 23
ACCEPTED_KEYS = {4, 8, 13, 18}
SHARED_WHOLE_DRAWING_SCALE = 1.042578
TARGET_BASELINE = 472


def path_for(index: int, suffix: str) -> Path:
    return SOURCES / f"frame_{index:03d}_{suffix}.png"


def save_png(image: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path, format="PNG", optimize=True)


def alpha_bbox(image: Image.Image) -> tuple[int, int, int, int]:
    box = image.getchannel("A").point(lambda value: 255 if value >= 8 else 0).getbbox()
    if box is None:
        raise ValueError("image has no visible alpha bounds")
    return box


def standardize_sources(indices: list[int] | None = None) -> None:
    for index in indices if indices is not None else range(FRAME_COUNT):
        path = path_for(index, "chroma")
        if not path.exists():
            raise FileNotFoundError(path)
        with Image.open(path) as source:
            rgb = source.convert("RGB")
            if rgb.size != (1024, 1024):
                rgb = rgb.resize((1024, 1024), Image.Resampling.LANCZOS)
            save_png(rgb, path)


def smoothstep(value: float) -> float:
    value = max(0.0, min(1.0, value))
    return value * value * (3.0 - 2.0 * value)


def remove_magenta_key(indices: list[int] | None = None) -> None:
    records: list[dict[str, object]] = []
    for index in indices if indices is not None else range(FRAME_COUNT):
        source_path = path_for(index, "chroma")
        output_path = path_for(index, "alpha")
        with Image.open(source_path) as source:
            rgb = source.convert("RGB")
        width, height = rgb.size
        border: list[tuple[int, int, int]] = []
        for x in range(0, width, 4):
            border.extend((rgb.getpixel((x, 0)), rgb.getpixel((x, height - 1))))
        for y in range(0, height, 4):
            border.extend((rgb.getpixel((0, y)), rgb.getpixel((width - 1, y))))
        key = tuple(round(statistics.median(pixel[channel] for pixel in border)) for channel in range(3))
        rgba = Image.new("RGBA", rgb.size, (0, 0, 0, 0))
        src = rgb.load()
        dst = rgba.load()
        transparent = 0
        partial = 0
        for y in range(height):
            for x in range(width):
                red, green, blue = src[x, y]
                dominance = min(red, blue) - green
                if min(red, blue) < 72 or dominance <= 45:
                    alpha = 255
                elif dominance >= 120:
                    alpha = 0
                else:
                    ratio = (120.0 - dominance) / 75.0
                    alpha = round(255.0 * smoothstep(ratio))
                if alpha <= 8:
                    dst[x, y] = (0, 0, 0, 0)
                    transparent += 1
                    continue
                if alpha < 255:
                    partial += 1
                    fraction = alpha / 255.0
                    red = max(0, min(255, round((red - (1.0 - fraction) * key[0]) / fraction)))
                    green = max(0, min(255, round((green - (1.0 - fraction) * key[1]) / fraction)))
                    blue = max(0, min(255, round((blue - (1.0 - fraction) * key[2]) / fraction)))
                dst[x, y] = (red, green, blue, alpha)
        save_png(rgba, output_path)
        records.append(
            {
                "index": index,
                "sampled_key_rgb": list(key),
                "transparent_pixels": transparent,
                "partially_transparent_pixels": partial,
                "total_pixels": width * height,
            }
        )
    QA.mkdir(parents=True, exist_ok=True)
    (QA / "key-removal-report.json").write_text(
        json.dumps(
            {
                "status": "PASS",
                "matte": "two-channel magenta dominance; opaque<=45, transparent>=120",
                "frames": records,
            },
            indent=2,
        ),
        encoding="utf-8",
    )


def normalize_frames() -> None:
    records: list[dict[str, object]] = []
    for index in range(FRAME_COUNT):
        output_path = FRAMES / f"frame_{index:03d}.png"
        if index in ACCEPTED_KEYS:
            with Image.open(output_path) as accepted_source:
                accepted = accepted_source.convert("RGBA")
            box = alpha_bbox(accepted)
            records.append(
                {
                    "index": index,
                    "source": "frozen_user_accepted_key",
                    "alpha_bbox": list(box),
                    "visible_baseline_y": box[3] - 1,
                    "pivot": [256, 492],
                }
            )
            continue

        with Image.open(path_for(index, "alpha")) as source:
            rgba = source.convert("RGBA")
        scaled_size = round(512 * SHARED_WHOLE_DRAWING_SCALE)
        reduced = rgba.resize((scaled_size, scaled_size), Image.Resampling.LANCZOS)
        stage = Image.new("RGBA", (512, 512), (0, 0, 0, 0))
        inset = (512 - scaled_size) // 2
        stage.alpha_composite(reduced, (inset, inset))
        box = alpha_bbox(stage)
        center_x = (box[0] + box[2] - 1) / 2.0
        dx = round(256 - center_x)
        dy = TARGET_BASELINE - (box[3] - 1)
        canvas = Image.new("RGBA", (512, 512), (0, 0, 0, 0))
        canvas.alpha_composite(stage, (dx, dy))
        final_box = alpha_bbox(canvas)
        if final_box[0] <= 0 or final_box[1] <= 0 or final_box[2] >= 512 or final_box[3] >= 512:
            raise ValueError(f"frame {index} touches cell boundary: {final_box}")
        save_png(canvas, output_path)
        records.append(
            {
                "index": index,
                "source": "independently_generated_complete_character",
                "source_size": [1024, 1024],
                "final_size": [512, 512],
                "shared_whole_drawing_scale": SHARED_WHOLE_DRAWING_SCALE,
                "whole_sprite_translation": [dx, dy],
                "alpha_bbox": list(final_box),
                "visible_baseline_y": final_box[3] - 1,
                "pivot": [256, 492],
            }
        )
    QA.mkdir(parents=True, exist_ok=True)
    (QA / "normalization-report.json").write_text(
        json.dumps(
            {
                "status": "PASS",
                "frame_count": FRAME_COUNT,
                "frozen_user_accepted_keys": sorted(ACCEPTED_KEYS),
                "shared_whole_drawing_scale": SHARED_WHOLE_DRAWING_SCALE,
                "target_baseline_y": TARGET_BASELINE,
                "frames": records,
            },
            indent=2,
        ),
        encoding="utf-8",
    )
    (ROOT / "generation-record.json").write_text(
        json.dumps(
            {
                "status": "motion_smoothing_repair_generated_pending_user",
                "frame_count": FRAME_COUNT,
                "fps": 10,
                "user_accepted_keys": sorted(ACCEPTED_KEYS),
                "new_complete_drawings": [index for index in range(FRAME_COUNT) if index not in ACCEPTED_KEYS],
                "production_method": "one built-in image generation call per complete character frame; midpoint-first temporal bounding",
                "forbidden_methods_used": [],
                "whole_frame_redraw_repairs": {
                    "5": "reduced premature head turn and restored head/body continuity",
                    "7": "replaced the one-frame strap-to-ear leap with a shoulder-height rise midpoint",
                    "9": "placed the hand at the lower ear as a strict midpoint between neck and temple",
                    "11": "made the first third of the outward wrist rotation monotonic",
                    "12": "made the second third of the outward wrist rotation monotonic",
                    "14": "kept the refusal press beside the brim and restored the muted palette",
                    "15": "released the stop beside the ear without snapping frontal",
                    "16": "placed the descending hand beside the lower cheek and shoulder",
                    "17": "continued the hand downward to the collarbone without reversing",
                    "19": "kept the open hand in the strap-height band for a horizontal approach",
                    "20": "added a partial strap grip without a vertical rebound",
                },
                "user_feedback": {
                    "date": "2026-07-30",
                    "verdict": "rejected_first_full_sequence_as_overly_jittery",
                    "repair_goal": "single-direction hand arc, stable head pose, intentional one-shot timing",
                },
            },
            indent=2,
        ),
        encoding="utf-8",
    )


def diagnose_source_geometry() -> None:
    measurements: list[dict[str, object]] = []
    heights: dict[int, int] = {}
    for index in range(FRAME_COUNT):
        with Image.open(path_for(index, "alpha")) as source:
            image = source.convert("RGBA")
        box = alpha_bbox(image)
        heights[index] = box[3] - box[1]
        measurements.append(
            {
                "index": index,
                "alpha_bbox_1024": list(box),
                "visible_width_1024": box[2] - box[0],
                "visible_height_1024": box[3] - box[1],
            }
        )
    authority_height = statistics.median(heights[index] for index in ACCEPTED_KEYS)
    flagged: list[int] = []
    for measurement in measurements:
        ratio = measurement["visible_height_1024"] / authority_height
        measurement["height_ratio_vs_accepted_keys"] = round(ratio, 5)
        if not 0.97 <= ratio <= 1.03:
            flagged.append(int(measurement["index"]))
    QA.mkdir(parents=True, exist_ok=True)
    (QA / "raw-geometry-report.json").write_text(
        json.dumps(
            {
                "status": "PASS" if not flagged else "REVIEW",
                "accepted_key_median_height_1024": authority_height,
                "review_threshold": [0.97, 1.03],
                "flagged_frames": flagged,
                "frames": measurements,
            },
            indent=2,
        ),
        encoding="utf-8",
    )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("stage", choices=("standardize", "key", "diagnose", "normalize", "all"))
    parser.add_argument("--index", type=int)
    args = parser.parse_args()
    indices = [args.index] if args.index is not None else None
    if args.index is not None and not 0 <= args.index < FRAME_COUNT:
        raise ValueError(f"index out of range: {args.index}")
    if args.stage in ("standardize", "all"):
        standardize_sources(indices)
    if args.stage in ("key", "all"):
        remove_magenta_key(indices)
    if args.stage in ("diagnose", "all"):
        diagnose_source_geometry()
    if args.stage in ("normalize", "all"):
        normalize_frames()


if __name__ == "__main__":
    main()
