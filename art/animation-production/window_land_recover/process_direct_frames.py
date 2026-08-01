from __future__ import annotations

import argparse
import importlib.util
import json
import shutil
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parent
SOURCES = ROOT / "direct-frame-sources"
CHROMA = ROOT / "direct-chroma"
RAW_ALPHA = ROOT / "direct-alpha-raw"
ALPHA = ROOT / "direct-alpha"
TEMPORAL = ROOT / "direct-temporal"
FRAMES = ROOT / "frames"
QA = ROOT / "qa"
KEY_POSES = ROOT / "key-poses"
KEY_TEMPORAL = ROOT / "key-temporal"
HELPER_PATH = ROOT / "process_key_poses.py"
SPEC = importlib.util.spec_from_file_location("window_land_key_helpers", HELPER_PATH)
if SPEC is None or SPEC.loader is None:
    raise RuntimeError(f"Cannot load helpers: {HELPER_PATH}")
helpers = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(helpers)

KEYS = {
    0: ("k00.png", "k00_descent_chroma.png"),
    3: ("k03.png", "k03_contact_chroma.png"),
    6: ("k06.png", "k06_absorb_chroma.png"),
    10: ("k10.png", "k10_stabilize_chroma.png"),
    14: ("k14.png", "k14_recovered_chroma.png"),
}
TARGET_BOTTOMS = {
    0: 888,
    1: 906,
    2: 925,
    3: 944,
    4: 944,
    5: 944,
    6: 944,
    7: 944,
    8: 944,
    9: 944,
    10: 944,
    11: 944,
    12: 944,
    13: 944,
    14: 944,
}
TARGET_HEAD_WIDTH_1024 = 202
TARGET_HEAD_CENTER_X = 512.0
DIRECT_INDICES = [1, 2, 4, 5, 7, 8, 9, 11, 12, 13]


def _ensure_dirs() -> None:
    for path in (CHROMA, RAW_ALPHA, ALPHA, TEMPORAL, FRAMES, QA):
        path.mkdir(parents=True, exist_ok=True)


def sync_keys() -> None:
    _ensure_dirs()
    for index, (frame_name, temporal_name) in KEYS.items():
        shutil.copyfile(KEY_POSES / frame_name, FRAMES / f"frame_{index:03d}.png")
        shutil.copyfile(KEY_TEMPORAL / temporal_name, TEMPORAL / f"frame_{index:03d}_chroma.png")


def process_direct(index: int) -> dict[str, object]:
    if index not in DIRECT_INDICES:
        raise ValueError(f"frame {index} is not a direct-frame slot")
    _ensure_dirs()
    source_path = SOURCES / f"frame_{index:03d}_chroma.png"
    if not source_path.exists():
        raise FileNotFoundError(source_path)

    standardized_path = CHROMA / source_path.name
    with Image.open(source_path) as source:
        rgb = source.convert("RGB")
        raw_dimensions = list(rgb.size)
        if rgb.size != (1024, 1024):
            rgb = rgb.resize((1024, 1024), Image.Resampling.LANCZOS)
        helpers._save_png(rgb, standardized_path)

    raw_alpha = helpers._remove_magenta_background(rgb)
    raw_alpha_path = RAW_ALPHA / f"frame_{index:03d}_alpha.png"
    helpers._save_png(raw_alpha, raw_alpha_path)
    source_bbox = helpers._binary_bbox(raw_alpha)
    source_head_bbox = helpers._head_bbox(raw_alpha, source_bbox)
    source_head_width = source_head_bbox[2] - source_head_bbox[0]
    scale = TARGET_HEAD_WIDTH_1024 / source_head_width
    if not 0.82 <= scale <= 1.24:
        raise ValueError(f"frame {index} requires unsafe whole-drawing scale {scale:.4f}")

    scaled_side = round(1024 * scale)
    scaled = raw_alpha.resize((scaled_side, scaled_side), Image.Resampling.LANCZOS)
    scaled_bbox = helpers._binary_bbox(scaled)
    scaled_head_bbox = helpers._head_bbox(scaled, scaled_bbox)
    head_center_x = (scaled_head_bbox[0] + scaled_head_bbox[2] - 1) / 2.0
    dx = round(TARGET_HEAD_CENTER_X - head_center_x)
    target_bottom = TARGET_BOTTOMS[index]
    dy = target_bottom - (scaled_bbox[3] - 1)

    normalized = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
    normalized.alpha_composite(scaled, (dx, dy))
    final_bbox_1024 = helpers._binary_bbox(normalized)
    final_head_bbox_1024 = helpers._head_bbox(normalized, final_bbox_1024)
    helpers._save_png(normalized, ALPHA / f"frame_{index:03d}_alpha.png")

    magenta = Image.new("RGBA", (1024, 1024), (255, 0, 255, 255))
    magenta.alpha_composite(normalized)
    helpers._save_png(magenta.convert("RGB"), TEMPORAL / f"frame_{index:03d}_chroma.png")

    reduced = normalized.resize((512, 512), Image.Resampling.LANCZOS)
    frame_path = FRAMES / f"frame_{index:03d}.png"
    helpers._save_png(reduced, frame_path)
    final_bbox_512 = helpers._binary_bbox(reduced)
    final_head_bbox_512 = helpers._head_bbox(reduced, final_bbox_512)
    return {
        "index": index,
        "source": str(source_path.relative_to(ROOT)).replace("\\", "/"),
        "raw_dimensions": raw_dimensions,
        "standardized_dimensions": [1024, 1024],
        "whole_drawing_scale": round(scale, 8),
        "whole_drawing_translation": [dx, dy],
        "target_visible_bottom_1024": target_bottom,
        "bbox_1024": list(final_bbox_1024),
        "head_bbox_1024": list(final_head_bbox_1024),
        "bbox_512": list(final_bbox_512),
        "head_bbox_512": list(final_head_bbox_512),
        "complete_drawing_only": True,
        "local_part_operations": False,
    }


