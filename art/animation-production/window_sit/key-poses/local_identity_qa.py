from __future__ import annotations

import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parent
FRAMES = ROOT / "normalized"
QA = ROOT / "qa"
KEYS = [
    "k00_stand",
    "k04_descent",
    "k08_stable_window_seat",
    "k12_leg_swing",
    "k19_side_lean",
    "k27_rise_load",
    "k31_stand_return",
]
AUTHORITIES = {
    "k04_descent": "k00_stand",
    "k08_stable_window_seat": "k00_stand",
    "k12_leg_swing": "k08_stable_window_seat",
    "k19_side_lean": "k08_stable_window_seat",
    "k27_rise_load": "k00_stand",
    "k31_stand_return": "k00_stand",
}
ALPHA_THRESHOLD = 16


def alpha_bbox(image: Image.Image) -> tuple[int, int, int, int]:
    bbox = image.getchannel("A").point(lambda value: 255 if value >= ALPHA_THRESHOLD else 0).getbbox()
    if bbox is None:
        raise ValueError("empty frame")
    return bbox


def measure(image: Image.Image) -> dict[str, float | int]:
    bbox = alpha_bbox(image)
    # Use a pose-independent head band. A percentage of full-body height
    # falsely shortens the face proxy in compact crouch/rise keys.
    head_bottom = min(bbox[3], bbox[1] + 128)
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
        "bbox": list(bbox),
        "head_width_proxy_px": max(row_spans),
        "face_width_proxy_px": max(x for x, _ in face_points) - min(x for x, _ in face_points) + 1,
        "face_height_proxy_px": max(y for _, y in face_points) - min(y for _, y in face_points) + 1,
        "hair_luma_proxy": round(sum(hair_luma) / len(hair_luma), 3),
        "dark_material_luma_proxy": round(sum(dark_luma) / len(dark_luma), 3),
        "magenta_fringe_pixels": magenta_fringe,
    }


def font(size: int) -> ImageFont.ImageFont:
    for candidate in (Path("C:/Windows/Fonts/msyh.ttc"), Path("C:/Windows/Fonts/segoeui.ttf")):
        if candidate.exists():
            return ImageFont.truetype(str(candidate), size=size)
    return ImageFont.load_default()


def main() -> None:
    measurements: dict[str, dict[str, float | int | list[int]]] = {}
    images: dict[str, Image.Image] = {}
    for name in KEYS:
        image = Image.open(FRAMES / f"{name}.png").convert("RGBA")
        images[name] = image
        measurements[name] = measure(image)

    records: list[dict[str, object]] = []
    for name, authority_name in AUTHORITIES.items():
        current = measurements[name]
        authority = measurements[authority_name]
        record: dict[str, object] = {
            "key": name,
            "authority": authority_name,
            **current,
            "head_width_delta_px": abs(float(current["head_width_proxy_px"]) - float(authority["head_width_proxy_px"])),
            "face_width_delta_px": abs(float(current["face_width_proxy_px"]) - float(authority["face_width_proxy_px"])),
            "face_height_delta_px": abs(float(current["face_height_proxy_px"]) - float(authority["face_height_proxy_px"])),
            "hair_luma_delta": round(abs(float(current["hair_luma_proxy"]) - float(authority["hair_luma_proxy"])), 3),
            "dark_material_luma_delta": round(abs(float(current["dark_material_luma_proxy"]) - float(authority["dark_material_luma_proxy"])), 3),
        }
        records.append(record)

    def maximum(key: str) -> float:
        return round(max(float(record[key]) for record in records), 3)

    summary = {
        "key_count": len(KEYS),
        "max_head_width_delta_px": maximum("head_width_delta_px"),
        "max_face_width_delta_px": maximum("face_width_delta_px"),
        "max_face_height_delta_px": maximum("face_height_delta_px"),
        "max_hair_luma_delta": maximum("hair_luma_delta"),
        "max_dark_material_luma_delta": maximum("dark_material_luma_delta"),
        "max_magenta_fringe_pixels": max(int(record["magenta_fringe_pixels"]) for record in records),
    }
    thresholds = {
        "max_head_width_delta_px": 12,
        "max_face_width_delta_px": 12,
        "max_face_height_delta_px": 20,
        "max_hair_luma_delta": 12,
        "max_dark_material_luma_delta": 12,
        "max_magenta_fringe_pixels": 16,
    }
    status = "PASS" if all(float(summary[key]) <= value for key, value in thresholds.items()) else "FAIL"
    QA.mkdir(parents=True, exist_ok=True)
    (QA / "local-identity-report.json").write_text(
        json.dumps(
            {
                "status": status,
                "method": "Fixed 128px head band from each alpha top; independent of crouch or seated full-body height.",
                "summary": summary,
                "thresholds": thresholds,
                "keys": records,
            },
            ensure_ascii=False,
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )

    panel = 230
    label_h = 36
    sheet = Image.new("RGBA", (panel * 4, (panel + label_h) * 2), (42, 44, 50, 255))
    draw = ImageDraw.Draw(sheet)
    label_font = font(16)
    for position, name in enumerate(KEYS):
        image = images[name]
        bbox = alpha_bbox(image)
        crop_top = max(0, bbox[1] - 8)
        crop = image.crop((126, crop_top, 386, min(512, crop_top + 260))).resize((panel, panel), Image.Resampling.LANCZOS)
        x = (position % 4) * panel
        y = (position // 4) * (panel + label_h)
        sheet.alpha_composite(crop, (x, y + label_h))
        draw.text((x + 8, y + 8), name, fill=(245, 245, 248, 255), font=label_font)
    sheet.save(QA / "local-identity-contact-sheet.png", optimize=True)

    if status != "PASS":
        raise SystemExit(2)


if __name__ == "__main__":
    main()
