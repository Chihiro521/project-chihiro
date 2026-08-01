from __future__ import annotations

import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parent
PROJECT = ROOT.parents[3]
ALPHA = ROOT / "alpha-1024-v3"
NORMALIZED = ROOT / "normalized"
QA = ROOT / "qa"
TARGET_SIZE = (512, 512)
TARGET_BASELINE = 472
TARGET_HEAD_CENTER_X = 256

SOURCES = [
    ("k00_stand", PROJECT / "art/animation-production/return_wave/frames/frame_000.png"),
    ("k04_descent", ALPHA / "k04_descent_alpha.png"),
    ("k08_stable_window_seat", ALPHA / "k08_stable_window_seat_alpha.png"),
    ("k12_leg_swing", ALPHA / "k12_leg_swing_alpha.png"),
    ("k19_side_lean", ALPHA / "k19_side_lean_alpha.png"),
    ("k27_rise_load", ALPHA / "k27_rise_load_alpha.png"),
    ("k31_stand_return", PROJECT / "art/animation-production/return_wave/frames/frame_000.png"),
]

LABELS = {
    "k00_stand": "K00 站立 / 双脚支撑",
    "k04_descent": "K04 下坐中段 / 双脚支撑",
    "k08_stable_window_seat": "K08 稳定窗沿坐姿母帧",
    "k12_leg_swing": "K12 小幅摆腿峰值",
    "k19_side_lean": "K19 侧倚观察",
    "k27_rise_load": "K27 起身受力",
    "k31_stand_return": "K31 回到站立",
}

SEATED_KEYS = {"k08_stable_window_seat", "k12_leg_swing", "k19_side_lean"}


def alpha_bbox(image: Image.Image) -> tuple[int, int, int, int]:
    bbox = image.getchannel("A").getbbox()
    if bbox is None:
        raise ValueError("empty alpha image")
    return bbox


def head_band_center_x(image: Image.Image) -> float:
    alpha = image.getchannel("A")
    left, top, right, bottom = alpha_bbox(image)
    band_bottom = min(bottom, top + max(1, int((bottom - top) * 0.30)))
    band_bbox = alpha.crop((0, top, image.width, band_bottom)).getbbox()
    if band_bbox is None:
        return (left + right) / 2.0
    return (band_bbox[0] + band_bbox[2]) / 2.0


def translate(image: Image.Image, dx: int, dy: int) -> Image.Image:
    result = Image.new("RGBA", TARGET_SIZE, (0, 0, 0, 0))
    result.alpha_composite(image, (dx, dy))
    return result


def normalize(name: str, source: Path) -> dict:
    image = Image.open(source).convert("RGBA")
    original_size = image.size
    if image.size != TARGET_SIZE:
        image = image.resize(TARGET_SIZE, Image.Resampling.LANCZOS)
    before = alpha_bbox(image)
    head_center_before = head_band_center_x(image)
    dx = round(TARGET_HEAD_CENTER_X - head_center_before)
    dy = TARGET_BASELINE - (before[3] - 1)
    image = translate(image, dx, dy)
    after = alpha_bbox(image)
    out_path = NORMALIZED / f"{name}.png"
    image.save(out_path, optimize=True)
    return {
        "name": name,
        "source": str(source.relative_to(PROJECT)).replace("\\", "/"),
        "source_size": list(original_size),
        "bbox_before_translation": list(before),
        "head_center_before_translation": round(head_center_before, 3),
        "translation": [dx, dy],
        "bbox_final": list(after),
        "visible_bottom_final": after[3] - 1,
        "head_center_final": round(head_band_center_x(image), 3),
    }


def font(size: int) -> ImageFont.ImageFont:
    candidates = [
        Path("C:/Windows/Fonts/msyh.ttc"),
        Path("C:/Windows/Fonts/segoeui.ttf"),
    ]
    for candidate in candidates:
        if candidate.exists():
            return ImageFont.truetype(str(candidate), size=size)
    return ImageFont.load_default()


def dashed_line(draw: ImageDraw.ImageDraw, xy: tuple[int, int, int, int], fill: tuple[int, int, int], width: int = 2) -> None:
    x0, y0, x1, _ = xy
    dash = 10
    gap = 7
    x = x0
    while x < x1:
        draw.line((x, y0, min(x + dash, x1), y0), fill=fill, width=width)
        x += dash + gap


def make_contact_sheet() -> None:
    preview_side = 300
    padding = 12
    label_h = 48
    title_h = 54
    cell_w = preview_side + padding * 2
    cell_h = preview_side + label_h + padding * 2
    columns = 4
    rows = 2
    sheet = Image.new("RGB", (cell_w * columns, title_h + cell_h * rows), (235, 235, 240))
    draw = ImageDraw.Draw(sheet)
    title_font = font(26)
    label_font = font(18)
    guide_font = font(14)
    draw.text((18, 11), "window_sit 稀疏关键姿势（青线仅为 QA 支撑点，不属于帧画面）", fill=(30, 32, 40), font=title_font)

    for index, (name, _) in enumerate(SOURCES):
        row = index // columns
        column = index % columns
        x0 = column * cell_w + padding
        y0 = title_h + row * cell_h + padding
        image = Image.open(NORMALIZED / f"{name}.png").convert("RGBA")
        preview = image.resize((preview_side, preview_side), Image.Resampling.LANCZOS)
        panel = Image.new("RGBA", (preview_side, preview_side), (248, 248, 250, 255))
        panel.alpha_composite(preview)
        sheet.paste(panel.convert("RGB"), (x0, y0))
        panel_draw = ImageDraw.Draw(sheet)
        contact_y = 350 if name in SEATED_KEYS else TARGET_BASELINE
        line_y = y0 + round(contact_y / 512 * preview_side)
        dashed_line(panel_draw, (x0 + 8, line_y, x0 + preview_side - 8, line_y), (26, 174, 196), width=2)
        panel_draw.text((x0 + 10, max(y0 + 4, line_y - 21)), "support", fill=(15, 120, 140), font=guide_font)
        panel_draw.rectangle((x0, y0, x0 + preview_side - 1, y0 + preview_side - 1), outline=(180, 182, 190), width=1)
        panel_draw.text((x0 + 4, y0 + preview_side + 8), LABELS[name], fill=(30, 32, 40), font=label_font)

    sheet.save(QA / "window_sit-key-contact-sheet.png", optimize=True)


def main() -> None:
    NORMALIZED.mkdir(parents=True, exist_ok=True)
    QA.mkdir(parents=True, exist_ok=True)
    report = [normalize(name, source) for name, source in SOURCES]
    (QA / "normalization-report.json").write_text(
        json.dumps(
            {
                "status": "PASS",
                "method": "uniform whole-canvas resize plus whole-frame translation only",
                "target_size": list(TARGET_SIZE),
                "target_head_center_x": TARGET_HEAD_CENTER_X,
                "target_visible_bottom": TARGET_BASELINE,
                "records": report,
            },
            ensure_ascii=False,
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )
    make_contact_sheet()


if __name__ == "__main__":
    main()
