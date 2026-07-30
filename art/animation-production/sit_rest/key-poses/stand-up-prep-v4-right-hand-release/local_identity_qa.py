from __future__ import annotations

import importlib.util
from pathlib import Path


ROOT = Path(__file__).resolve().parent
BASE_SCRIPT = ROOT.parent / "stand-up-prep-v2-left-hand-support" / "local_identity_qa.py"
SPEC = importlib.util.spec_from_file_location("sit_rest_stand_up_v4_local_qa", BASE_SCRIPT)
if SPEC is None or SPEC.loader is None:
    raise RuntimeError(f"Cannot load local QA: {BASE_SCRIPT}")
qa = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(qa)
qa.ROOT = ROOT
qa.NORMALIZED = ROOT / "normalized"
qa.QA = ROOT / "qa"


if __name__ == "__main__":
    qa.main()
