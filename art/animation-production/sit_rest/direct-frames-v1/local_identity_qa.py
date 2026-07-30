from __future__ import annotations

import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parent
FRAMES = ROOT / "frames"
QA = ROOT / "qa"
GENERATED = (1, 2, 3, 5, 6, 7, 18, 23, 24)
AUTHORITIES = {1: 0, 2: 0, 3: 4, 5: 4, 6: 8, 7: 8, 18: 17, 23: 22, 24: 25}
ALPHA_THRESHOLD = 16


def alpha_bbox(image: Image.Image) -> tuple[int, int, int, int]:
    bbox = image.getchannel("A").point(lambda value: 255 if value >= ALPHA_THRESHOLD else 0).getbbox()
    if bbox is None:
        raise ValueError("empty frame")
    return bbox


def measure(image: Image.Image) -> dict[str, float | int]:
    bbox = alpha_bbox(image)
    visible_height = bbox[3] - bbox[1]
    head_bottom = min(bbox[3], bbox[1] + max(72, round(visible_height * 0.27)))
    alpha = image.getchannel("A")
    row_spans: list[int] = []
    face_points: list[tuple[int, int]] = []
    hair_luma: list[float] = []
    dark_luma: list[float] = []
    magenta_fringe = 0

    for y in range(bbox[1], bbox[3]):
        visible_x: list[int] = []
        for x in range(bbox[0], bbox[2]):
            a = alpha.getpixel((x, y))
            if a < ALPHA_THRESHOLD:
                continue
            r, g, b, _ = image.getpixel((x, y))
            luma = 0.2126 * r + 0.7152 * g + 0.0722 * b
            if y < head_bottom:
                visible_x.append(x)
                if r >= 190 and g >= 155 and b >= 135 and r - g >= 4 and g - b >= 4:
                    face_points.append((x, y))
                if 135 <= luma <= 235 and abs(r - g) <= 42 and 2 <= g - b <= 45:
                    hair_luma.append(luma)
            if 18 <= luma <= 100 and b >= g - 10:
                dark_luma.append(luma)
            if r >= 120 and b >= 120 and g <= 95 and min(r, b) - g >= 55:
                magenta_fringe += 1
        if visible_x:
            row_spans.append(max(visible_x) - min(visible_x) + 1)

    if not row_spans or not face_points or not hair_luma or not dark_luma:
        raise ValueError("identity proxy region is empty")
    return {
        "bbox_top": bbox[1],
        "head_width_proxy_px": max(row_spans),
        "face_width_proxy_px": max(x for x, _ in face_points) - min(x for x, _ in face_points) + 1,
        "face_height_proxy_px": max(y for _, y in face_points) - min(y for _, y in face_points) + 1,
        "hair_luma_proxy": round(sum(hair_luma) / len(hair_luma), 3),
        "dark_material_luma_proxy": round(sum(dark_luma) / len(dark_luma), 3),
        "magenta_fringe_pixels": magenta_fringe,
    }


