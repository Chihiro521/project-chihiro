# sit_rest scale stabilization v2

## Trigger

- User semantic review: several middle frames visibly become larger or smaller.
- Strict audit confirmed scale pops at `F02->F03`, `F07->F08`, `F19->F20`, and `F21->F22`.
- The approved seated block measured about 90-91 px head width versus the 107 px standing authority.

## Repair boundary

- Keep every complete character drawing and pose unchanged.
- Re-normalize only by one uniform whole-frame scale plus one whole-frame translation.
- Use the standing authority head width `107 px` as the fixed camera-scale landmark for every frame.
- Keep head center `x=256`, visible baseline `y=472`, final cell `512x512`, pivot `(256,492)`.
- Read every available 1024x1024 alpha source directly to avoid repeated downsampling.
- Keep `F00` and `F25` byte-identical.

## Forbidden

- No limb or accessory translation, part compositing, crop-to-content, warping, deformation, morphing, optical flow, cross-fade, or redrawing.
- No pose, garment, contact, palette, texture, or topology change.

## Gate

- Head-width range across all 26 normalized frames: at most 2 px.
- Adjacent head-width jump: at most 2 px.
- Head-center range: at most 1.5 px.
- Visible baseline range: exactly 0 px.
- Generic sequence QA, local identity/material QA, guided contact sheets, target preview, and slow preview must all be rebuilt.
- Production state: `automated_qa_pass_pending_user`.
