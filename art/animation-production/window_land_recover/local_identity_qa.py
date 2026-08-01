from __future__ import annotations

import json
import statistics
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

import process_key_poses as helpers


ROOT = Path(__file__).resolve().parent
FRAMES = ROOT / "frames"
QA = ROOT / "qa"
DIRECT = (1, 2, 4, 5, 7, 8, 9, 11, 12, 13)
AUTHORITIES = {1: 0, 2: 3, 4: 3, 5: 6, 7: 6, 8: 6, 9: 10, 11: 10, 12: 14, 13: 14}
ALPHA_THRESHOLD = 16


def alpha_bbox(image: Image.Image) -> tuple[int, int, int, int]:
    bbox = image.getchannel("A").point(
        lambda value: 255 if value >= ALPHA_THRESHOLD else 0
    ).getbbox()
    if bbox is None:
        raise ValueError("empty frame")
    return bbox


def row_runs(image: Image.Image, y: int, x0: int, x1: int) -> list[int]:
    alpha = image.getchannel("A")
    runs: list[int] = []
    start: int | None = None
    for x in range(max(0, x0), min(image.width, x1)):
        visible = alpha.getpixel((x, y)) >= ALPHA_THRESHOLD
        if visible and start is None:
            start = x
        elif not visible and start is not None:
            runs.append(x - start)
            start = None
    if start is not None:
        runs.append(min(image.width, x1) - start)
    return runs


def row_span(image: Image.Image, y: int) -> int:
    alpha = image.getchannel("A")
    xs = [x for x in range(image.width) if alpha.getpixel((x, y)) >= ALPHA_THRESHOLD]
    return max(xs) - min(xs) + 1 if xs else 0


