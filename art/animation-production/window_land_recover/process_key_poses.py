from __future__ import annotations

import argparse
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont


ROOT = Path(__file__).resolve().parent
SOURCES = ROOT / "key-sources"
CHROMA = ROOT / "key-chroma"
RAW_ALPHA = ROOT / "key-alpha-raw"
ALPHA = ROOT / "key-alpha"
TEMPORAL = ROOT / "key-temporal"
POSES = ROOT / "key-poses"
QA = ROOT / "key-qa"
KEYS = [
    (0, "K00 slight descent", "k00_descent_chroma.png", 888),
    (3, "K03 first sole contact", "k03_contact_chroma.png", 944),
    (6, "K06 deepest absorption", "k06_absorb_chroma.png", 944),
    (10, "K10 stabilized rise", "k10_stabilize_chroma.png", 944),
    (14, "K14 recovered standing", "k14_recovered_chroma.png", 944),
]
ALPHA_THRESHOLD = 8
TARGET_HEAD_CENTER_X = 512.0
FINAL_PIVOT = [256, 492]


def _existing_keys() -> list[tuple[int, str, str, int]]:
    return [entry for entry in KEYS if (SOURCES / entry[2]).exists()]


def _save_png(image: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path, format="PNG", optimize=True)


def _binary_bbox(image: Image.Image) -> tuple[int, int, int, int]:
    bbox = image.getchannel("A").point(
        lambda value: 255 if value >= ALPHA_THRESHOLD else 0
    ).getbbox()
    if bbox is None:
        raise ValueError("image has no visible alpha bounds")
    return bbox


def _head_bbox(
    image: Image.Image, visible_bbox: tuple[int, int, int, int]
) -> tuple[int, int, int, int]:
    top = visible_bbox[1]
    # Keep the local head band above the shoulders even in a crouched pose.
    # A taller generic band would incorrectly count the balancing sleeve as
    # face/head width and would hide the very drift this gate is meant to catch.
    head_band_height = round(image.height * 225 / 1024)
    bottom = min(visible_bbox[3], top + head_band_height)
    crop = image.getchannel("A").crop((0, top, image.width, bottom))
    local = crop.point(lambda value: 255 if value >= ALPHA_THRESHOLD else 0).getbbox()
    if local is None:
        raise ValueError("head band has no visible alpha")
    return local[0], top + local[1], local[2], top + local[3]


def standardize_sources() -> None:
    CHROMA.mkdir(parents=True, exist_ok=True)
    for _, _, filename, _ in _existing_keys():
        with Image.open(SOURCES / filename) as source:
            rgb = source.convert("RGB")
            if rgb.size != (1024, 1024):
                rgb = rgb.resize((1024, 1024), Image.Resampling.LANCZOS)
            _save_png(rgb, CHROMA / filename)


def _remove_magenta_background(rgb: Image.Image) -> Image.Image:
    rgba = Image.new("RGBA", rgb.size, (0, 0, 0, 0))
    source_pixels = rgb.load()
    target_pixels = rgba.load()
    for y in range(rgb.height):
        for x in range(rgb.width):
            red, green, blue = source_pixels[x, y]
            dominance = min(red, blue) - green
            if red < 180 or blue < 140 or green >= 120 or dominance <= 90:
                alpha = 255
            elif dominance >= 150 and green <= 85:
                alpha = 0
            else:
                ratio = max(0.0, min(1.0, (dominance - 90.0) / 60.0))
                smooth = ratio * ratio * (3.0 - 2.0 * ratio)
                alpha = round(255.0 * (1.0 - smooth))
            target_pixels[x, y] = (red, green, blue, alpha)

    alpha_channel = rgba.getchannel("A").filter(ImageFilter.MinFilter(3))
    rgba.putalpha(alpha_channel)
    pixels = rgba.load()
    for y in range(rgba.height):
        for x in range(rgba.width):
            red, green, blue, alpha = pixels[x, y]
            if alpha == 0:
                pixels[x, y] = (0, 0, 0, 0)
            elif alpha < 255:
                # Restrained two-channel despill on edge pixels only. Interior
                # skin, hair, ribbon and fabric RGB remain bit-for-bit intact.
                edge_cap = max(green + 42, 0)
                pixels[x, y] = (
                    min(red, edge_cap),
                    green,
                    min(blue, edge_cap),
                    alpha,
                )
    return rgba


def remove_backgrounds() -> None:
    RAW_ALPHA.mkdir(parents=True, exist_ok=True)
    for _, _, filename, _ in _existing_keys():
        output = RAW_ALPHA / filename.replace("_chroma.png", "_alpha.png")
        with Image.open(CHROMA / filename) as source:
            rgb = source.convert("RGB")
        _save_png(_remove_magenta_background(rgb), output)


