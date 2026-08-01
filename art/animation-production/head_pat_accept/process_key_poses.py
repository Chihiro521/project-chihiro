from __future__ import annotations

import json
import statistics
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont, ImageStat


ROOT = Path(__file__).resolve().parent
KEYS = ROOT / "key-poses"
RAW_ALPHA = KEYS / "raw-alpha-v4"
SOURCE_1024 = KEYS / "source-1024"
NORMALIZED = KEYS / "normalized"
QA = ROOT / "key-qa-v2"

REFERENCE = ROOT.parent / "return_wave" / "frames" / "frame_000.png"
TARGET_BASELINE = 472
TARGET_VISIBLE_HEIGHT = 453
PIVOT_X = 256

POSES = [
    ("k07_accept", "k07_accept", "K07  轻倾迎合"),
    ("k09_hold", "k09_hold", "K09  闭眼停留"),
]


def save_png(image: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path, format="PNG", optimize=True)


def alpha_bbox(image: Image.Image, threshold: int = 8) -> tuple[int, int, int, int]:
    bbox = image.getchannel("A").point(
        lambda value: 255 if value >= threshold else 0
    ).getbbox()
    if bbox is None:
        raise ValueError("empty alpha bounds")
    return bbox


def standardize_sources() -> None:
    SOURCE_1024.mkdir(parents=True, exist_ok=True)
    for output_stem, source_stem, _ in POSES:
        chroma_path = KEYS / f"{source_stem}_chroma.png"
        alpha_path = RAW_ALPHA / f"{source_stem}_alpha.png"
        with Image.open(chroma_path) as source:
            rgb = source.convert("RGB")
            if rgb.size != (1024, 1024):
                rgb = rgb.resize((1024, 1024), Image.Resampling.LANCZOS)
            save_png(rgb, SOURCE_1024 / f"{output_stem}_chroma.png")
        with Image.open(alpha_path) as source:
            rgba = source.convert("RGBA")
            if rgba.size != (1024, 1024):
                rgba = rgba.resize((1024, 1024), Image.Resampling.LANCZOS)
            save_png(rgba, SOURCE_1024 / f"{output_stem}_alpha.png")


def normalized_scale() -> float:
    heights: list[int] = []
    for output_stem, _, _ in POSES:
        with Image.open(SOURCE_1024 / f"{output_stem}_alpha.png") as source:
            bbox = alpha_bbox(source.convert("RGBA"))
        heights.append(bbox[3] - bbox[1])
    median_height = statistics.median(heights)
    return TARGET_VISIBLE_HEIGHT * 1024.0 / (median_height * 512.0)


def place_complete_drawing(source: Image.Image, scale: float) -> tuple[Image.Image, dict[str, object]]:
    rgba = source.convert("RGBA")
    side = round(512 * scale)
    reduced = rgba.resize((side, side), Image.Resampling.LANCZOS)
    staging = Image.new("RGBA", (512, 512), (0, 0, 0, 0))
    inset = (512 - side) // 2
    staging.alpha_composite(reduced, (inset, inset))

    bbox = alpha_bbox(staging)
    alpha = staging.getchannel("A")
    foot_band = alpha.crop((0, max(bbox[1], bbox[3] - 78), 512, bbox[3]))
    foot_bbox = foot_band.point(lambda value: 255 if value >= 8 else 0).getbbox()
    if foot_bbox is None:
        raise ValueError("missing planted-foot region")
    foot_center_x = (foot_bbox[0] + foot_bbox[2] - 1) / 2.0
    dx = round(PIVOT_X - foot_center_x)
    dy = TARGET_BASELINE - (bbox[3] - 1)

    canvas = Image.new("RGBA", (512, 512), (0, 0, 0, 0))
    canvas.alpha_composite(staging, (dx, dy))
    final_bbox = alpha_bbox(canvas)
    if final_bbox[0] <= 0 or final_bbox[1] <= 0 or final_bbox[2] >= 512 or final_bbox[3] >= 512:
        raise ValueError(f"normalization clipped the complete drawing: {final_bbox}")
    return canvas, {
        "whole_drawing_scale": round(scale, 6),
        "whole_sprite_translation": [dx, dy],
        "alpha_bbox": list(final_bbox),
        "visible_height": final_bbox[3] - final_bbox[1],
        "visible_baseline_y": final_bbox[3] - 1,
        "foot_center_x_before_translation": round(foot_center_x, 3),
        "pivot": [PIVOT_X, 492],
    }


def row_alpha_width(image: Image.Image, y: int, threshold: int = 32) -> int:
    alpha = image.getchannel("A")
    row = alpha.crop((0, max(0, min(511, y)), 512, max(0, min(511, y)) + 1))
    bbox = row.point(lambda value: 255 if value >= threshold else 0).getbbox()
    return 0 if bbox is None else bbox[2] - bbox[0]


