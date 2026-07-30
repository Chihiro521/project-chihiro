from __future__ import annotations

import importlib.util
from pathlib import Path


ROOT = Path(__file__).resolve().parent
BASE_SCRIPT = ROOT.parent / "seated-loop-v1" / "process_seated_loop.py"
SPEC = importlib.util.spec_from_file_location("sit_rest_seated_loop_processor", BASE_SCRIPT)
if SPEC is None or SPEC.loader is None:
    raise RuntimeError(f"Cannot load processor: {BASE_SCRIPT}")
processor = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(processor)
processor.ROOT = ROOT
processor.KEY_POSES = ROOT.parent
processor.CHROMA = ROOT / "chroma"
processor.ALPHA = ROOT / "alpha"
processor.NORMALIZED = ROOT / "normalized"
processor.QA = ROOT / "qa"
processor.FRAMES = [
    (8, "K06 v3 / F08 contact"),
    (10, "F10 reach support"),
    (12, "F12 supported relax"),
    (14, "F14 supported blink"),
    (16, "F16 release return"),
]
processor.main()
