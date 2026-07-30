# Guard Bag Annoyed Palette Revision Contract

## Trigger

The user rejected dynamic v4 because the character becomes visibly darker and lighter between frames.

## Authority hierarchy

- Design and palette authority: `anchors/model-sheet.png`, center front view.
- Standing proportion and measurable palette authority: `key-poses/k00_canonical_reference.png`.
- Motion and contact authorities: the nearest accepted frames on both sides of each repair target.
- A failed frame may be supplied only as a low-detail pose/contact guide. Its surface color, lighting and texture are explicitly rejected.

## Canonical semantic-region measurements

Measured after the established 512x512 normalization, using alpha >= 32:

- Dark dress mean RGB: `(54.149, 57.597, 61.766)`, mean luma `57.165`.
- Gray-beige hair mean RGB: `(198.747, 180.172, 157.349)`, mean luma `182.473`.
- Tan satchel mean RGB: `(189.102, 149.736, 98.050)`, mean luma `154.373`.

## Repair method

1. Repair the first failing frame in temporal order.
2. Generate one fresh complete-character drawing from the immutable authorities.
3. Reject failed attempts instead of applying local or per-frame color correction.
4. Post-process only with the established chroma removal, one uniform complete-character downscale and one whole-layer integer root translation.
5. Re-run palette, proportion, root, texture, chroma, bag and sequence QA after every accepted replacement.

## Local palette gate

- Dress mean-RGB Euclidean distance from canonical: at most `4.5`.
- Hair mean-luma delta from canonical: at most `4.0` absolute.
- Satchel mean-luma delta from canonical: at most `5.5` absolute.
- Adjacent dress mean-luma jump: at most `3.0` absolute.
- Adjacent hair mean-luma jump: at most `3.5` absolute.
- Adjacent satchel mean-luma jump: at most `6.0` absolute.

These numeric checks route redraws and do not replace visual review. No threshold may be widened merely to accept a visibly drifting frame.

## Forbidden repair

No per-frame levels, curves, exposure, hue, saturation, palette transfer, selective recoloring, local paint-over, body-part replacement, compositing, interpolation, morphing, warping or deformation.