def color_bbox(image: Image.Image, predicate) -> tuple[int, int, int, int] | None:
    rgba = image.convert("RGBA")
    pixels = rgba.load()
    mask = Image.new("L", rgba.size, 0)
    out = mask.load()
    for y in range(rgba.height):
        for x in range(rgba.width):
            r, g, b, a = pixels[x, y]
            if a >= 24 and predicate(r, g, b):
                out[x, y] = 255
    return mask.getbbox()


def metrics(image: Image.Image) -> dict[str, object]:
    rgba = image.convert("RGBA")
    bbox = alpha_bbox(rgba)
    height = bbox[3] - bbox[1]
    head_limit = min(512, bbox[1] + round(height * 0.31))
    head_alpha = rgba.getchannel("A").crop((0, bbox[1], 512, head_limit))
    head_bbox_local = head_alpha.point(lambda value: 255 if value >= 16 else 0).getbbox()
    if head_bbox_local is None:
        raise ValueError("missing head silhouette")
    head_width = head_bbox_local[2] - head_bbox_local[0]

    face_bbox = color_bbox(
        rgba.crop((0, bbox[1], 512, head_limit)),
        lambda r, g, b: r >= 210 and g >= 150 and b >= 120 and r - g >= 12 and g - b >= 3,
    )
    face_width = 0 if face_bbox is None else face_bbox[2] - face_bbox[0]
    face_height = 0 if face_bbox is None else face_bbox[3] - face_bbox[1]

    hair_pixels: list[int] = []
    fabric_pixels: list[int] = []
    px = rgba.load()
    for y in range(bbox[1], min(head_limit, rgba.height)):
        for x in range(bbox[0], bbox[2]):
            r, g, b, a = px[x, y]
            if a >= 64 and 130 <= r <= 235 and 115 <= g <= 225 and 95 <= b <= 210 and r >= g >= b:
                hair_pixels.append(round(0.2126 * r + 0.7152 * g + 0.0722 * b))
    for y in range(bbox[1] + round(height * 0.28), bbox[1] + round(height * 0.66)):
        for x in range(bbox[0], bbox[2]):
            r, g, b, a = px[x, y]
            if a >= 64 and r < 90 and g < 95 and b < 115:
                fabric_pixels.append(round(0.2126 * r + 0.7152 * g + 0.0722 * b))

    return {
        "alpha_bbox": list(bbox),
        "visible_height": height,
        "head_silhouette_width": head_width,
        "face_color_bbox_width": face_width,
        "face_color_bbox_height": face_height,
        "hair_luma_median": statistics.median(hair_pixels) if hair_pixels else None,
        "navy_luma_median": statistics.median(fabric_pixels) if fabric_pixels else None,
        "hem_row_width_y330": row_alpha_width(rgba, 330),
        "leg_band_width_y385": row_alpha_width(rgba, 385),
        "sock_band_width_y425": row_alpha_width(rgba, 425),
        "shoe_band_width_y455": row_alpha_width(rgba, 455),
    }


def relative_delta(value: float | int | None, reference: float | int | None) -> float | None:
    if value is None or reference in (None, 0):
        return None
    return round(abs(float(value) - float(reference)) / abs(float(reference)), 6)


def normalize_and_report() -> None:
    NORMALIZED.mkdir(parents=True, exist_ok=True)
    QA.mkdir(parents=True, exist_ok=True)
    scale = normalized_scale()
    normalization_records: list[dict[str, object]] = []

    for output_stem, source_stem, label in POSES:
        with Image.open(SOURCE_1024 / f"{output_stem}_alpha.png") as source:
            frame, record = place_complete_drawing(source, scale)
        save_png(frame, NORMALIZED / f"{output_stem}.png")
        normalization_records.append(
            {"name": output_stem, "source": source_stem, "label": label, **record}
        )

    (QA / "normalization-report.json").write_text(
        json.dumps(
            {
                "status": "PASS",
                "policy": "All raw built-in outputs are uniformly resized to the 1024 production canvas, then one identical whole-drawing scale is used for every key. Only whole-sprite root translation aligns planted feet and baseline; no part transforms or per-frame scaling are used.",
                "target_visible_height": TARGET_VISIBLE_HEIGHT,
                "uniform_whole_drawing_scale": round(scale, 6),
                "frames": normalization_records,
            },
            ensure_ascii=False,
            indent=2,
        ),
        encoding="utf-8",
    )

    with Image.open(REFERENCE) as source:
        reference_frame = source.convert("RGBA")
    reference_metrics = metrics(reference_frame)
    frame_reports: list[dict[str, object]] = []
    status = "PASS"
    tracked_limits = {
        "head_silhouette_width": 0.09,
        "face_color_bbox_width": 0.12,
        "face_color_bbox_height": 0.12,
        "hair_luma_median": 0.12,
        "navy_luma_median": 0.14,
        "leg_band_width_y385": 0.16,
        "sock_band_width_y425": 0.16,
        "shoe_band_width_y455": 0.16,
    }
    for output_stem, source_stem, label in POSES:
        with Image.open(NORMALIZED / f"{output_stem}.png") as source:
            value_metrics = metrics(source.convert("RGBA"))
        deltas = {
            key: relative_delta(value_metrics.get(key), reference_metrics.get(key))
            for key in tracked_limits
        }
        violations = [
            {"metric": key, "delta": delta, "limit": tracked_limits[key]}
            for key, delta in deltas.items()
            if delta is not None and delta > tracked_limits[key]
        ]
        if violations:
            status = "FAIL"
        frame_reports.append(
            {
                "name": output_stem,
                "source": source_stem,
                "label": label,
                "metrics": value_metrics,
                "relative_delta_vs_approved_idle": deltas,
                "violations": violations,
            }
        )
    (QA / "local-identity-report.json").write_text(
        json.dumps(
            {
                "status": status,
                "reference": str(REFERENCE.relative_to(ROOT.parent.parent)),
                "reference_metrics": reference_metrics,
                "limits": tracked_limits,
                "frames": frame_reports,
                "semantic_note": "Numeric proxies cannot approve facial identity, anatomy, accessory topology, motion intent or material quality. Inspect both review sheets before user acceptance.",
            },
            ensure_ascii=False,
            indent=2,
        ),
        encoding="utf-8",
    )


