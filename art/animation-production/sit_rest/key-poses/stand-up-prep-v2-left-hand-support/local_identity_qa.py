from __future__ import annotations

import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parent
NORMALIZED = ROOT / "normalized"
QA = ROOT / "qa"
INDICES = (17, 19, 20, 21, 22, 25)
ALPHA_THRESHOLD = 16


def alpha_bbox(image: Image.Image) -> tuple[int, int, int, int]:
    bbox = image.getchannel("A").point(lambda value: 255 if value >= ALPHA_THRESHOLD else 0).getbbox()
    if bbox is None:
        raise ValueError("empty frame")
    return bbox


def measure_head(image: Image.Image, bbox: tuple[int, int, int, int]) -> dict[str, float | int]:
    height = bbox[3] - bbox[1]
    band_bottom = min(bbox[3], bbox[1] + max(72, round(height * 0.25)))
    alpha = image.getchannel("A")
    row_spans: list[int] = []
    face_points: list[tuple[int, int]] = []
    hair_luma: list[float] = []

    for y in range(bbox[1], band_bottom):
        xs: list[int] = []
        for x in range(bbox[0], bbox[2]):
            if alpha.getpixel((x, y)) < ALPHA_THRESHOLD:
                continue
            xs.append(x)
            r, g, b, _ = image.getpixel((x, y))
            luma = 0.2126 * r + 0.7152 * g + 0.0722 * b
            if r >= 205 and g >= 175 and b >= 150 and r - g >= 5 and g - b >= 5:
                face_points.append((x, y))
            if 145 <= luma <= 235 and abs(r - g) <= 38 and 4 <= g - b <= 38:
                hair_luma.append(luma)
        if xs:
            row_spans.append(max(xs) - min(xs) + 1)

    if not row_spans or not face_points or not hair_luma:
        raise ValueError("head proxy region is empty")
    face_width = max(x for x, _ in face_points) - min(x for x, _ in face_points) + 1
    face_height = max(y for _, y in face_points) - min(y for _, y in face_points) + 1
    return {
        "head_width_proxy_px": max(row_spans),
        "face_width_proxy_px": face_width,
        "face_height_proxy_px": face_height,
        "hair_luma_proxy": round(sum(hair_luma) / len(hair_luma), 3),
    }


def main() -> None:
    records: list[dict[str, float | int]] = []
    closeups: list[Image.Image] = []
    for index in INDICES:
        with Image.open(NORMALIZED / f"frame_{index:03d}.png") as source:
            image = source.convert("RGBA")
        bbox = alpha_bbox(image)
        measurements = measure_head(image, bbox)
        records.append({"frame": index, **measurements})
        crop = image.crop((156, 0, 356, 210)).resize((300, 315), Image.Resampling.LANCZOS)
        closeups.append(crop)

    def value_range(key: str) -> float:
        values = [float(record[key]) for record in records]
        return round(max(values) - min(values), 3)

    summary = {
        "head_width_proxy_range_px": value_range("head_width_proxy_px"),
        "face_width_proxy_range_px": value_range("face_width_proxy_px"),
        "hair_luma_proxy_range": value_range("hair_luma_proxy"),
    }
    thresholds = {
        "max_head_width_proxy_range_px": 22,
        "max_face_width_proxy_range_px": 20,
        "max_hair_luma_proxy_range": 28,
    }
    status = "PASS" if (
        summary["head_width_proxy_range_px"] <= thresholds["max_head_width_proxy_range_px"]
        and summary["face_width_proxy_range_px"] <= thresholds["max_face_width_proxy_range_px"]
        and summary["hair_luma_proxy_range"] <= thresholds["max_hair_luma_proxy_range"]
    ) else "FAIL"
    QA.mkdir(parents=True, exist_ok=True)
    (QA / "local-identity-report.json").write_text(
        json.dumps({"status": status, "summary": summary, "thresholds": thresholds, "frames": records}, indent=2),
        encoding="utf-8",
    )

    label_height = 40
    sheet = Image.new("RGBA", (len(closeups) * 300, 315 + label_height), (44, 47, 53, 255))
    draw = ImageDraw.Draw(sheet)
    font_path = Path("C:/Windows/Fonts/segoeui.ttf")
    font = ImageFont.truetype(str(font_path), 18) if font_path.exists() else ImageFont.load_default()
    for panel, (index, crop) in enumerate(zip(INDICES, closeups)):
        x = panel * 300
        sheet.alpha_composite(crop, (x, label_height))
        draw.text((x + 10, 10), f"F{index:02d}", fill=(245, 245, 245, 255), font=font)
    sheet.save(QA / "identity-head-closeup.png", format="PNG", optimize=True)

    if status != "PASS":
        raise SystemExit(2)


if __name__ == "__main__":
    main()