def main() -> None:
    measurements: dict[int, dict[str, float | int]] = {}
    for index in sorted(set(GENERATED) | set(AUTHORITIES.values())):
        with Image.open(FRAMES / f"frame_{index:03d}.png") as source:
            measurements[index] = measure(source.convert("RGBA"))

    records: list[dict[str, float | int]] = []
    for index in GENERATED:
        authority = AUTHORITIES[index]
        current = measurements[index]
        anchor = measurements[authority]
        record: dict[str, float | int] = {
            "frame": index,
            "authority_frame": authority,
            **current,
            "head_width_delta_px": round(abs(float(current["head_width_proxy_px"]) - float(anchor["head_width_proxy_px"])), 3),
            "face_width_delta_px": round(abs(float(current["face_width_proxy_px"]) - float(anchor["face_width_proxy_px"])), 3),
            "face_height_delta_px": round(abs(float(current["face_height_proxy_px"]) - float(anchor["face_height_proxy_px"])), 3),
            "hair_luma_delta": round(abs(float(current["hair_luma_proxy"]) - float(anchor["hair_luma_proxy"])), 3),
            "dark_material_luma_delta": round(abs(float(current["dark_material_luma_proxy"]) - float(anchor["dark_material_luma_proxy"])), 3),
        }
        records.append(record)

    def maximum(key: str) -> float:
        return round(max(float(record[key]) for record in records), 3)

    summary = {
        "generated_frame_count": len(records),
        "max_head_width_delta_px": maximum("head_width_delta_px"),
        "max_face_width_delta_px": maximum("face_width_delta_px"),
        "max_face_height_delta_px": maximum("face_height_delta_px"),
        "max_hair_luma_delta": maximum("hair_luma_delta"),
        "max_dark_material_luma_delta": maximum("dark_material_luma_delta"),
        "max_magenta_fringe_pixels": maximum("magenta_fringe_pixels"),
    }
    thresholds = {
        "max_head_width_delta_px": 22,
        "max_face_width_delta_px": 20,
        "max_face_height_delta_px": 20,
        "max_hair_luma_delta": 28,
        "max_dark_material_luma_delta": 18,
        "max_magenta_fringe_pixels": 80,
    }
    status = "PASS" if all(summary[key] <= value for key, value in thresholds.items()) else "FAIL"
    QA.mkdir(parents=True, exist_ok=True)
    (QA / "local-identity-report.json").write_text(
        json.dumps({"status": status, "summary": summary, "thresholds": thresholds, "frames": records}, indent=2),
        encoding="utf-8",
    )

    columns = 5
    rows = 2
    panel = 260
    label_height = 38
    sheet = Image.new("RGBA", (columns * panel, rows * (panel + label_height)), (44, 47, 53, 255))
    draw = ImageDraw.Draw(sheet)
    font_path = Path("C:/Windows/Fonts/segoeui.ttf")
    font = ImageFont.truetype(str(font_path), 17) if font_path.exists() else ImageFont.load_default()
    for position, index in enumerate(GENERATED):
        with Image.open(FRAMES / f"frame_{index:03d}.png") as source:
            image = source.convert("RGBA")
        top = max(0, int(measurements[index]["bbox_top"]) - 8)
        crop = image.crop((136, top, 376, min(512, top + 240))).resize((panel, panel), Image.Resampling.LANCZOS)
        x = (position % columns) * panel
        y = (position // columns) * (panel + label_height)
        sheet.alpha_composite(crop, (x, y + label_height))
        draw.text((x + 10, y + 9), f"F{index:02d} / A{AUTHORITIES[index]:02d}", fill=(245, 245, 245, 255), font=font)
    sheet.save(QA / "generated-head-closeup.png", format="PNG", optimize=True)

    torso_sheet = Image.new("RGBA", (columns * panel, rows * (panel + label_height)), (44, 47, 53, 255))
    torso_draw = ImageDraw.Draw(torso_sheet)
    for position, index in enumerate(GENERATED):
        with Image.open(FRAMES / f"frame_{index:03d}.png") as source:
            image = source.convert("RGBA")
        bbox = alpha_bbox(image)
        visible_height = bbox[3] - bbox[1]
        top = max(0, bbox[1] + round(visible_height * 0.18))
        bottom = min(512, bbox[1] + round(visible_height * 0.62))
        crop = image.crop((126, top, 386, bottom)).resize((panel, panel), Image.Resampling.LANCZOS)
        x = (position % columns) * panel
        y = (position // columns) * (panel + label_height)
        torso_sheet.alpha_composite(crop, (x, y + label_height))
        torso_draw.text((x + 10, y + 9), f"F{index:02d} garment", fill=(245, 245, 245, 255), font=font)
    torso_sheet.save(QA / "generated-garment-closeup.png", format="PNG", optimize=True)

    if status != "PASS":
        raise SystemExit(2)


if __name__ == "__main__":
    main()