def measure(image: Image.Image) -> dict[str, float | int | list[int]]:
    bbox = alpha_bbox(image)
    head_bbox = helpers._head_bbox(image, bbox)
    alpha = image.getchannel("A")
    visible_height = bbox[3] - bbox[1]
    head_width = head_bbox[2] - head_bbox[0]
    head_height = head_bbox[3] - head_bbox[1]
    center_x = (head_bbox[0] + head_bbox[2]) // 2

    face_points: list[tuple[int, int]] = []
    hair_luma: list[float] = []
    navy_luma: list[float] = []
    navy_texture: list[float] = []
    magenta_fringe = 0
    strap_pixels = 0
    rabbit_light_pixels = 0

    head_bottom = head_bbox[3]
    torso_bottom = min(bbox[3], bbox[1] + round(visible_height * 0.69))
    rabbit_top = min(bbox[3], head_bottom + 20)
    rabbit_bottom = min(bbox[3], bbox[1] + round(visible_height * 0.76))
    pixels = image.load()

    for y in range(bbox[1], bbox[3]):
        for x in range(bbox[0], bbox[2]):
            if alpha.getpixel((x, y)) < ALPHA_THRESHOLD:
                continue
            red, green, blue, _ = pixels[x, y]
            luma = 0.2126 * red + 0.7152 * green + 0.0722 * blue

            if head_bbox[0] <= x < head_bbox[2] and head_bbox[1] <= y < head_bbox[3]:
                if red >= 175 and green >= 135 and blue >= 115 and red >= green >= blue - 8:
                    face_points.append((x, y))
                if 125 <= luma <= 235 and abs(red - green) <= 48 and 0 <= green - blue <= 55:
                    hair_luma.append(luma)

            if head_bottom - 4 <= y < torso_bottom and 145 <= x <= 370:
                if 15 <= red <= 95 and 18 <= green <= 100 and 24 <= blue <= 120 and blue >= red - 4:
                    navy_luma.append(luma)
                    if x + 1 < image.width and alpha.getpixel((x + 1, y)) >= ALPHA_THRESHOLD:
                        rr, gg, bb, _ = pixels[x + 1, y]
                        if 15 <= rr <= 95 and 18 <= gg <= 100 and 24 <= bb <= 120 and bb >= rr - 4:
                            adjacent = 0.2126 * rr + 0.7152 * gg + 0.0722 * bb
                            navy_texture.append(abs(luma - adjacent))

            if head_bottom <= y < torso_bottom:
                progress = (y - head_bottom) / max(1, torso_bottom - head_bottom)
                expected_x = center_x - 13 + progress * 37
                if abs(x - expected_x) <= 24 and red >= 105 and 55 <= green <= 175 and blue <= 135 and red >= green + 12:
                    strap_pixels += 1

            if center_x + 2 <= x < min(image.width, center_x + 115) and rabbit_top <= y < rabbit_bottom:
                if red >= 178 and green >= 165 and blue >= 145 and max(red, green, blue) - min(red, green, blue) <= 65:
                    rabbit_light_pixels += 1

            if red >= 120 and blue >= 120 and green <= 95 and min(red, blue) - green >= 55:
                magenta_fringe += 1

    if not face_points or not hair_luma or not navy_luma or not navy_texture:
        raise ValueError("identity proxy region is empty")

    lower_runs: list[int] = []
    for y in range(bbox[1] + round(visible_height * 0.72), bbox[3]):
        for run in row_runs(image, y, center_x - 78, center_x + 78):
            if 7 <= run <= 48:
                lower_runs.append(run)
    if not lower_runs:
        raise ValueError("lower-limb proxy region is empty")

    torso_y = min(bbox[3] - 1, bbox[1] + round(visible_height * 0.42))
    skirt_y = min(bbox[3] - 1, bbox[1] + round(visible_height * 0.63))
    return {
        "bbox": list(bbox),
        "visible_height": visible_height,
        "visible_bottom": bbox[3] - 1,
        "head_width_px": head_width,
        "head_height_px": head_height,
        "face_width_proxy_px": max(x for x, _ in face_points) - min(x for x, _ in face_points) + 1,
        "face_height_proxy_px": max(y for _, y in face_points) - min(y for _, y in face_points) + 1,
        "hair_luma_proxy": round(statistics.fmean(hair_luma), 3),
        "navy_luma_proxy": round(statistics.fmean(navy_luma), 3),
        "navy_texture_proxy": round(statistics.fmean(navy_texture), 3),
        "torso_width_proxy_px": row_span(image, torso_y),
        "skirt_width_proxy_px": row_span(image, skirt_y),
        "lower_limb_run_proxy_px": round(statistics.median(lower_runs), 3),
        "strap_route_pixels": strap_pixels,
        "rabbit_light_pixels": rabbit_light_pixels,
        "magenta_fringe_pixels": magenta_fringe,
    }


def delta(current: dict[str, object], anchor: dict[str, object], key: str) -> float:
    return round(abs(float(current[key]) - float(anchor[key])), 3)


def font(size: int) -> ImageFont.ImageFont:
    path = Path("C:/Windows/Fonts/segoeui.ttf")
    return ImageFont.truetype(str(path), size) if path.exists() else ImageFont.load_default()