def checkerboard(size: tuple[int, int], tile: int = 16) -> Image.Image:
    image = Image.new("RGBA", size, (58, 61, 68, 255))
    draw = ImageDraw.Draw(image)
    colors = ((58, 61, 68, 255), (44, 47, 53, 255))
    for y in range(0, size[1], tile):
        for x in range(0, size[0], tile):
            draw.rectangle(
                (x, y, min(x + tile - 1, size[0] - 1), min(y + tile - 1, size[1] - 1)),
                fill=colors[((x // tile) + (y // tile)) % 2],
            )
    return image


def font(size: int) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    candidates = [
        Path("C:/Windows/Fonts/msyh.ttc"),
        Path("C:/Windows/Fonts/segoeui.ttf"),
    ]
    for path in candidates:
        if path.exists():
            return ImageFont.truetype(str(path), size)
    return ImageFont.load_default()


def build_review_sheets() -> None:
    entries: list[tuple[str, str, Path]] = [
        ("auth_start", "AUTH  中性起点", REFERENCE),
        *[
            (output_stem, label, NORMALIZED / f"{output_stem}.png")
            for output_stem, _, label in POSES
        ],
        ("auth_return", "AUTH  中性终点", REFERENCE),
    ]
    qa_frames = QA / "frames"
    qa_frames.mkdir(parents=True, exist_ok=True)
    for index, (_, _, path) in enumerate(entries):
        with Image.open(path) as source:
            save_png(source.convert("RGBA"), qa_frames / f"frame_{index:03d}.png")
    panel_w = 512
    label_h = 56
    sheet = checkerboard((panel_w * len(entries), 512 + label_h))
    draw = ImageDraw.Draw(sheet)
    label_font = font(20)
    small_font = font(15)
    for index, (_, label, path) in enumerate(entries):
        with Image.open(path) as source:
            frame = source.convert("RGBA")
        x = index * panel_w
        sheet.alpha_composite(frame, (x, label_h))
        draw.line((x + PIVOT_X, label_h, x + PIVOT_X, label_h + 512), fill=(92, 197, 255, 95), width=1)
        draw.line((x, label_h + TARGET_BASELINE, x + 511, label_h + TARGET_BASELINE), fill=(108, 237, 170, 150), width=2)
        draw.text((x + 14, 8), label, fill=(250, 250, 250, 255), font=label_font)
        draw.text((x + 14, 34), "蓝线=pivot  绿线=baseline", fill=(190, 203, 214, 255), font=small_font)
    save_png(sheet, KEYS / "head_pat_accept-key-contact-sheet-v2.png")

    crop_box = (118, 10, 394, 285)
    close_panel = 552
    close_label = 50
    close = checkerboard((close_panel * len(entries), 550 + close_label), tile=20)
    close_draw = ImageDraw.Draw(close)
    for index, (_, label, path) in enumerate(entries):
        with Image.open(path) as source:
            frame = source.convert("RGBA")
        crop = frame.crop(crop_box).resize((550, 550), Image.Resampling.LANCZOS)
        x = index * close_panel
        close.alpha_composite(crop, (x, close_label))
        close_draw.text((x + 14, 10), label, fill=(250, 250, 250, 255), font=label_font)
    save_png(close, KEYS / "head_pat_accept-key-identity-closeup-v2.png")


def main() -> None:
    standardize_sources()
    normalize_and_report()
    build_review_sheets()


if __name__ == "__main__":
    main()
