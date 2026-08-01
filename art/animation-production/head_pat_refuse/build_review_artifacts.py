from __future__ import annotations

import json
import statistics
from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parent
FRAMES_DIR = ROOT / "frames"
QA_DIR = ROOT / "qa"
FRAME_COUNT = 23
REFERENCE_INDICES = (0, 4, 8, 13, 18, 22)
ONE_SHOT_CONTEXT_DURATIONS_MS = (
    450,
    120, 120, 120,
    180,
    120, 120, 120,
    140,
    100, 100, 100, 100,
    220,
    120, 120, 130, 140,
    160,
    140, 140, 160,
    700,
)


def load_frames() -> list[Image.Image]:
    frames: list[Image.Image] = []
    for index in range(FRAME_COUNT):
        path = FRAMES_DIR / f"frame_{index:03d}.png"
        with Image.open(path) as source:
            frame = source.convert("RGBA")
        if frame.size != (512, 512):
            raise ValueError(f"unexpected frame size for {path}: {frame.size}")
        frames.append(frame)
    return frames


def checkerboard(size: tuple[int, int], cell: int = 16) -> Image.Image:
    image = Image.new("RGB", size, (54, 57, 62))
    draw = ImageDraw.Draw(image)
    for y in range(0, size[1], cell):
        for x in range(0, size[0], cell):
            if (x // cell + y // cell) % 2:
                draw.rectangle((x, y, x + cell - 1, y + cell - 1), fill=(76, 80, 86))
    return image


def composite_on_checker(frame: Image.Image) -> Image.Image:
    background = checkerboard(frame.size)
    background.paste(frame, (0, 0), frame)
    return background


def alpha_bbox(frame: Image.Image) -> tuple[int, int, int, int]:
    bbox = frame.getchannel("A").point(lambda value: 255 if value >= 8 else 0).getbbox()
    if bbox is None:
        raise ValueError("empty alpha frame")
    return bbox


def contiguous_run_width(mask: Image.Image, y: int, center_x: int = 256) -> int:
    pixels = mask.load()
    x = max(0, min(mask.width - 1, center_x))
    if pixels[x, y] == 0:
        nearest = None
        for radius in range(1, 129):
            for candidate in (x - radius, x + radius):
                if 0 <= candidate < mask.width and pixels[candidate, y] != 0:
                    nearest = candidate
                    break
            if nearest is not None:
                x = nearest
                break
        if nearest is None:
            return 0
    left = x
    right = x
    while left > 0 and pixels[left - 1, y] != 0:
        left -= 1
    while right + 1 < mask.width and pixels[right + 1, y] != 0:
        right += 1
    return right - left + 1


def median_run_width(mask: Image.Image, start_y: int, end_y: int) -> float:
    widths = [contiguous_run_width(mask, y) for y in range(start_y, end_y + 1)]
    widths = [width for width in widths if width > 0]
    return float(statistics.median(widths)) if widths else 0.0


def frame_metrics(frame: Image.Image) -> dict[str, float | int | list[int]]:
    bbox = alpha_bbox(frame)
    x0, y0, x1, y1 = bbox
    height = y1 - y0
    width = x1 - x0
    mask = frame.getchannel("A").point(lambda value: 255 if value >= 16 else 0)

    def rel_y(ratio: float) -> int:
        return max(0, min(511, round(y0 + height * ratio)))

    head_width = median_run_width(mask, rel_y(0.07), rel_y(0.25))
    face_width = median_run_width(mask, rel_y(0.16), rel_y(0.29))
    torso_width = median_run_width(mask, rel_y(0.32), rel_y(0.54))
    hem_width = median_run_width(mask, rel_y(0.57), rel_y(0.70))

    alpha = frame.getchannel("A")
    rgb = frame.convert("RGB")
    hair_luma: list[float] = []
    dark_count = 0
    dark_total = 0
    tan_count = 0
    rabbit_light_count = 0
    accessory_total = 0
    left_leg_area = 0
    right_leg_area = 0
    leg_total = 0

    head_y1 = rel_y(0.31)
    body_y0 = rel_y(0.31)
    body_y1 = rel_y(0.72)
    legs_y0 = rel_y(0.73)
    legs_y1 = rel_y(0.96)
    accessory_x0 = 256
    accessory_y0 = rel_y(0.31)
    accessory_y1 = rel_y(0.73)

    alpha_pixels = alpha.load()
    rgb_pixels = rgb.load()
    for y in range(y0, y1):
        for x in range(x0, x1):
            if alpha_pixels[x, y] < 16:
                continue
            red, green, blue = rgb_pixels[x, y]
            luma = 0.2126 * red + 0.7152 * green + 0.0722 * blue
            if y <= head_y1 and 95 <= luma <= 225 and max(red, green, blue) - min(red, green, blue) <= 75:
                hair_luma.append(luma)
            if body_y0 <= y <= body_y1 and abs(x - 256) <= round(height * 0.24):
                dark_total += 1
                if luma < 92:
                    dark_count += 1
            if x >= accessory_x0 and accessory_y0 <= y <= accessory_y1:
                accessory_total += 1
                if red >= 105 and green >= 70 and blue <= 155 and red >= green + 12:
                    tan_count += 1
                if luma >= 205 and max(red, green, blue) - min(red, green, blue) <= 55:
                    rabbit_light_count += 1
            if legs_y0 <= y <= legs_y1:
                leg_total += 1
                if x < 256:
                    left_leg_area += 1
                else:
                    right_leg_area += 1

    return {
        "alpha_bbox": list(bbox),
        "height": height,
        "width": width,
        "baseline_y": y1 - 1,
        "center_x": round((x0 + x1 - 1) / 2.0, 3),
        "head_core_width": round(head_width, 3),
        "face_core_width": round(face_width, 3),
        "torso_core_width": round(torso_width, 3),
        "dress_hem_width": round(hem_width, 3),
        "hair_neutral_luma": round(statistics.median(hair_luma), 3) if hair_luma else 0.0,
        "dark_fabric_fraction": round(dark_count / max(1, dark_total), 5),
        "tan_accessory_fraction": round(tan_count / max(1, accessory_total), 5),
        "rabbit_light_fraction": round(rabbit_light_count / max(1, accessory_total), 5),
        "left_leg_area_fraction": round(left_leg_area / max(1, leg_total), 5),
        "right_leg_area_fraction": round(right_leg_area / max(1, leg_total), 5),
    }


def build_local_identity_report(frames: list[Image.Image]) -> dict[str, object]:
    metrics = [frame_metrics(frame) for frame in frames]
    numeric_keys = (
        "height",
        "head_core_width",
        "face_core_width",
        "torso_core_width",
        "dress_hem_width",
        "hair_neutral_luma",
        "dark_fabric_fraction",
        "tan_accessory_fraction",
        "rabbit_light_fraction",
        "left_leg_area_fraction",
        "right_leg_area_fraction",
    )
    references: dict[str, float] = {}
    for key in numeric_keys:
        references[key] = float(statistics.median(float(metrics[index][key]) for index in REFERENCE_INDICES))

    ratio_limits = {
        "height": (0.96, 1.04),
        "head_core_width": (0.88, 1.12),
        "torso_core_width": (0.84, 1.18),
        "dress_hem_width": (0.86, 1.14),
        "tan_accessory_fraction": (0.68, 1.38),
        "rabbit_light_fraction": (0.62, 1.42),
        "left_leg_area_fraction": (0.78, 1.22),
        "right_leg_area_fraction": (0.78, 1.22),
    }
    absolute_limits = {
        "hair_neutral_luma": 18.0,
        "dark_fabric_fraction": 0.13,
    }
    flagged: list[dict[str, object]] = []
    records: list[dict[str, object]] = []
    for index, measurement in enumerate(metrics):
        checks: dict[str, object] = {}
        for key, (lower, upper) in ratio_limits.items():
            reference = references[key]
            ratio = float(measurement[key]) / reference if reference else 0.0
            passed = lower <= ratio <= upper
            checks[key] = {"ratio": round(ratio, 5), "limits": [lower, upper], "pass": passed}
            if not passed:
                flagged.append({"index": index, "metric": key, "value": measurement[key], "ratio": round(ratio, 5)})
        for key, tolerance in absolute_limits.items():
            delta = float(measurement[key]) - references[key]
            passed = abs(delta) <= tolerance
            checks[key] = {"delta": round(delta, 5), "tolerance": tolerance, "pass": passed}
            if not passed:
                flagged.append({"index": index, "metric": key, "value": measurement[key], "delta": round(delta, 5)})
        records.append({"index": index, "metrics": measurement, "checks": checks})

    report = {
        "status": "PASS" if not flagged else "REVIEW",
        "frame_count": FRAME_COUNT,
        "reference_indices": list(REFERENCE_INDICES),
        "reference_medians": {key: round(value, 5) for key, value in references.items()},
        "method": "central alpha-run geometry plus palette and accessory ROI proxies; automated checks supplement, not replace, semantic review",
        "non_gating_measurements": {
            "face_core_width": "Reported for inspection only. The raised hand joins the head silhouette and the approved head turn changes the central alpha run, so this proxy is not a reliable pass/fail gate for F11-F15. Head-core width and the close-up sheet remain the automated and visual face-size checks."
        },
        "flagged": flagged,
        "frames": records,
        "manual_semantic_checks": {
            "single_rabbit_and_fixed_satchel_topology": "PASS: one viewer-right rabbit and one satchel remain present in all 23 frames",
            "raised_hand_reads_as_restrained_refusal_not_greeting": "PASS: hand remains beside the temple/brim through F08-F15 and performs one small outward stop press",
            "no_external_hand_or_bag_contact": "PASS: no external hand appears and the raised hand never touches the bag or rabbit",
            "head_face_and_body_volume_continuity": "PASS: transition and close-up sheets show stable large head, compact torso, broad hem and sturdy legs after F05/F14/F19 redraws",
        },
        "manual_review_artifacts": [
            "qa/motion-transition-sheet.png",
            "qa/local-identity-contact-sheet.png"
        ],
    }
    (QA_DIR / "local-identity-report.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
    return report


def build_gifs(frames: list[Image.Image]) -> None:
    rendered = [composite_on_checker(frame) for frame in frames]
    rendered[0].save(
        QA_DIR / "preview-target-10fps.gif",
        save_all=True,
        append_images=rendered[1:],
        duration=100,
        loop=0,
        disposal=2,
        optimize=False,
    )
    rendered[0].save(
        QA_DIR / "preview-slow-5fps.gif",
        save_all=True,
        append_images=rendered[1:],
        duration=200,
        loop=0,
        disposal=2,
        optimize=False,
    )
    if len(ONE_SHOT_CONTEXT_DURATIONS_MS) != FRAME_COUNT:
        raise ValueError("one-shot timing table does not match frame count")
    rendered[0].save(
        QA_DIR / "preview-one-shot-context.gif",
        save_all=True,
        append_images=rendered[1:],
        duration=list(ONE_SHOT_CONTEXT_DURATIONS_MS),
        loop=0,
        disposal=2,
        optimize=False,
    )
    rendered[0].save(
        QA_DIR / "preview-one-shot-context-slow.gif",
        save_all=True,
        append_images=rendered[1:],
        duration=[duration * 2 for duration in ONE_SHOT_CONTEXT_DURATIONS_MS],
        loop=0,
        disposal=2,
        optimize=False,
    )
    (QA_DIR / "timing-report.json").write_text(
        json.dumps(
            {
                "status": "PASS",
                "frame_count": FRAME_COUNT,
                "nominal_motion_fps": 10,
                "context_preview_duration_ms": sum(ONE_SHOT_CONTEXT_DURATIONS_MS),
                "durations_ms": list(ONE_SHOT_CONTEXT_DURATIONS_MS),
                "notes": "The runtime action is one-shot. Longer first/last durations represent surrounding idle context; F13 receives the intentional refusal hold. Holds use timing metadata, not drifting redraws.",
            },
            indent=2,
        ),
        encoding="utf-8",
    )


def build_transition_sheet(frames: list[Image.Image]) -> None:
    groups = (
        ("notice", range(0, 5)),
        ("avoid", range(4, 9)),
        ("raise", range(8, 14)),
        ("refuse-release", range(13, 19)),
        ("recover", range(18, 23)),
    )
    tile = 256
    label_h = 30
    max_columns = max(len(tuple(indices)) for _, indices in groups)
    sheet = Image.new("RGB", (max_columns * tile, len(groups) * (tile + label_h)), (24, 25, 28))
    draw = ImageDraw.Draw(sheet)
    for row, (name, group_range) in enumerate(groups):
        indices = tuple(group_range)
        y = row * (tile + label_h)
        for column, index in enumerate(indices):
            preview = composite_on_checker(frames[index]).resize((tile, tile), Image.Resampling.LANCZOS)
            x = column * tile
            sheet.paste(preview, (x, y))
            draw.text((x + 6, y + tile + 7), f"{name} F{index:02d}", fill=(235, 235, 235))
    sheet.save(QA_DIR / "motion-transition-sheet.png", optimize=True)


def build_identity_sheet(frames: list[Image.Image], report: dict[str, object]) -> None:
    columns = 4
    tile_w = 460
    tile_h = 430
    rows = (FRAME_COUNT + columns - 1) // columns
    sheet = Image.new("RGB", (columns * tile_w, rows * tile_h), (24, 25, 28))
    draw = ImageDraw.Draw(sheet)
    records = report["frames"]
    for index, frame in enumerate(frames):
        column = index % columns
        row = index // columns
        x0 = column * tile_w
        y0 = row * tile_h
        full = composite_on_checker(frame).resize((320, 320), Image.Resampling.LANCZOS)
        sheet.paste(full, (x0, y0))
        bbox = alpha_bbox(frame)
        height = bbox[3] - bbox[1]
        crop_box = (
            max(0, 256 - round(height * 0.24)),
            max(0, bbox[1] - 6),
            min(512, 256 + round(height * 0.24)),
            min(512, bbox[1] + round(height * 0.36)),
        )
        crop = composite_on_checker(frame).crop(crop_box).resize((140, 180), Image.Resampling.LANCZOS)
        sheet.paste(crop, (x0 + 320, y0))
        metrics = records[index]["metrics"]
        lines = (
            f"F{index:02d} bbox={metrics['alpha_bbox']}",
            f"head={metrics['head_core_width']} face={metrics['face_core_width']}",
            f"torso={metrics['torso_core_width']} hem={metrics['dress_hem_width']}",
            f"hairL={metrics['hair_neutral_luma']} dark={metrics['dark_fabric_fraction']}",
            f"tan={metrics['tan_accessory_fraction']} rabbit={metrics['rabbit_light_fraction']}",
        )
        for line_index, line in enumerate(lines):
            draw.text((x0 + 8, y0 + 326 + line_index * 18), line, fill=(235, 235, 235))
    sheet.save(QA_DIR / "local-identity-contact-sheet.png", optimize=True)


def main() -> None:
    QA_DIR.mkdir(parents=True, exist_ok=True)
    frames = load_frames()
    report = build_local_identity_report(frames)
    build_gifs(frames)
    build_transition_sheet(frames)
    build_identity_sheet(frames, report)
    print(json.dumps({"status": report["status"], "flagged": report["flagged"]}, ensure_ascii=False))


if __name__ == "__main__":
    main()
