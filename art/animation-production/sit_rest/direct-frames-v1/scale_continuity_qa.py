from __future__ import annotations

import importlib.util
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parent
FRAMES = ROOT / "frames"
QA = ROOT / "qa"
LOCAL_PATH = ROOT / "local_identity_qa.py"
SPEC = importlib.util.spec_from_file_location("sit_rest_local_identity", LOCAL_PATH)
if SPEC is None or SPEC.loader is None:
    raise RuntimeError(f"Cannot load local QA helpers: {LOCAL_PATH}")
local = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(local)


def main() -> None:
    records: list[dict[str, float | int]] = []
    images: list[Image.Image] = []
    for index in range(26):
        with Image.open(FRAMES / f"frame_{index:03d}.png") as source:
            image = source.convert("RGBA")
        images.append(image)
        metrics = local.measure(image)
        records.append({"frame": index, **metrics})

    for index, record in enumerate(records):
        if index == 0:
            record["adjacent_head_width_delta_px"] = 0.0
            record["adjacent_face_width_delta_px"] = 0.0
            record["adjacent_face_height_delta_px"] = 0.0
            continue
        previous = records[index - 1]
        record["adjacent_head_width_delta_px"] = abs(
            float(record["head_width_proxy_px"]) - float(previous["head_width_proxy_px"])
        )
        record["adjacent_face_width_delta_px"] = abs(
            float(record["face_width_proxy_px"]) - float(previous["face_width_proxy_px"])
        )
        record["adjacent_face_height_delta_px"] = abs(
            float(record["face_height_proxy_px"]) - float(previous["face_height_proxy_px"])
        )

    head_values = sorted(float(record["head_width_proxy_px"]) for record in records)
    face_width_values = sorted(float(record["face_width_proxy_px"]) for record in records)
    face_height_values = sorted(float(record["face_height_proxy_px"]) for record in records)
    median = lambda values: values[len(values) // 2]
    summary = {
        "head_width_median_px": median(head_values),
        "head_width_range_px": max(head_values) - min(head_values),
        "face_width_median_px": median(face_width_values),
        "face_width_range_px": max(face_width_values) - min(face_width_values),
        "face_height_median_px": median(face_height_values),
        "face_height_range_px": max(face_height_values) - min(face_height_values),
        "max_adjacent_head_width_delta_px": max(float(record["adjacent_head_width_delta_px"]) for record in records),
        "max_adjacent_face_width_delta_px": max(float(record["adjacent_face_width_delta_px"]) for record in records),
        "max_adjacent_face_height_delta_px": max(float(record["adjacent_face_height_delta_px"]) for record in records),
    }
    thresholds = {
        "max_head_width_range_px": 2.0,
        "max_adjacent_head_width_delta_px": 2.0,
    }
    failures: list[dict[str, float | int | str]] = []
    if float(summary["head_width_range_px"]) > thresholds["max_head_width_range_px"]:
        failures.append(
            {
                "frame": -1,
                "from_frame": -1,
                "metric": "head_width_range_px",
                "value": float(summary["head_width_range_px"]),
                "limit": thresholds["max_head_width_range_px"],
            }
        )
    for record in records[1:]:
        value = float(record["adjacent_head_width_delta_px"])
        if value > thresholds["max_adjacent_head_width_delta_px"]:
            failures.append(
                {
                    "frame": int(record["frame"]),
                    "from_frame": int(record["frame"]) - 1,
                    "metric": "adjacent_head_width_delta_px",
                    "value": value,
                    "limit": thresholds["max_adjacent_head_width_delta_px"],
                }
            )
    diagnostics = {
        "face_width_note": "Face skin width is retained as a diagnostic only because gaze, hair occlusion and head pitch change the visible skin mask.",
        "face_height_note": "Face skin height is retained as a diagnostic only and is not a camera-scale authority across standing, crouching and seated pose families.",
    }
    status = "PASS" if not failures else "FAIL"
    QA.mkdir(parents=True, exist_ok=True)
    (QA / "scale-continuity-report.json").write_text(
        json.dumps(
            {"status": status, "summary": summary, "thresholds": thresholds, "diagnostics": diagnostics, "failures": failures, "frames": records},
            indent=2,
        ),
        encoding="utf-8",
    )

    columns = 7
    rows = 4
    panel = 190
    label_height = 34
    sheet = Image.new("RGBA", (columns * panel, rows * (panel + label_height)), (44, 47, 53, 255))
    draw = ImageDraw.Draw(sheet)
    font_path = Path("C:/Windows/Fonts/segoeui.ttf")
    font = ImageFont.truetype(str(font_path), 15) if font_path.exists() else ImageFont.load_default()
    for index, (image, record) in enumerate(zip(images, records)):
        bbox = local.alpha_bbox(image)
        top = max(0, bbox[1] - 8)
        crop = image.crop((161, top, 351, min(512, top + 190)))
        x = (index % columns) * panel
        y = (index // columns) * (panel + label_height)
        sheet.alpha_composite(crop, (x, y + label_height))
        color = (255, 140, 120, 255) if any(failure["frame"] == index for failure in failures) else (245, 245, 245, 255)
        draw.text(
            (x + 8, y + 8),
            f"F{index:02d} H{int(record['head_width_proxy_px'])} W{int(record['face_width_proxy_px'])}",
            fill=color,
            font=font,
        )
    sheet.save(QA / "scale-continuity-head-sheet.png", format="PNG", optimize=True)

    if status != "PASS":
        raise SystemExit(2)


if __name__ == "__main__":
    main()
