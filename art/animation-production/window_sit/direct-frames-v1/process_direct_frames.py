from __future__ import annotations

import argparse
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parent
ACTION = ROOT.parent
PROJECT = ACTION.parents[2]
ALPHA = ROOT / "alpha-1254"
FRAMES = ROOT / "frames"
QA = ROOT / "qa"
KEYS = ACTION / "key-poses" / "normalized"
TARGET_SIZE = (512, 512)
TARGET_HEAD_CENTER_X = 256
TARGET_VISIBLE_BOTTOM = 472
FRAME_COUNT = 32

KEY_SOURCES = {
    0: KEYS / "k00_stand.png",
    4: KEYS / "k04_descent.png",
    8: KEYS / "k08_stable_window_seat.png",
    12: KEYS / "k12_leg_swing.png",
    19: KEYS / "k19_side_lean.png",
    27: KEYS / "k27_rise_load.png",
    31: KEYS / "k31_stand_return.png",
}
DIRECT_INDICES = [1, 2, 3, 5, 6, 7, 9, 10, 11, 13, 14, 15, 16, 17, 18, 20, 21, 22, 23, 24, 25, 26, 28, 29, 30]


def alpha_bbox(image: Image.Image) -> tuple[int, int, int, int]:
    bbox = image.getchannel("A").point(lambda value: 255 if value >= 16 else 0).getbbox()
    if bbox is None:
        raise ValueError("empty alpha image")
    return bbox


def head_center_x(image: Image.Image) -> float:
    alpha = image.getchannel("A")
    left, top, right, bottom = alpha_bbox(image)
    band_bottom = min(bottom, top + 128)
    band = alpha.crop((0, top, image.width, band_bottom)).getbbox()
    if band is None:
        return (left + right) / 2.0
    return (band[0] + band[2]) / 2.0


def normalize_direct(index: int, source: Path) -> dict:
    image = Image.open(source).convert("RGBA")
    source_size = image.size
    if image.size != TARGET_SIZE:
        image = image.resize(TARGET_SIZE, Image.Resampling.LANCZOS)
    before = alpha_bbox(image)
    dx = round(TARGET_HEAD_CENTER_X - head_center_x(image))
    dy = TARGET_VISIBLE_BOTTOM - (before[3] - 1)
    normalized = Image.new("RGBA", TARGET_SIZE, (0, 0, 0, 0))
    normalized.alpha_composite(image, (dx, dy))
    after = alpha_bbox(normalized)
    normalized.save(FRAMES / f"frame_{index:03d}.png", optimize=True)
    return {
        "index": index,
        "kind": "direct",
        "source": str(source.relative_to(PROJECT)).replace("\\", "/"),
        "source_size": list(source_size),
        "bbox_before_translation": list(before),
        "translation": [dx, dy],
        "bbox_final": list(after),
        "head_center_final": round(head_center_x(normalized), 3),
        "visible_bottom_final": after[3] - 1,
    }


def copy_key(index: int, source: Path) -> dict:
    image = Image.open(source).convert("RGBA")
    if image.size != TARGET_SIZE:
        raise ValueError(f"key frame {index} is not 512x512")
    destination = FRAMES / f"frame_{index:03d}.png"
    image.save(destination, optimize=True)
    bbox = alpha_bbox(image)
    return {
        "index": index,
        "kind": "approved_key",
        "source": str(source.relative_to(PROJECT)).replace("\\", "/"),
        "source_size": list(image.size),
        "translation": [0, 0],
        "bbox_final": list(bbox),
        "head_center_final": round(head_center_x(image), 3),
        "visible_bottom_final": bbox[3] - 1,
    }


def support_y(index: int) -> int:
    if index <= 4:
        return 472
    if index == 5:
        return 440
    if index == 6:
        return 400
    if index == 7:
        return 365
    if 8 <= index <= 24:
        return 350
    if index == 25:
        return 385
    if index == 26:
        return 430
    return 472


def load_font(size: int) -> ImageFont.ImageFont:
    for candidate in (Path("C:/Windows/Fonts/msyh.ttc"), Path("C:/Windows/Fonts/segoeui.ttf")):
        if candidate.exists():
            return ImageFont.truetype(str(candidate), size=size)
    return ImageFont.load_default()


def dashed_line(draw: ImageDraw.ImageDraw, x0: int, y: int, x1: int) -> None:
    x = x0
    while x < x1:
        draw.line((x, y, min(x + 7, x1), y), fill=(22, 174, 196), width=2)
        x += 12


