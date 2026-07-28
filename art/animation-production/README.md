# Little Chihiro animation production

This folder holds approval and QA artifacts for new v0.21 frame sequences.

- `character-reference/model-sheet.png` is generated from existing approved frames.
- `character-reference/identity-lock.json` freezes visible character invariants.
- Each action owns a copied `sprite-sequence.json`, key frames, in-betweens and `qa/` output.
- No generated frame enters `skins/little-chihiro/animations/` until automated QA and semantic review both pass.
