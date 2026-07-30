from __future__ import annotations

import importlib.util
from pathlib import Path


ROOT = Path(__file__).resolve().parent
BASE_PATH = ROOT.parent / "local_identity_qa.py"
SPEC = importlib.util.spec_from_file_location("sit_rest_scale_v2_local", BASE_PATH)
if SPEC is None or SPEC.loader is None:
    raise RuntimeError(f"Cannot load local QA: {BASE_PATH}")
qa = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(qa)
qa.ROOT = ROOT
qa.FRAMES = ROOT / "frames"
qa.QA = ROOT / "qa"


if __name__ == "__main__":
    qa.main()
