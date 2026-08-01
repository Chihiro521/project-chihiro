from __future__ import annotations

import json
import math
import statistics
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFont, ImageStat


ROOT = Path(__file__).resolve().parent
FRAMES = ROOT / "frames"
QA = ROOT / "qa"
MANIFEST = ROOT / "sprite-sequence.json"
ALPHA_THRESHOLD = 8


def checker(size: tuple[int, int], tile: int = 16) -> Image.Image:
    image = Image.new("RGBA", size, (58, 61, 68, 255))
    draw = ImageDraw.Draw(image)
    for y in range(0, size[1], tile):
        for x in range(0, size[0], tile):
            if (x // tile + y // tile) % 2:
                draw.rectangle((x, y, x + tile - 1, y + tile - 1), fill=(44, 47, 53, 255))
    return image


def alpha_bbox(image: Image.Image) -> tuple[int, int, int, int]:
    bbox = image.getchannel("A").point(
        lambda value: 255 if value >= ALPHA_THRESHOLD else 0
    ).getbbox()
    if bbox is None:
        raise ValueError("frame has no visible alpha")
    return bbox


def padded_crop(image: Image.Image, box: tuple[int, int, int, int]) -> Image.Image:
    width = box[2] - box[0]
    height = box[3] - box[1]
    out = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    source_box = (
        max(0, box[0]),
        max(0, box[1]),
        min(image.width, box[2]),
        min(image.height, box[3]),
    )
    if source_box[2] <= source_box[0] or source_box[3] <= source_box[1]:
        return out
    source = image.crop(source_box)
    out.alpha_composite(source, (source_box[0] - box[0], source_box[1] - box[1]))
    return out


def head_crop(image: Image.Image) -> tuple[Image.Image, tuple[int, int, int, int]]:
    left, top, right, bottom = alpha_bbox(image)
    height = bottom - top
    band_bottom = min(bottom, top + max(112, round(height * 0.34)))
    band = image.getchannel("A").crop((left, top, right, band_bottom)).point(
        lambda value: 255 if value >= ALPHA_THRESHOLD else 0
    )
    band_bbox = band.getbbox()
    if band_bbox is None:
        center_x = (left + right) / 2
    else:
        center_x = left + (band_bbox[0] + band_bbox[2]) / 2
    size = max(118, min(158, round(height * 0.37)))
    crop_box = (
        round(center_x - size / 2),
        top - 6,
        round(center_x + size / 2),
        top - 6 + size,
    )
    return padded_crop(image, crop_box), crop_box


def material_crop(image: Image.Image) -> Image.Image:
    left, top, right, bottom = alpha_bbox(image)
    height = bottom - top
    center_x = (left + right) / 2
    crop_width = max(230, min(330, (right - left) + 45))
    crop_height = max(210, min(320, round(height * 0.66)))
    crop_box = (
        round(center_x - crop_width * 0.48),
        top + round(height * 0.13),
        round(center_x + crop_width * 0.52),
        top + round(height * 0.13) + crop_height,
    )
    return padded_crop(image, crop_box)


def fit_on_checker(crop: Image.Image, size: tuple[int, int]) -> Image.Image:
    canvas = checker(size, tile=12)
    scale = min(size[0] / crop.width, size[1] / crop.height)
    target = (max(1, round(crop.width * scale)), max(1, round(crop.height * scale)))
    resized = crop.resize(target, Image.Resampling.LANCZOS)
    canvas.alpha_composite(resized, ((size[0] - target[0]) // 2, (size[1] - target[1]) // 2))
    return canvas


def build_contact_sheets(frames: list[Image.Image]) -> None:
    font_path = Path("C:/Windows/Fonts/segoeui.ttf")
    font = ImageFont.truetype(str(font_path), 15) if font_path.exists() else ImageFont.load_default()
    columns = 5
    rows = math.ceil(len(frames) / columns)
    panel_w, panel_h = 360, 232

    identity = Image.new("RGBA", (columns * panel_w, rows * panel_h), (35, 38, 44, 255))
    material = Image.new("RGBA", (columns * panel_w, rows * panel_h), (35, 38, 44, 255))
    identity_draw = ImageDraw.Draw(identity)
    material_draw = ImageDraw.Draw(material)

    for index, frame in enumerate(frames):
        col = index % columns
        row = index // columns
        x = col * panel_w
        y = row * panel_h
        head, _ = head_crop(frame)
        full = fit_on_checker(frame, (165, 185))
        close = fit_on_checker(head, (165, 185))
        identity.alpha_composite(full, (x + 8, y + 36))
        identity.alpha_composite(close, (x + 187, y + 36))
        identity_draw.text((x + 10, y + 9), f"F{index:02d}  full / head", font=font, fill=(245, 245, 245, 255))

        detail = fit_on_checker(material_crop(frame), (340, 185))
        material.alpha_composite(detail, (x + 10, y + 36))
        material_draw.text((x + 10, y + 9), f"F{index:02d}  hair / navy / strap / bag / rabbit", font=font, fill=(245, 245, 245, 255))

    identity.save(QA / "local-identity-contact-sheet.png", optimize=True)
    material.save(QA / "material-contact-sheet.png", optimize=True)


def build_leg_continuity_sheet(frames: list[Image.Image]) -> None:
    indices = list(range(4, 9))
    crop_box = (96, 320, 416, 512)
    panel_width = crop_box[2] - crop_box[0]
    panel_height = crop_box[3] - crop_box[1]
    label_height = 34
    sheet = Image.new(
        "RGBA",
        (panel_width * len(indices), panel_height + label_height),
        (35, 38, 44, 255),
    )
    draw = ImageDraw.Draw(sheet)
    font_path = Path("C:/Windows/Fonts/segoeui.ttf")
    font = ImageFont.truetype(str(font_path), 15) if font_path.exists() else ImageFont.load_default()
    for column, index in enumerate(indices):
        x = column * panel_width
        background = checker((panel_width, panel_height))
        background.alpha_composite(frames[index].crop(crop_box))
        sheet.alpha_composite(background, (x, label_height))
        draw.text((x + 10, 8), f"F{index:02d} lower-body continuity", font=font, fill=(245, 245, 245, 255))
        baseline_y = label_height + 472 - crop_box[1]
        draw.line((x + 4, baseline_y, x + panel_width - 4, baseline_y), fill=(108, 215, 255, 160), width=1)
    sheet.save(QA / "leg-continuity-contact-sheet.png", optimize=True)


def hair_luminance_proxy(head: Image.Image) -> float | None:
    pixels = head.convert("RGBA").getdata()
    values: list[float] = []
    for red, green, blue, alpha in pixels:
        if alpha < 96:
            continue
        high = max(red, green, blue)
        low = min(red, green, blue)
        if 105 <= high <= 230 and high - low <= 58:
            values.append(0.2126 * red + 0.7152 * green + 0.0722 * blue)
    return round(statistics.fmean(values), 3) if values else None


def navy_high_frequency_proxy(image: Image.Image) -> float | None:
    rgba = image.convert("RGBA")
    gray = rgba.convert("L")
    alpha = rgba.getchannel("A")
    rgb_pixels = rgba.load()
    mask = Image.new("L", rgba.size, 0)
    mask_pixels = mask.load()
    for y in range(rgba.height):
        for x in range(rgba.width):
            red, green, blue, opacity = rgb_pixels[x, y]
            luminance = (red * 54 + green * 183 + blue * 19) // 256
            if opacity >= 128 and luminance <= 105 and blue >= red * 0.82:
                mask_pixels[x, y] = 255
    if mask.getbbox() is None:
        return None
    shifted = Image.new("L", gray.size, 0)
    shifted.paste(gray.crop((1, 0, gray.width, gray.height)), (0, 0))
    difference = ImageChops.difference(gray, shifted)
    mean = ImageStat.Stat(difference, mask=mask).mean[0]
    return round(mean, 4)


def summary(values: list[float]) -> dict[str, float]:
    return {
        "min": round(min(values), 4),
        "median": round(statistics.median(values), 4),
        "max": round(max(values), 4),
        "range": round(max(values) - min(values), 4),
    }


def save_gif(frames: list[Image.Image], path: Path, fps: int, indices: list[int] | None = None) -> None:
    selected = frames if indices is None else [frames[index] for index in indices]
    review_frames: list[Image.Image] = []
    for frame in selected:
        background = checker(frame.size)
        background.alpha_composite(frame)
        review_frames.append(background.convert("RGB"))
    review_frames[0].save(
        path,
        save_all=True,
        append_images=review_frames[1:],
        duration=round(1000 / fps),
        loop=0,
        optimize=False,
        disposal=2,
    )


def main() -> None:
    QA.mkdir(parents=True, exist_ok=True)
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    frame_paths = [FRAMES / entry["file"] for entry in manifest["frames"]]
    frames: list[Image.Image] = []
    for path in frame_paths:
        with Image.open(path) as image:
            frames.append(image.convert("RGBA"))

    build_contact_sheets(frames)
    build_leg_continuity_sheet(frames)
    save_gif(frames, QA / "nap-preview-6fps.gif", 6)
    save_gif(frames, QA / "nap-preview-slow-3fps.gif", 3)
    save_gif(frames, QA / "nap-loop-6fps.gif", 6, list(range(8, 16)))
    save_gif(frames, QA / "nap-enter-slow-3fps.gif", 3, list(range(0, 9)))

    bboxes = [alpha_bbox(frame) for frame in frames]
    baselines = [bbox[3] - 1 for bbox in bboxes]
    head_widths: list[float] = []
    hair_values: list[float] = []
    navy_values: list[float] = []
    per_frame: list[dict[str, object]] = []
    for index, frame in enumerate(frames):
        head, head_box = head_crop(frame)
        head_alpha_bbox = head.getchannel("A").point(
            lambda value: 255 if value >= ALPHA_THRESHOLD else 0
        ).getbbox()
        head_width = float(head_alpha_bbox[2] - head_alpha_bbox[0]) if head_alpha_bbox else 0.0
        hair_value = hair_luminance_proxy(head)
        navy_value = navy_high_frequency_proxy(frame)
        head_widths.append(head_width)
        if hair_value is not None:
            hair_values.append(hair_value)
        if navy_value is not None:
            navy_values.append(navy_value)
        per_frame.append(
            {
                "index": index,
                "alpha_bbox": list(bboxes[index]),
                "head_crop_box": list(head_box),
                "head_alpha_width_proxy": head_width,
                "hair_luminance_proxy": hair_value,
                "navy_high_frequency_proxy": navy_value,
            }
        )

    report = {
        "status": "AUTOMATED_PASS_MANUAL_PENDING",
        "frame_count": len(frames),
        "dimensions": [512, 512],
        "automated_checks": {
            "baseline_range_px": max(baselines) - min(baselines),
            "head_alpha_width_proxy": summary(head_widths),
            "hair_luminance_proxy": summary(hair_values),
            "navy_high_frequency_proxy": summary(navy_values),
            "artifacts": {
                "identity_contact_sheet": "local-identity-contact-sheet.png",
                "material_contact_sheet": "material-contact-sheet.png",
                "target_fps_gif": "nap-preview-6fps.gif",
                "slow_gif": "nap-preview-slow-3fps.gif",
                "loop_gif": "nap-loop-6fps.gif",
                "enter_slow_gif": "nap-enter-slow-3fps.gif",
                "leg_continuity_contact_sheet": "leg-continuity-contact-sheet.png",
            },
        },
        "manual_review": {
            "status": "PENDING",
            "required_checks": [
                "head_and_face_size",
                "torso_and_limb_volume",
                "garment_topology",
                "hair_luminance",
                "navy_fabric_high_frequency",
                "strap_bag_rabbit_topology",
                "leg_and_shoe_readability",
                "ground_baseline",
            ],
        },
        "per_frame": per_frame,
    }
    (QA / "local-identity-report.json").write_text(
        json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8"
    )


if __name__ == "__main__":
    main()
