from __future__ import annotations

import argparse
import json
import statistics
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parent
SOURCES = ROOT / "key-sources"
KEYS = ROOT / "key-poses"
QA = ROOT / "key-qa"
REFERENCE = ROOT.parent / "return_wave" / "frames" / "frame_000.png"
TARGET_BASELINE = 472
TARGET_VISIBLE_HEIGHT = 453
KEYS_SPEC = [
    ("k03_notice", "K03 察觉触碰"),
    ("k06_avoid", "K06 避头抬手"),
    ("k09_block_peak", "K09 帽檐侧阻止"),
    ("k12_lower", "K12 放下恢复"),
]


def save_png(image: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path, format="PNG", optimize=True)


def alpha_bbox(image: Image.Image) -> tuple[int, int, int, int]:
    bbox = image.getchannel("A").point(lambda v: 255 if v >= 8 else 0).getbbox()
    if bbox is None:
        raise ValueError("image has no visible alpha bounds")
    return bbox


def standardize_sources() -> None:
    """Resize every complete built-in output uniformly to the declared 1024 cell."""
    for stem, _ in KEYS_SPEC:
        path = SOURCES / f"{stem}_chroma.png"
        with Image.open(path) as source:
            rgb = source.convert("RGB")
            if rgb.size != (1024, 1024):
                rgb = rgb.resize((1024, 1024), Image.Resampling.LANCZOS)
            save_png(rgb, path)


def _smoothstep(value: float) -> float:
    value = max(0.0, min(1.0, value))
    return value * value * (3.0 - 2.0 * value)


def remove_magenta_key() -> None:
    """Remove magenta with a two-channel matte that preserves warm skin and hair.

    The generic helper treats red as the only dominant channel when generated
    magenta is not perfectly balanced; that can mistake skin and ash hair for
    spill. Here both red *and* blue must dominate green before alpha is reduced.
    """
    records: list[dict[str, object]] = []
    for stem, _ in KEYS_SPEC:
        source_path = SOURCES / f"{stem}_chroma.png"
        output_path = SOURCES / f"{stem}_alpha.png"
        with Image.open(source_path) as source:
            rgb = source.convert("RGB")
        width, height = rgb.size
        border: list[tuple[int, int, int]] = []
        step = 4
        for x in range(0, width, step):
            border.append(rgb.getpixel((x, 0)))
            border.append(rgb.getpixel((x, height - 1)))
        for y in range(0, height, step):
            border.append(rgb.getpixel((0, y)))
            border.append(rgb.getpixel((width - 1, y)))
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
                    alpha = round(255.0 * _smoothstep(ratio))
                if alpha <= 8:
                    dst[x, y] = (0, 0, 0, 0)
                    transparent += 1
                    continue
                if alpha < 255:
                    partial += 1
                    fraction = alpha / 255.0
                    # Unmix the sampled key from antialiased boundary pixels.
                    red = round((red - (1.0 - fraction) * key[0]) / fraction)
                    green = round((green - (1.0 - fraction) * key[1]) / fraction)
                    blue = round((blue - (1.0 - fraction) * key[2]) / fraction)
                    red = max(0, min(255, red))
                    green = max(0, min(255, green))
                    blue = max(0, min(255, blue))
                dst[x, y] = (red, green, blue, alpha)
        save_png(rgba, output_path)
        records.append(
            {
                "name": stem,
                "sampled_key_rgb": list(key),
                "transparent_pixels": transparent,
                "partially_transparent_pixels": partial,
                "total_pixels": width * height,
                "matte": "two-channel magenta dominance; opaque<=45, transparent>=120",
            }
        )
    QA.mkdir(parents=True, exist_ok=True)
    (QA / "key-removal-report.json").write_text(
        json.dumps({"status": "PASS", "frames": records}, indent=2), encoding="utf-8"
    )


