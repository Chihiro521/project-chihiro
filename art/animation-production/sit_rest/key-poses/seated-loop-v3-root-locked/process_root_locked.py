from __future__ import annotations

import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parent
ALPHA = ROOT / "alpha"
NORMALIZED = ROOT / "normalized"
QA = ROOT / "qa"
FRAMES = [
    (8, "K06 v3 / F08 contact"),
    (10, "F10 reach support"),
    (12, "F12 supported relax"),
    (14, "F14 supported blink"),
    (16, "F16 release return"),
]
ALPHA_THRESHOLD = 8
TARGET_VISIBLE_HEIGHT = 311
TARGET_FOOT_MIDPOINT_X = 256.0
TARGET_BASELINE_Y = 472


def _binary_bbox(image: Image.Image) -> tuple[int, int, int, int]:
    bbox = image.getchannel("A").point(
        lambda value: 255 if value >= ALPHA_THRESHOLD else 0
    ).getbbox()
    if bbox is None:
        raise ValueError("image has no visible alpha bounds")
    return bbox


def _column_spans(mask: Image.Image, y0: int, y1: int) -> list[tuple[int, int, int]]:
    width, _ = mask.size
    columns: list[tuple[int, int]] = []
    for x in range(width):
        count = 0
        for y in range(y0, y1):
            if mask.getpixel((x, y)) >= ALPHA_THRESHOLD:
                count += 1
        if count:
            columns.append((x, count))
    if not columns:
        raise ValueError("no visible pixels in shoe anchor band")

    spans: list[list[tuple[int, int]]] = []
    for item in columns:
        if not spans or item[0] - spans[-1][-1][0] > 2:
            spans.append([item])
        else:
            spans[-1].append(item)
    ranked = sorted(spans, key=lambda span: sum(count for _, count in span), reverse=True)
    selected = sorted(ranked[:2], key=lambda span: span[0][0])
    result: list[tuple[int, int, int]] = []
    for span in selected:
        weight = sum(count for _, count in span)
        centroid = round(sum(x * count for x, count in span) / weight)
        result.append((span[0][0], span[-1][0], centroid))
    return result


def _shoe_midpoint(image: Image.Image, bbox: tuple[int, int, int, int]) -> tuple[float, list[tuple[int, int, int]]]:
    visible_height = bbox[3] - bbox[1]
    band_height = max(24, round(visible_height * 0.12))
    y0 = max(bbox[1], bbox[3] - band_height)
    spans = _column_spans(image.getchannel("A"), y0, bbox[3])
    if len(spans) == 1:
        return float(spans[0][2]), spans
    return (spans[0][2] + spans[1][2]) / 2.0, spans


def _head_center_x(image: Image.Image, bbox: tuple[int, int, int, int]) -> float:
    head_bottom = min(bbox[3], bbox[1] + round((bbox[3] - bbox[1]) * 0.34))
    mask = image.getchannel("A")
    points: list[tuple[int, int]] = []
    for y in range(bbox[1], head_bottom):
        for x in range(bbox[0], bbox[2]):
            if mask.getpixel((x, y)) >= ALPHA_THRESHOLD:
                points.append((x, y))
    if not points:
        raise ValueError("head anchor band is empty")
    return sum(x for x, _ in points) / len(points)


def _save_png(image: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path, format="PNG", optimize=True)


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

        source_bbox = _binary_bbox(rgba)
        source_visible_height = source_bbox[3] - source_bbox[1]
        uniform_scale = TARGET_VISIBLE_HEIGHT / source_visible_height
        scaled_side = round(1024 * uniform_scale)
        scaled = rgba.resize((scaled_side, scaled_side), Image.Resampling.LANCZOS)
        scaled_bbox = _binary_bbox(scaled)
        shoe_midpoint_x, shoe_spans = _shoe_midpoint(scaled, scaled_bbox)
        dx = round(TARGET_FOOT_MIDPOINT_X - shoe_midpoint_x)
        dy = TARGET_BASELINE_Y - (scaled_bbox[3] - 1)

        canvas = Image.new("RGBA", (512, 512), (0, 0, 0, 0))
        canvas.alpha_composite(scaled, (dx, dy))
        final_bbox = _binary_bbox(canvas)
        final_shoe_midpoint_x, final_shoe_spans = _shoe_midpoint(canvas, final_bbox)
        head_center_x = _head_center_x(canvas, final_bbox)
        output_path = NORMALIZED / f"frame_{index:03d}.png"
        _save_png(canvas, output_path)

        records.append(
            {
                "frame": index,
                "label": label,
                "uniform_whole_character_scale": round(uniform_scale, 8),
                "whole_character_translation": [dx, dy],
                "alpha_bbox": list(final_bbox),
                "visible_height_px": final_bbox[3] - final_bbox[1],
                "visible_baseline_y": final_bbox[3] - 1,
                "shoe_spans": [list(span) for span in final_shoe_spans],
                "shoe_midpoint_x": round(final_shoe_midpoint_x, 3),
                "head_center_x": round(head_center_x, 3),
                "pivot": [256, 492],
            }
        )

    shoe_values = [float(record["shoe_midpoint_x"]) for record in records]
    height_values = [int(record["visible_height_px"]) for record in records]
    baseline_values = [int(record["visible_baseline_y"]) for record in records]
    head_values = [float(record["head_center_x"]) for record in records]
    summary = {
        "shoe_midpoint_range_px": round(max(shoe_values) - min(shoe_values), 3),
        "visible_height_range_px": max(height_values) - min(height_values),
        "baseline_range_px": max(baseline_values) - min(baseline_values),
        "head_center_range_px": round(max(head_values) - min(head_values), 3),
    }
    status = "PASS" if (
        summary["shoe_midpoint_range_px"] <= 1.0
        and summary["visible_height_range_px"] <= 1
        and summary["baseline_range_px"] == 0
        and summary["head_center_range_px"] <= 10.0
    ) else "FAIL"
    (QA / "stabilization-report.json").write_text(
        json.dumps({"status": status, "summary": summary, "frames": records}, indent=2),
        encoding="utf-8",
    )
    if status != "PASS":
        raise SystemExit(2)


def _checkerboard(size: tuple[int, int], tile: int = 16) -> Image.Image:
    width, height = size
    image = Image.new("RGBA", size, (58, 61, 68, 255))
    draw = ImageDraw.Draw(image)
    colors = ((58, 61, 68, 255), (44, 47, 53, 255))
    for y in range(0, height, tile):
        for x in range(0, width, tile):
            draw.rectangle(
                (x, y, min(x + tile - 1, width - 1), min(y + tile - 1, height - 1)),
                fill=colors[((x // tile) + (y // tile)) % 2],
            )
    return image


def contact_sheet() -> None:
    panel_width = 512
    label_height = 50
    panel_height = 512 + label_height
    columns = 3
    rows = 2
    sheet = _checkerboard((panel_width * columns, panel_height * rows))
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
    _save_png(sheet, QA / "sit_rest-seated-loop-v3-root-locked-contact-sheet.png")


if __name__ == "__main__":
    normalize()
    contact_sheet()
