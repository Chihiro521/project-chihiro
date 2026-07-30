from __future__ import annotations

import argparse
import importlib.util
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parent
KEY_POSES = ROOT.parent
BASE_SCRIPT = KEY_POSES / "stand-up-prep-v2-left-hand-support" / "process_stand_up_v2.py"
SPEC = importlib.util.spec_from_file_location("sit_rest_stand_up_v4_base", BASE_SCRIPT)
if SPEC is None or SPEC.loader is None:
    raise RuntimeError(f"Cannot load base pipeline: {BASE_SCRIPT}")
pipeline = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(pipeline)

pipeline.ROOT = ROOT
pipeline.CHROMA = ROOT / "chroma"
pipeline.ALPHA = ROOT / "alpha"
pipeline.NORMALIZED = ROOT / "normalized"
pipeline.QA = ROOT / "qa"
pipeline.FRAMES = [
    (17, "F17 seated authority"),
    (19, "F19 right hand releases strap"),
    (20, "F20 right palm supports"),
    (21, "F21 right hand swings up"),
    (22, "F22 right arm opens outward"),
    (25, "F25 exact stand return"),
]
pipeline.TARGET_VISIBLE_HEIGHTS = {19: 330, 20: 310, 21: 380, 22: 435}


def contact_sheets() -> None:
    label_height = 50
    columns = 3
    rows = 2
    sheet = pipeline.helpers._checkerboard((columns * 512, rows * (512 + label_height)))
    draw = ImageDraw.Draw(sheet)
    font_path = Path("C:/Windows/Fonts/segoeui.ttf")
    font = ImageFont.truetype(str(font_path), 20) if font_path.exists() else ImageFont.load_default()
    frames: dict[int, Image.Image] = {}

    for panel, (index, label) in enumerate(pipeline.FRAMES):
        with Image.open(pipeline.NORMALIZED / f"frame_{index:03d}.png") as source:
            frame = source.convert("RGBA")
        frames[index] = frame
        column = panel % columns
        row = panel // columns
        x = column * 512
        y = row * (512 + label_height)
        sheet.alpha_composite(frame, (x, y + label_height))
        draw.text((x + 14, y + 13), label, fill=(245, 245, 245, 255), font=font)
    pipeline.helpers._save_png(sheet, pipeline.QA / "stand-up-v4-contact-sheet.png")

    hand_indices = (19, 20, 21, 22)
    crop_box = (0, 170, 280, 512)
    crop_size = (392, 479)
    close = pipeline.helpers._checkerboard((len(hand_indices) * crop_size[0], crop_size[1] + label_height))
    close_draw = ImageDraw.Draw(close)
    labels = {19: "F19 release", 20: "F20 palm support", 21: "F21 upswing", 22: "F22 outward"}
    for panel, index in enumerate(hand_indices):
        crop = frames[index].crop(crop_box).resize(crop_size, Image.Resampling.LANCZOS)
        x = panel * crop_size[0]
        close.alpha_composite(crop, (x, label_height))
        close_draw.text((x + 12, 13), labels[index], fill=(245, 245, 245, 255), font=font)
    pipeline.helpers._save_png(close, pipeline.QA / "right-hand-contact-closeup.png")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("stage", choices=("standardize", "normalize", "contact", "slow", "all"))
    args = parser.parse_args()
    if args.stage in ("standardize", "all"):
        pipeline.standardize_sources()
    if args.stage in ("normalize", "all"):
        pipeline.normalize()
    if args.stage in ("contact", "all"):
        contact_sheets()
    if args.stage in ("slow", "all"):
        pipeline.slow_preview()


if __name__ == "__main__":
    main()
