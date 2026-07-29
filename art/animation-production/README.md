# Little Chihiro animation production

This folder holds approval and QA artifacts for new v0.21 frame sequences.

- `character-reference/model-sheet.png` is generated from existing approved frames.
- `character-reference/identity-lock.json` freezes visible character invariants.
- Each action owns a copied `sprite-sequence.json`, key frames, in-betweens and `qa/` output.
- No generated frame enters `skins/little-chihiro/animations/` until automated QA and semantic review both pass.

## Accepted sequences

- `idle_breathe`: eight phases at 4 FPS, fixed 512×512 cells and pivot `(256, 492)`. It reuses the approved front anchor through a Godot CanvasItem UV deformation so character identity and costume pixels do not drift. Automated QA and user semantic review passed; the approved anchor's intentional padding is documented by `min_alpha_coverage: 0.17`. The fixed-grid sheet and metadata live in `idle_breathe/package/`.
- `look_around`: twelve directed poses at 6 FPS, fixed 512×512 cells and pivot `(256, 492)`. It reorders existing approved gaze frames into a left/right scan with one centered blink, so no production pixels are redrawn. Automated QA and user semantic review passed; package artifacts live in `look_around/package/`.
- `straighten_bag`: ten directly generated, non-interpolated poses at 6 FPS, fixed 512×512 cells and pivot `(256, 492)`. Automated QA and user semantic review passed; chroma-edge despill preserves the approved alpha matte exactly. Package artifacts live in `straighten_bag/package/`.
- `inspect_rabbit`: fifteen directly generated, non-interpolated poses at 6 FPS, fixed 512×512 cells and pivot `(256, 492)`. The action lifts the rabbit, extends the cheek-to-ear-to-crown petting beat, and places it back on the satchel. Automated QA and user semantic review passed; package artifacts live in `inspect_rabbit/package/`.
- `stretch`: seventeen directly generated, non-interpolated poses at 6 FPS, fixed 512×512 cells and pivot `(256, 492)`. The action raises both arms, briefly curls both hands into small relaxed fists, then lowers them and returns to idle. Automated QA and user semantic review passed; package artifacts live in `stretch/package/`.