def draw_full_contact_sheet(images: dict[int, Image.Image]) -> None:
    columns, rows, panel, label = 5, 3, 280, 38
    sheet = Image.new("RGBA", (columns * panel, rows * (panel + label)), (37, 40, 47, 255))
    draw = ImageDraw.Draw(sheet)
    label_font = font(17)
    for position, index in enumerate(range(15)):
        x = (position % columns) * panel
        y = (position // columns) * (panel + label)
        draw.text((x + 10, y + 9), f"F{index:02d}  {'KEY' if index in (0, 3, 6, 10, 14) else 'DIRECT'}", fill=(245, 245, 245, 255), font=label_font)
        frame = images[index].resize((256, 256), Image.Resampling.LANCZOS)
        sheet.alpha_composite(frame, (x + 12, y + label))
        line_y = y + label + 236
        color = (96, 221, 153, 230) if index >= 3 else (88, 178, 255, 210)
        for sx in range(x + 12, x + 268, 12):
            draw.line((sx, line_y, min(sx + 7, x + 267), line_y), fill=color, width=1)
    sheet.save(QA / "local-identity-contact-sheet.png", format="PNG", optimize=True)


def draw_closeup_sheet(images: dict[int, Image.Image], measurements: dict[int, dict[str, object]]) -> None:
    columns, rows, panel, label = 5, 3, 240, 34
    head_sheet = Image.new("RGBA", (columns * panel, rows * (panel + label)), (37, 40, 47, 255))
    material_sheet = Image.new("RGBA", (columns * panel, rows * (panel + label)), (37, 40, 47, 255))
    head_draw = ImageDraw.Draw(head_sheet)
    material_draw = ImageDraw.Draw(material_sheet)
    label_font = font(16)
    for position, index in enumerate(range(15)):
        image = images[index]
        bbox = tuple(int(value) for value in measurements[index]["bbox"])
        head_bbox = helpers._head_bbox(image, bbox)
        x = (position % columns) * panel
        y = (position // columns) * (panel + label)
        for canvas, canvas_draw, title in (
            (head_sheet, head_draw, f"F{index:02d} head/face"),
            (material_sheet, material_draw, f"F{index:02d} dress/bag"),
        ):
            canvas_draw.text((x + 8, y + 8), title, fill=(245, 245, 245, 255), font=label_font)

        pad = 18
        crop = image.crop((max(0, head_bbox[0] - pad), max(0, head_bbox[1] - pad), min(512, head_bbox[2] + pad), min(512, head_bbox[3] + pad)))
        crop.thumbnail((220, 220), Image.Resampling.LANCZOS)
        head_sheet.alpha_composite(crop, (x + (panel - crop.width) // 2, y + label + (panel - crop.height) // 2))

        visible_height = bbox[3] - bbox[1]
        material_crop = image.crop((max(0, bbox[0] - 8), bbox[1] + round(visible_height * 0.20), min(512, bbox[2] + 8), min(512, bbox[1] + round(visible_height * 0.77))))
        material_crop.thumbnail((220, 220), Image.Resampling.LANCZOS)
        material_sheet.alpha_composite(material_crop, (x + (panel - material_crop.width) // 2, y + label + (panel - material_crop.height) // 2))

    head_sheet.save(QA / "head-face-contact-sheet.png", format="PNG", optimize=True)
    material_sheet.save(QA / "material-topology-contact-sheet.png", format="PNG", optimize=True)


def write_slow_gif(images: dict[int, Image.Image]) -> None:
    checker = Image.new("RGBA", (512, 512), (58, 60, 64, 255))
    checker_draw = ImageDraw.Draw(checker)
    tile = 24
    for y in range(0, 512, tile):
        for x in range(0, 512, tile):
            if (x // tile + y // tile) % 2:
                checker_draw.rectangle((x, y, x + tile - 1, y + tile - 1), fill=(78, 80, 84, 255))
    frames: list[Image.Image] = []
    for index in range(15):
        composed = checker.copy()
        composed.alpha_composite(images[index])
        frames.append(composed.convert("RGB"))
    frames[0].save(
        QA / "preview-slow.gif",
        save_all=True,
        append_images=frames[1:],
        duration=300,
        loop=0,
        disposal=2,
        optimize=False,
    )


def main() -> None:
    QA.mkdir(parents=True, exist_ok=True)
    images: dict[int, Image.Image] = {}
    measurements: dict[int, dict[str, object]] = {}
    for index in range(15):
        with Image.open(FRAMES / f"frame_{index:03d}.png") as source:
            images[index] = source.convert("RGBA")
        measurements[index] = measure(images[index])

    records: list[dict[str, object]] = []
    for index in DIRECT:
        authority = AUTHORITIES[index]
        current = measurements[index]
        anchor = measurements[authority]
        records.append(
            {
                "frame": index,
                "authority_frame": authority,
                **current,
                "head_width_delta_px": delta(current, anchor, "head_width_px"),
                "head_height_delta_px": delta(current, anchor, "head_height_px"),
                "face_width_delta_px": delta(current, anchor, "face_width_proxy_px"),
                "face_height_delta_px": delta(current, anchor, "face_height_proxy_px"),
                "hair_luma_delta": delta(current, anchor, "hair_luma_proxy"),
                "navy_luma_delta": delta(current, anchor, "navy_luma_proxy"),
                "navy_texture_delta": delta(current, anchor, "navy_texture_proxy"),
                "torso_width_delta_px": delta(current, anchor, "torso_width_proxy_px"),
                "skirt_width_delta_px": delta(current, anchor, "skirt_width_proxy_px"),
                "lower_limb_run_delta_px": delta(current, anchor, "lower_limb_run_proxy_px"),
            }
        )

    def maximum(key: str) -> float:
        return round(max(float(record[key]) for record in records), 3)

    head_widths = [int(measurements[index]["head_width_px"]) for index in range(15)]
    contact_bottoms = [int(measurements[index]["visible_bottom"]) for index in range(3, 15)]
    descent_bottoms = [int(measurements[index]["visible_bottom"]) for index in range(4)]
    summary = {
        "direct_frame_count": len(records),
        "head_width_range_px": max(head_widths) - min(head_widths),
        "max_head_height_delta_px": maximum("head_height_delta_px"),
        "max_face_width_delta_px": maximum("face_width_delta_px"),
        "max_face_height_delta_px": maximum("face_height_delta_px"),
        "max_hair_luma_delta": maximum("hair_luma_delta"),
        "max_navy_luma_delta": maximum("navy_luma_delta"),
        "max_navy_texture_delta": maximum("navy_texture_delta"),
        "max_torso_width_delta_px": maximum("torso_width_delta_px"),
        "max_skirt_width_delta_px": maximum("skirt_width_delta_px"),
        "max_lower_limb_run_delta_px": maximum("lower_limb_run_delta_px"),
        "min_strap_route_pixels": min(int(measurements[index]["strap_route_pixels"]) for index in range(15)),
        "min_rabbit_light_pixels": min(int(measurements[index]["rabbit_light_pixels"]) for index in range(15)),
        "max_magenta_fringe_pixels": max(int(measurements[index]["magenta_fringe_pixels"]) for index in range(15)),
        "contact_baseline_range_px": max(contact_bottoms) - min(contact_bottoms),
        "descent_bottoms": descent_bottoms,
        "descent_is_monotonic": all(left < right for left, right in zip(descent_bottoms, descent_bottoms[1:])),
    }
    thresholds = {
        "head_width_range_px": 3,
        "max_head_height_delta_px": 4,
        "max_face_width_delta_px": 18,
        "max_face_height_delta_px": 18,
        "max_hair_luma_delta": 24,
        "max_navy_luma_delta": 18,
        "max_navy_texture_delta": 10,
        "max_torso_width_delta_px": 42,
        "max_skirt_width_delta_px": 55,
        "max_lower_limb_run_delta_px": 15,
        "min_strap_route_pixels": 70,
        "min_rabbit_light_pixels": 80,
        "max_magenta_fringe_pixels": 90,
        "contact_baseline_range_px": 1,
        "descent_is_monotonic": True,
    }
    failures: list[str] = []
    for key, limit in thresholds.items():
        value = summary[key]
        if key.startswith("min_"):
            if float(value) < float(limit):
                failures.append(f"{key}: {value} < {limit}")
        elif isinstance(limit, bool):
            if value is not limit:
                failures.append(f"{key}: {value} != {limit}")
        elif float(value) > float(limit):
            failures.append(f"{key}: {value} > {limit}")

    status = "PASS" if not failures else "FAIL"
    report = {
        "status": status,
        "summary": summary,
        "thresholds": thresholds,
        "failures": failures,
        "semantic_checks_required": [
            "single intact rabbit and single satchel in every frame",
            "strap remains connected and on canonical route",
            "face, body volume, leg thickness and hair brightness remain character-consistent",
            "no platform art; both soles own the invisible contact plane after F03",
            "F12-F14 reads as restrained rebound and final settle, not proportion drift",
        ],
        "frames": records,
    }
    (QA / "local-identity-report.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
    draw_full_contact_sheet(images)
    draw_closeup_sheet(images, measurements)
    write_slow_gif(images)
    if status != "PASS":
        raise SystemExit(2)


if __name__ == "__main__":
    main()