def _update_record(record: dict[str, object]) -> None:
    path = ROOT / "direct-frame-normalization.json"
    payload: dict[str, object] = {
        "action": "window_land_recover",
        "target_head_width_1024": TARGET_HEAD_WIDTH_1024,
        "pivot": [256, 492],
        "method": "uniform whole-drawing scale and translation after fixed two-channel magenta removal",
        "forbidden": "no part movement, compositing, interpolation, optical flow, morph or warp",
        "frames": [],
    }
    if path.exists():
        payload = json.loads(path.read_text(encoding="utf-8"))
    records = [item for item in payload.get("frames", []) if int(item["index"]) != int(record["index"])]
    records.append(record)
    records.sort(key=lambda item: int(item["index"]))
    payload["frames"] = records
    path.write_text(json.dumps(payload, indent=2), encoding="utf-8")


def build_available_report() -> None:
    records: list[dict[str, object]] = []
    for index in range(15):
        frame_path = FRAMES / f"frame_{index:03d}.png"
        if not frame_path.exists():
            continue
        with Image.open(frame_path) as source:
            frame = source.convert("RGBA")
        bbox = helpers._binary_bbox(frame)
        head_bbox = helpers._head_bbox(frame, bbox)
        records.append(
            {
                "index": index,
                "bbox": list(bbox),
                "visible_height": bbox[3] - bbox[1],
                "visible_bottom": bbox[3] - 1,
                "head_bbox": list(head_bbox),
                "head_width": head_bbox[2] - head_bbox[0],
            }
        )
    head_widths = [int(item["head_width"]) for item in records]
    payload = {
        "status": "PASS" if records and max(head_widths) - min(head_widths) <= 4 else "FAIL",
        "available_frames": len(records),
        "head_width_range_px": max(head_widths) - min(head_widths) if head_widths else None,
        "frames": records,
    }
    (QA / "available-normalization-report.json").write_text(
        json.dumps(payload, indent=2), encoding="utf-8"
    )
    if payload["status"] != "PASS":
        raise SystemExit(2)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=("sync-keys", "process", "all", "report"))
    parser.add_argument("--index", type=int)
    args = parser.parse_args()
    if args.command in ("sync-keys", "all"):
        sync_keys()
    if args.command == "process":
        if args.index is None:
            raise ValueError("--index is required for process")
        record = process_direct(args.index)
        _update_record(record)
    elif args.command == "all":
        for index in DIRECT_INDICES:
            if (SOURCES / f"frame_{index:03d}_chroma.png").exists():
                _update_record(process_direct(index))
    if args.command in ("process", "all", "report"):
        build_available_report()


if __name__ == "__main__":
    main()