def make_contact_sheet() -> None:
    preview = 156
    label_h = 24
    padding = 6
    columns = 8
    rows = 4
    cell_w = preview + padding * 2
    cell_h = preview + label_h + padding * 2
    sheet = Image.new("RGB", (columns * cell_w, rows * cell_h), (236, 236, 241))
    draw = ImageDraw.Draw(sheet)
    label_font = load_font(15)
    for index in range(FRAME_COUNT):
        image = Image.open(FRAMES / f"frame_{index:03d}.png").convert("RGBA")
        thumb = image.resize((preview, preview), Image.Resampling.LANCZOS)
        panel = Image.new("RGBA", (preview, preview), (249, 249, 251, 255))
        panel.alpha_composite(thumb)
        col = index % columns
        row = index // columns
        x = col * cell_w + padding
        y = row * cell_h + padding
        sheet.paste(panel.convert("RGB"), (x, y))
        guide_y = y + round(support_y(index) / 512 * preview)
        dashed_line(draw, x + 3, guide_y, x + preview - 3)
        draw.rectangle((x, y, x + preview - 1, y + preview - 1), outline=(182, 184, 192), width=1)
        role = "K" if index in KEY_SOURCES else "F"
        draw.text((x + 4, y + preview + 4), f"{role}{index:02d}", fill=(28, 30, 38), font=label_font)
    sheet.save(QA / "window_sit-full-contact-sheet.png", optimize=True)


def save_gif(path: Path, duration_ms: int) -> None:
    images = [Image.open(FRAMES / f"frame_{index:03d}.png").convert("RGBA") for index in range(FRAME_COUNT)]
    durations = [500] + [duration_ms] * (FRAME_COUNT - 2) + [500]
    images[0].save(
        path,
        save_all=True,
        append_images=images[1:],
        duration=durations,
        loop=0,
        disposal=2,
        optimize=False,
    )


def save_world_contact_gif(path: Path, duration_ms: int) -> None:
    canvas_size = (640, 640)
    fixed_support_y = 512
    images: list[Image.Image] = []
    for index in range(FRAME_COUNT):
        frame = Image.open(FRAMES / f"frame_{index:03d}.png").convert("RGBA")
        canvas = Image.new("RGBA", canvas_size, (244, 244, 247, 255))
        canvas.alpha_composite(frame, (64, fixed_support_y - support_y(index)))
        draw = ImageDraw.Draw(canvas)
        dashed_line(draw, 12, fixed_support_y, canvas_size[0] - 12)
        images.append(canvas)
    durations = [500] + [duration_ms] * (FRAME_COUNT - 2) + [500]
    images[0].save(
        path,
        save_all=True,
        append_images=images[1:],
        duration=durations,
        loop=0,
        disposal=2,
        optimize=False,
    )


def save_support_contact_curve() -> None:
    records = []
    for index in range(FRAME_COUNT):
        if index <= 4:
            owner = "both_shoe_soles"
        elif index <= 7:
            owner = "transfer_feet_to_pelvis"
        elif index <= 24:
            owner = "seated_pelvis_skirt_compression"
        elif index <= 26:
            owner = "transfer_pelvis_to_feet"
        else:
            owner = "both_shoe_soles"
        records.append(
            {
                "index": index,
                "support_x": 256,
                "support_y": support_y(index),
                "owner": owner,
            }
        )
    (QA / "support-contact-curve.json").write_text(
        json.dumps(
            {
                "action": "window_sit",
                "coordinate_space": "normalized_512x512_cell",
                "platform_visible": False,
                "records": records,
            },
            ensure_ascii=False,
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--require-complete", action="store_true")
    args = parser.parse_args()
    FRAMES.mkdir(parents=True, exist_ok=True)
    QA.mkdir(parents=True, exist_ok=True)
    records: list[dict] = []
    for index, source in KEY_SOURCES.items():
        records.append(copy_key(index, source))
    available_direct: list[int] = []
    for index in DIRECT_INDICES:
        source = ALPHA / f"frame_{index:03d}.png"
        if not source.exists():
            continue
        records.append(normalize_direct(index, source))
        available_direct.append(index)
    missing = sorted(set(DIRECT_INDICES) - set(available_direct))
    records.sort(key=lambda item: int(item["index"]))
    status = "PASS" if not missing else "INCOMPLETE"
    (QA / "normalization-report.json").write_text(
        json.dumps(
            {
                "status": status,
                "method": "Uniform whole-canvas resize plus whole-frame head-center/baseline translation; no per-part operations.",
                "available_direct_indices": available_direct,
                "missing_direct_indices": missing,
                "records": records,
            },
            ensure_ascii=False,
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )
    if not missing:
        make_contact_sheet()
        save_gif(QA / "preview.gif", 167)
        save_gif(QA / "preview-slow.gif", 334)
        save_world_contact_gif(QA / "preview-world-contact.gif", 167)
        save_world_contact_gif(QA / "preview-world-contact-slow.gif", 334)
        save_support_contact_curve()
    if args.require_complete and missing:
        raise SystemExit(2)


if __name__ == "__main__":
    main()