def normalize_complete_drawings() -> None:
    entries = _existing_keys()
    if not entries:
        raise ValueError("no selected key sources")
    recovered_path = RAW_ALPHA / "k14_recovered_alpha.png"
    if not recovered_path.exists():
        raise ValueError("K14 recovered standing is required as the key pixel-scale authority")

    with Image.open(recovered_path) as source:
        recovered = source.convert("RGBA")
    recovered_bbox = _binary_bbox(recovered)
    recovered_head_bbox = _head_bbox(recovered, recovered_bbox)
    target_head_width = recovered_head_bbox[2] - recovered_head_bbox[0]

    records: list[dict[str, object]] = []
    for index, label, filename, target_bottom in entries:
        alpha_name = filename.replace("_chroma.png", "_alpha.png")
        with Image.open(RAW_ALPHA / alpha_name) as source:
            rgba = source.convert("RGBA")
        if rgba.size != (1024, 1024):
            raise ValueError(f"{alpha_name} must be 1024x1024, got {rgba.size}")

        source_bbox = _binary_bbox(rgba)
        source_head_bbox = _head_bbox(rgba, source_bbox)
        source_head_width = source_head_bbox[2] - source_head_bbox[0]
        scale = target_head_width / source_head_width
        if not 0.82 <= scale <= 1.24:
            raise ValueError(f"{alpha_name} requires unsafe whole-drawing scale {scale:.4f}")

        scaled_side = round(1024 * scale)
        scaled = rgba.resize((scaled_side, scaled_side), Image.Resampling.LANCZOS)
        scaled_bbox = _binary_bbox(scaled)
        scaled_head_bbox = _head_bbox(scaled, scaled_bbox)
        head_center_x = (scaled_head_bbox[0] + scaled_head_bbox[2] - 1) / 2.0
        dx = round(TARGET_HEAD_CENTER_X - head_center_x)
        dy = target_bottom - (scaled_bbox[3] - 1)

        normalized = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
        normalized.alpha_composite(scaled, (dx, dy))
        final_bbox = _binary_bbox(normalized)
        final_head_bbox = _head_bbox(normalized, final_bbox)
        output_stem = filename.replace("_chroma.png", "")
        _save_png(normalized, ALPHA / f"{output_stem}_alpha.png")

        magenta = Image.new("RGBA", (1024, 1024), (255, 0, 255, 255))
        magenta.alpha_composite(normalized)
        _save_png(magenta.convert("RGB"), TEMPORAL / f"{output_stem}_chroma.png")

        reduced = normalized.resize((512, 512), Image.Resampling.LANCZOS)
        _save_png(reduced, POSES / f"k{index:02d}.png")
        reduced_bbox = _binary_bbox(reduced)
        reduced_head_bbox = _head_bbox(reduced, reduced_bbox)
        records.append(
            {
                "index": index,
                "label": label,
                "source_file": f"key-sources/{filename}",
                "source_canvas": [1024, 1024],
                "whole_drawing_scale": round(scale, 8),
                "whole_drawing_translation": [dx, dy],
                "target_visible_bottom_1024": target_bottom,
                "normalized_bbox_1024": list(final_bbox),
                "normalized_head_bbox_1024": list(final_head_bbox),
                "final_bbox_512": list(reduced_bbox),
                "final_head_bbox_512": list(reduced_head_bbox),
                "final_pivot": FINAL_PIVOT,
            }
        )

    head_widths = [
        record["final_head_bbox_512"][2] - record["final_head_bbox_512"][0]
        for record in records
    ]
    report = {
        "status": "PASS" if max(head_widths) - min(head_widths) <= 4 else "FAIL",
        "target_head_width_1024": target_head_width,
        "head_width_range_512": max(head_widths) - min(head_widths),
        "complete_drawing_only": True,
        "local_part_operations": False,
        "frames": records,
    }
    QA.mkdir(parents=True, exist_ok=True)
    (QA / "normalization-report.json").write_text(
        json.dumps(report, indent=2), encoding="utf-8"
    )
    if report["status"] != "PASS":
        raise SystemExit(2)


def _checkerboard(size: tuple[int, int], tile: int = 16) -> Image.Image:
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


def build_contact_sheet() -> None:
    entries = _existing_keys()
    columns = 3
    rows = (len(entries) + columns - 1) // columns
    label_height = 54
    panel_height = 512 + label_height
    sheet = _checkerboard((512 * columns, panel_height * rows))
    draw = ImageDraw.Draw(sheet)
    font_path = Path(r"C:\Windows\Fonts\segoeui.ttf")
    font = ImageFont.truetype(str(font_path), 21) if font_path.exists() else ImageFont.load_default()
    small = ImageFont.truetype(str(font_path), 17) if font_path.exists() else ImageFont.load_default()

    for panel, (index, label, _, target_bottom) in enumerate(entries):
        with Image.open(POSES / f"k{index:02d}.png") as source:
            frame = source.convert("RGBA")
        x = (panel % columns) * 512
        y = (panel // columns) * panel_height
        sheet.alpha_composite(frame, (x, y + label_height))
        draw.text((x + 14, y + 8), label, fill=(245, 245, 245, 255), font=font)
        contact = "airborne / no contact" if index == 0 else "both soles / invisible edge"
        draw.text((x + 14, y + 32), contact, fill=(194, 203, 214, 255), font=small)
        if index != 0:
            guide_y = y + label_height + round(target_bottom / 2)
            draw.line((x + 80, guide_y, x + 432, guide_y), fill=(95, 210, 255, 180), width=1)

    _save_png(sheet, POSES / "window_land_recover-key-contact-sheet.png")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "stage", choices=("standardize", "key", "normalize", "contact", "all")
    )
    args = parser.parse_args()
    if args.stage in ("standardize", "all"):
        standardize_sources()
    if args.stage in ("key", "all"):
        remove_backgrounds()
    if args.stage in ("normalize", "all"):
        normalize_complete_drawings()
    if args.stage in ("contact", "all"):
        build_contact_sheet()


if __name__ == "__main__":
    main()
