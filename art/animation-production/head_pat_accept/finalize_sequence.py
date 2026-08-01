from __future__ import annotations

import argparse
import json
import math
import statistics
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont, ImageOps, ImageSequence

from process_key_poses import REFERENCE, alpha_bbox, metrics


ROOT = Path(__file__).resolve().parent
FRAMES = ROOT / "frames"
QA = ROOT / "qa"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Build head_pat_accept local identity/material QA artifacts."
    )
    parser.add_argument(
        "--semantic-pass",
        action="store_true",
        help="Record that the generated review sheets were visually inspected and passed.",
    )
    return parser.parse_args()


def font(size: int) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    for path in (
        Path("C:/Windows/Fonts/msyh.ttc"),
        Path("C:/Windows/Fonts/segoeui.ttf"),
    ):
        if path.exists():
            return ImageFont.truetype(str(path), size)
    return ImageFont.load_default()


def checkerboard(size: tuple[int, int], tile: int = 16) -> Image.Image:
    image = Image.new("RGBA", size, (57, 60, 67, 255))
    draw = ImageDraw.Draw(image)
    colors = ((57, 60, 67, 255), (43, 46, 52, 255))
    for y in range(0, size[1], tile):
        for x in range(0, size[0], tile):
            draw.rectangle(
                (x, y, min(x + tile - 1, size[0] - 1), min(y + tile - 1, size[1] - 1)),
                fill=colors[((x // tile) + (y // tile)) % 2],
            )
    return image


def contain_rgba(image: Image.Image, size: tuple[int, int]) -> Image.Image:
    source = image.convert("RGBA")
    fitted = ImageOps.contain(source, size, Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", size, (0, 0, 0, 0))
    canvas.alpha_composite(
        fitted,
        ((size[0] - fitted.width) // 2, (size[1] - fitted.height) // 2),
    )
    return canvas


def navy_texture_energy(image: Image.Image) -> float:
    rgba = image.convert("RGBA")
    bbox = alpha_bbox(rgba)
    height = bbox[3] - bbox[1]
    y0 = bbox[1] + round(height * 0.29)
    y1 = min(rgba.height - 1, bbox[1] + round(height * 0.65))
    pixels = rgba.load()
    differences: list[int] = []

    def navy(pixel: tuple[int, int, int, int]) -> bool:
        r, g, b, a = pixel
        return a >= 64 and r < 100 and g < 105 and b < 125

    def luma(pixel: tuple[int, int, int, int]) -> int:
        r, g, b, _ = pixel
        return round(0.2126 * r + 0.7152 * g + 0.0722 * b)

    for y in range(y0, y1):
        for x in range(max(0, bbox[0]), min(rgba.width - 1, bbox[2] - 1)):
            current = pixels[x, y]
            right = pixels[x + 1, y]
            down = pixels[x, y + 1]
            if navy(current) and navy(right):
                differences.append(abs(luma(current) - luma(right)))
            if navy(current) and navy(down):
                differences.append(abs(luma(current) - luma(down)))
    return round(statistics.fmean(differences), 6) if differences else 0.0


def frame_paths() -> list[Path]:
    paths = sorted(FRAMES.glob("frame_*.png"))
    expected = [f"frame_{index:03d}.png" for index in range(17)]
    actual = [path.name for path in paths]
    if actual != expected:
        raise ValueError(f"expected 17 ordered frames, got: {actual}")
    return paths


def build_local_contact_sheet(paths: list[Path]) -> None:
    columns = 4
    rows = math.ceil(len(paths) / columns)
    cell_w = 512
    cell_h = 368
    label_h = 34
    sheet = checkerboard((columns * cell_w, rows * cell_h), tile=18)
    draw = ImageDraw.Draw(sheet)
    label_font = font(19)
    note_font = font(14)

    for index, path in enumerate(paths):
        with Image.open(path) as source:
            frame = source.convert("RGBA")
        col = index % columns
        row = index // columns
        x = col * cell_w
        y = row * cell_h
        head_torso = contain_rgba(frame.crop((132, 4, 380, 318)), (250, 320))
        bag_legs = contain_rgba(frame.crop((176, 205, 355, 485)), (250, 320))
        sheet.alpha_composite(head_torso, (x + 4, y + label_h))
        sheet.alpha_composite(bag_legs, (x + 258, y + label_h))
        draw.text((x + 10, y + 6), path.stem, fill=(250, 250, 250, 255), font=label_font)
        draw.text(
            (x + 338, y + 10),
            "face/body | bag/legs",
            fill=(184, 199, 211, 255),
            font=note_font,
        )
        draw.line((x + 256, y + label_h, x + 256, y + cell_h - 1), fill=(102, 205, 255, 120))
    sheet.save(QA / "local-identity-contact-sheet.png", format="PNG", optimize=True)


def build_slow_preview() -> None:
    source_path = QA / "preview.gif"
    output_path = QA / "preview-slow.gif"
    with Image.open(source_path) as source:
        frames = [frame.copy() for frame in ImageSequence.Iterator(source)]
    frames[0].save(
        output_path,
        save_all=True,
        append_images=frames[1:],
        duration=320,
        loop=0,
        disposal=2,
        optimize=False,
    )


def build_report(paths: list[Path], semantic_pass: bool) -> dict[str, object]:
    with Image.open(REFERENCE) as source:
        reference = source.convert("RGBA")
    reference_metrics = metrics(reference)
    reference_texture = navy_texture_energy(reference)

    with Image.open(FRAMES / "frame_007.png") as source:
        k07 = metrics(source.convert("RGBA"))
    with Image.open(FRAMES / "frame_009.png") as source:
        k09 = metrics(source.convert("RGBA"))

    target = {
        "visible_height": round((k07["visible_height"] + k09["visible_height"]) / 2),
        "head_silhouette_width": round(
            (k07["head_silhouette_width"] + k09["head_silhouette_width"]) / 2
        ),
        "face_color_bbox_width": round(
            (k07["face_color_bbox_width"] + k09["face_color_bbox_width"]) / 2
        ),
        "face_color_bbox_height": round(
            (k07["face_color_bbox_height"] + k09["face_color_bbox_height"]) / 2
        ),
        "leg_band_width_y385": round(
            (k07["leg_band_width_y385"] + k09["leg_band_width_y385"]) / 2
        ),
        "sock_band_width_y425": round(
            (k07["sock_band_width_y425"] + k09["sock_band_width_y425"]) / 2
        ),
        "shoe_band_width_y455": round(
            (k07["shoe_band_width_y455"] + k09["shoe_band_width_y455"]) / 2
        ),
    }
    absolute_limits = {
        "visible_height": 2,
        "head_silhouette_width": 3,
        "face_color_bbox_width": 4,
        "face_color_bbox_height": 4,
        "leg_band_width_y385": 3,
        "sock_band_width_y425": 3,
        "shoe_band_width_y455": 3,
    }
    luma_limits = {"hair_luma_median": 10, "navy_luma_median": 14}
    texture_limit = round(max(reference_texture, navy_texture_energy(Image.open(FRAMES / "frame_007.png").convert("RGBA")), navy_texture_energy(Image.open(FRAMES / "frame_009.png").convert("RGBA"))) * 1.5, 6)

    rows: list[dict[str, object]] = []
    numeric_status = "PASS"
    aggregate: dict[str, list[float]] = {
        key: []
        for key in (
            *absolute_limits,
            *luma_limits,
            "navy_high_frequency_energy",
            "baseline_y",
            "center_x",
        )
    }
    for path in paths:
        with Image.open(path) as source:
            frame = source.convert("RGBA")
        value_metrics = metrics(frame)
        bbox = value_metrics["alpha_bbox"]
        texture_energy = navy_texture_energy(frame)
        absolute_deltas = {
            key: abs(float(value_metrics[key]) - float(target[key]))
            for key in absolute_limits
        }
        luma_deltas = {
            key: abs(float(value_metrics[key]) - float(reference_metrics[key]))
            for key in luma_limits
        }
        violations = [
            {"metric": key, "delta": absolute_deltas[key], "limit": limit}
            for key, limit in absolute_limits.items()
            if absolute_deltas[key] > limit
        ]
        violations.extend(
            {"metric": key, "delta": luma_deltas[key], "limit": limit}
            for key, limit in luma_limits.items()
            if luma_deltas[key] > limit
        )
        if texture_energy > texture_limit:
            violations.append(
                {
                    "metric": "navy_high_frequency_energy",
                    "value": texture_energy,
                    "limit": texture_limit,
                }
            )
        if violations:
            numeric_status = "FAIL"
        baseline_y = bbox[3] - 1
        center_x = (bbox[0] + bbox[2] - 1) / 2.0
        for key in absolute_limits:
            aggregate[key].append(float(value_metrics[key]))
        for key in luma_limits:
            aggregate[key].append(float(value_metrics[key]))
        aggregate["navy_high_frequency_energy"].append(texture_energy)
        aggregate["baseline_y"].append(float(baseline_y))
        aggregate["center_x"].append(center_x)
        rows.append(
            {
                "frame": path.name,
                "metrics": {**value_metrics, "navy_high_frequency_energy": texture_energy},
                "absolute_delta_vs_action_family": absolute_deltas,
                "absolute_luma_delta_vs_standing_authority": luma_deltas,
                "violations": violations,
            }
        )

    ranges = {
        key: round(max(values) - min(values), 6) for key, values in aggregate.items()
    }
    sequence_limits = {
        "visible_height": 4,
        "head_silhouette_width": 5,
        "face_color_bbox_width": 6,
        "face_color_bbox_height": 8,
        "leg_band_width_y385": 3,
        "sock_band_width_y425": 3,
        "shoe_band_width_y455": 3,
        "hair_luma_median": 10,
        "navy_luma_median": 12,
        "baseline_y": 2,
        "center_x": 5,
    }
    range_violations = [
        {"metric": key, "range": ranges[key], "limit": limit}
        for key, limit in sequence_limits.items()
        if ranges[key] > limit
    ]
    if range_violations:
        numeric_status = "FAIL"

    status = "PASS" if numeric_status == "PASS" and semantic_pass else "PENDING"
    return {
        "status": status,
        "numeric_status": numeric_status,
        "semantic_status": "PASS" if semantic_pass else "PENDING_VISUAL_REVIEW",
        "reference": str(REFERENCE.relative_to(ROOT.parent.parent)),
        "reference_metrics": {
            **reference_metrics,
            "navy_high_frequency_energy": reference_texture,
        },
        "action_family_target": target,
        "absolute_limits_px": absolute_limits,
        "luma_limits": luma_limits,
        "navy_high_frequency_energy_limit": texture_limit,
        "sequence_ranges": ranges,
        "sequence_range_limits": sequence_limits,
        "sequence_range_violations": range_violations,
        "frames": rows,
        "semantic_checks": {
            "identity_and_proportions": "Head, face, body, limb and shoe proportions remain in the accepted standing family.",
            "materials": "Hair remains muted ash-beige and navy fabric avoids accumulating high-frequency stripe noise.",
            "topology": "One beret, one strap, one viewer-right satchel and one intact rabbit remain continuous in every frame.",
            "motion": "Only gaze, eyelids, tiny mouth change and restrained head inclination form the notice-accept-hold-release-recover arc.",
            "contact": "Both feet remain planted; no external hand or cursor is rendered.",
        },
        "note": "Numeric proxies cannot establish semantic identity or topology alone; PASS requires inspecting the full contact sheet, local identity sheet and both GIFs.",
    }


def main() -> None:
    args = parse_args()
    QA.mkdir(parents=True, exist_ok=True)
    paths = frame_paths()
    build_local_contact_sheet(paths)
    build_slow_preview()
    report = build_report(paths, args.semantic_pass)
    (QA / "local-identity-report.json").write_text(
        json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    print(json.dumps({"status": report["status"], "numeric_status": report["numeric_status"]}))


if __name__ == "__main__":
    main()