def normalize_alpha() -> None:
    """Apply one shared scale and whole-frame pivot translation to every key."""
    raw: dict[str, Image.Image] = {}
    half_heights: list[int] = []
    for stem, _ in KEYS_SPEC:
        path = SOURCES / f"{stem}_alpha.png"
        with Image.open(path) as source:
            rgba = source.convert("RGBA")
            if rgba.size != (1024, 1024):
                raise ValueError(f"{path.name} must be 1024x1024, got {rgba.size}")
            raw[stem] = rgba.copy()
            half = rgba.resize((512, 512), Image.Resampling.LANCZOS)
            box = alpha_bbox(half)
            half_heights.append(box[3] - box[1])

    shared_scale = TARGET_VISIBLE_HEIGHT / statistics.median(half_heights)
    if not 0.95 <= shared_scale <= 1.08:
        raise ValueError(f"unexpected shared scale {shared_scale:.4f}")

    records: list[dict[str, object]] = []
    for stem, label in KEYS_SPEC:
        source = raw[stem]
        scaled_size = round(512 * shared_scale)
        reduced = source.resize((scaled_size, scaled_size), Image.Resampling.LANCZOS)
        stage = Image.new("RGBA", (512, 512), (0, 0, 0, 0))
        inset = (512 - scaled_size) // 2
        stage.alpha_composite(reduced, (inset, inset))

        box = alpha_bbox(stage)
        center_x = (box[0] + box[2] - 1) / 2.0
        visible_bottom = box[3] - 1
        dx = round(256 - center_x)
        dy = TARGET_BASELINE - visible_bottom
        canvas = Image.new("RGBA", (512, 512), (0, 0, 0, 0))
        canvas.alpha_composite(stage, (dx, dy))
        final_box = alpha_bbox(canvas)
        if final_box[0] <= 0 or final_box[1] <= 0 or final_box[2] >= 512 or final_box[3] >= 512:
            raise ValueError(f"{stem} touches the fixed cell boundary: {final_box}")
        save_png(canvas, KEYS / f"{stem}.png")
        records.append(
            {
                "name": stem,
                "label": label,
                "source_size": [1024, 1024],
                "final_size": [512, 512],
                "shared_whole_drawing_scale": round(shared_scale, 6),
                "whole_sprite_translation": [dx, dy],
                "alpha_bbox": list(final_box),
                "visible_height": final_box[3] - final_box[1],
                "visible_baseline_y": final_box[3] - 1,
                "pivot": [256, 492],
            }
        )

    QA.mkdir(parents=True, exist_ok=True)
    (QA / "normalization-report.json").write_text(
        json.dumps(
            {
                "status": "PASS",
                "shared_scale_source": "median key height to approved standing height",
                "target_visible_height": TARGET_VISIBLE_HEIGHT,
                "target_baseline_y": TARGET_BASELINE,
                "frames": records,
            },
            indent=2,
            ensure_ascii=False,
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
    path = Path("C:/Windows/Fonts/msyh.ttc")
    return ImageFont.truetype(str(path), size) if path.exists() else ImageFont.load_default()


def build_contact_sheets() -> None:
    QA.mkdir(parents=True, exist_ok=True)
    panels: list[tuple[str, Path]] = [("比例参照", REFERENCE)] + [
        (label, KEYS / f"{stem}.png") for stem, label in KEYS_SPEC
    ]
    label_height = 52
    sheet = checkerboard((512 * len(panels), 512 + label_height))
    draw = ImageDraw.Draw(sheet)
    label_font = font(20)
    for index, (label, path) in enumerate(panels):
        with Image.open(path) as source:
            frame = source.convert("RGBA")
        x = index * 512
        sheet.alpha_composite(frame, (x, label_height))
        draw.text((x + 14, 13), label, fill=(245, 245, 245, 255), font=label_font)
        draw.line((x + 8, label_height + TARGET_BASELINE, x + 504, label_height + TARGET_BASELINE), fill=(54, 210, 150, 180), width=1)
    save_png(sheet, QA / "head_pat_refuse-key-contact-sheet.png")

    crop_box = (120, 20, 392, 330)
    closeup = checkerboard(((crop_box[2] - crop_box[0]) * len(panels), crop_box[3] - crop_box[1] + label_height), 12)
    close_draw = ImageDraw.Draw(closeup)
    for index, (label, path) in enumerate(panels):
        with Image.open(path) as source:
            frame = source.convert("RGBA").crop(crop_box)
        x = index * frame.width
        closeup.alpha_composite(frame, (x, label_height))
        close_draw.text((x + 10, 13), label, fill=(245, 245, 245, 255), font=label_font)
    save_png(closeup, QA / "head_pat_refuse-key-closeups.png")


def run_key_qa() -> None:
    with Image.open(REFERENCE) as ref_source:
        reference = ref_source.convert("RGBA")
    ref_box = alpha_bbox(reference)
    ref_height = ref_box[3] - ref_box[1]
    ref_width = ref_box[2] - ref_box[0]
    results: list[dict[str, object]] = []
    failures: list[str] = []
    for stem, label in KEYS_SPEC:
        path = KEYS / f"{stem}.png"
        with Image.open(path) as source:
            image = source.convert("RGBA")
        box = alpha_bbox(image)
        width = box[2] - box[0]
        height = box[3] - box[1]
        alpha = image.getchannel("A")
        coverage = sum(1 for value in alpha.getdata() if value >= 8) / (512 * 512)
        frame_failures: list[str] = []
        if image.size != (512, 512):
            frame_failures.append("dimensions")
        if box[3] - 1 != TARGET_BASELINE:
            frame_failures.append("baseline")
        if not 0.88 <= height / ref_height <= 1.12:
            frame_failures.append("visible_height")
        if not 0.75 <= width / ref_width <= 1.60:
            frame_failures.append("visible_width")
        if not 0.13 <= coverage <= 0.44:
            frame_failures.append("alpha_coverage")
        if any(image.getpixel(point)[3] != 0 for point in ((0, 0), (511, 0), (0, 511), (511, 511))):
            frame_failures.append("transparent_corners")
        if frame_failures:
            failures.append(f"{stem}: {', '.join(frame_failures)}")
        results.append(
            {
                "name": stem,
                "label": label,
                "alpha_bbox": list(box),
                "visible_width": width,
                "visible_height": height,
                "width_ratio_vs_reference": round(width / ref_width, 4),
                "height_ratio_vs_reference": round(height / ref_height, 4),
                "alpha_coverage": round(coverage, 6),
                "baseline_y": box[3] - 1,
                "failures": frame_failures,
            }
        )
    report = {
        "status": "PASS" if not failures else "FAIL",
        "scope": "preliminary sparse-key structural and standing-scale gate; user semantic review remains mandatory",
        "reference": str(REFERENCE.relative_to(ROOT.parent)),
        "reference_bbox": list(ref_box),
        "frames": results,
        "failures": failures,
    }
    (QA / "key-qa-report.json").write_text(
        json.dumps(report, indent=2, ensure_ascii=False), encoding="utf-8"
    )
    if failures:
        raise SystemExit("; ".join(failures))


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("stage", choices=("standardize", "key", "normalize", "contact", "qa", "finish"))
    args = parser.parse_args()
    if args.stage == "standardize":
        standardize_sources()
    elif args.stage == "key":
        remove_magenta_key()
    elif args.stage == "normalize":
        normalize_alpha()
    elif args.stage == "contact":
        build_contact_sheets()
    elif args.stage == "qa":
        run_key_qa()
    elif args.stage == "finish":
        normalize_alpha()
        build_contact_sheets()
        run_key_qa()


if __name__ == "__main__":
    main()
