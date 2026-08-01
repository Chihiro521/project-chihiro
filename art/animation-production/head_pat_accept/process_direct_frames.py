from __future__ import annotations

import json
from pathlib import Path

from PIL import Image

from process_key_poses import (
    REFERENCE,
    alpha_bbox,
    metrics,
    place_complete_drawing,
    relative_delta,
    save_png,
)


ROOT = Path(__file__).resolve().parent
SOURCES = ROOT / "direct-frame-sources"
RAW_ALPHA = SOURCES / "raw-alpha"
SOURCE_1024 = SOURCES / "source-1024"
FRAMES = ROOT / "frames-progress"
QA = ROOT / "direct-frame-qa-progress"
KEY_NORMALIZATION = ROOT / "key-qa-v2" / "normalization-report.json"
KEY_NORMALIZED = ROOT / "key-poses" / "normalized"


def fixed_scale() -> float:
    data = json.loads(KEY_NORMALIZATION.read_text(encoding="utf-8"))
    return float(data["uniform_whole_drawing_scale"])


def selected_sources() -> list[Path]:
    return sorted(RAW_ALPHA.glob("frame_*_alpha.png"))


def main() -> None:
    SOURCE_1024.mkdir(parents=True, exist_ok=True)
    FRAMES.mkdir(parents=True, exist_ok=True)
    QA.mkdir(parents=True, exist_ok=True)
    scale = fixed_scale()

    with Image.open(KEY_NORMALIZED / "k07_accept.png") as source:
        k07_metrics = metrics(source.convert("RGBA"))
    with Image.open(KEY_NORMALIZED / "k09_hold.png") as source:
        k09_metrics = metrics(source.convert("RGBA"))
    with Image.open(REFERENCE) as source:
        reference_metrics = metrics(source.convert("RGBA"))

    target = {
        "visible_height": round((k07_metrics["visible_height"] + k09_metrics["visible_height"]) / 2),
        "head_silhouette_width": round((k07_metrics["head_silhouette_width"] + k09_metrics["head_silhouette_width"]) / 2),
        "face_color_bbox_width": round((k07_metrics["face_color_bbox_width"] + k09_metrics["face_color_bbox_width"]) / 2),
        "face_color_bbox_height": round((k07_metrics["face_color_bbox_height"] + k09_metrics["face_color_bbox_height"]) / 2),
        "leg_band_width_y385": round((k07_metrics["leg_band_width_y385"] + k09_metrics["leg_band_width_y385"]) / 2),
        "sock_band_width_y425": round((k07_metrics["sock_band_width_y425"] + k09_metrics["sock_band_width_y425"]) / 2),
        "shoe_band_width_y455": round((k07_metrics["shoe_band_width_y455"] + k09_metrics["shoe_band_width_y455"]) / 2),
    }
    absolute_limits = {
        "visible_height": 2,
        "head_silhouette_width": 3,
        "face_color_bbox_width": 4,
        "face_color_bbox_height": 4,
        "leg_band_width_y385": 3,
        "sock_band_width_y425": 3,
        "shoe_band_width_y455": 3,
    }

    records: list[dict[str, object]] = []
    status = "PASS"
    for path in selected_sources():
        frame_id = path.stem.removesuffix("_alpha")
        with Image.open(path) as source:
            rgba = source.convert("RGBA")
            raw_size = list(rgba.size)
            raw_bbox = list(alpha_bbox(rgba))
            standardized = rgba
            if standardized.size != (1024, 1024):
                standardized = standardized.resize((1024, 1024), Image.Resampling.LANCZOS)
        standardized_path = SOURCE_1024 / f"{frame_id}_alpha.png"
        save_png(standardized, standardized_path)
        normalized, placement = place_complete_drawing(standardized, scale)
        output_path = FRAMES / f"{frame_id}.png"
        save_png(normalized, output_path)
        value_metrics = metrics(normalized)
        deltas = {
            key: abs(int(value_metrics[key]) - int(target[key]))
            for key in absolute_limits
        }
        violations = [
            {"metric": key, "delta_px": deltas[key], "limit_px": limit}
            for key, limit in absolute_limits.items()
            if deltas[key] > limit
        ]
        if violations:
            status = "FAIL"
        records.append(
            {
                "frame": frame_id,
                "source": str(path.relative_to(ROOT)),
                "raw_size": raw_size,
                "raw_alpha_bbox": raw_bbox,
                "fixed_whole_drawing_scale": scale,
                "placement": placement,
                "metrics": value_metrics,
                "target_action_family_metrics": target,
                "absolute_delta_px": deltas,
                "violations": violations,
            }
        )

    (QA / "progress-report.json").write_text(
        json.dumps(
            {
                "status": status,
                "policy": "Every direct frame uses the one frozen K07/K09 whole-drawing scale. Per-frame scaling is forbidden; only root translation aligns planted feet and baseline.",
                "fixed_scale": scale,
                "reference_metrics": reference_metrics,
                "action_family_target": target,
                "absolute_limits_px": absolute_limits,
                "frames": records,
            },
            ensure_ascii=False,
            indent=2,
        ),
        encoding="utf-8",
    )


if __name__ == "__main__":
    main()
