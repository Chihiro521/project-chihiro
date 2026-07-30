# guard_bag_annoyed key-pose contract

- Action: restrained one-shot after a poke; a tiny startle becomes protective guarding and controlled annoyance, then returns to neutral.
- Facing: front, fixed orthographic camera.
- Sequence plan: 15 complete-character frames at 6 FPS, non-looping, in place.
- Production gate: generate and review only five keys now: K02 startle, K04 guard start, K07 guard peak, K09 annoyed hold, K12 recovery transition.
- Generation: one independent 1024x1024 complete-character image per call on flat `#FF00FF`; no interpolation, optical flow, local translation, part compositing, warping, cross-fade or morphing.
- Final cell: 512x512 RGBA PNG, fixed pivot `(256,492)`, visible shoe baseline `y=472`, no per-frame trimming.
- Canonical side: the satchel remains on Chihiro's left hip (viewer right). Her left hand and forearm protect the intact satchel and single rabbit. Her right hand gives the small palm-out stop gesture.
- Emotional arc: brief mild surprise -> alert protection -> narrowed, dry displeasure -> residual wary glance -> neutral. No rage, scream, attack or theatrical recoil.
- Identity authority: `anchors/canonical_idle_chroma.png` and `key-poses/k00_canonical_reference.png`; `anchors/character_front.png` and `anchors/model-sheet.png` are supporting original-design references.

## Key poses

| Key | Phase | Body and contact | Expression and silhouette |
|---|---:|---|---|
| K02 startle | 0.143 | Feet planted; shoulders rise slightly; chin retracts; right hand tightens near strap; left fingertips contact outer satchel edge. | Compact inward recoil, subtly wider eyes, tiny parted mouth. |
| K04 guard start | 0.286 | Left hand and forearm begin drawing the attached bag and rabbit inward; right hand leaves strap with elbow tucked. | Alert side-eye; narrow silhouette expansion only at bent sleeves. |
| K07 guard peak | 0.500 | Left forearm cradles the intact bag at the left-front lower torso; right palm faces outward near sternum; torso turns away no more than five degrees. | Clear protect/stop read, guarded rather than aggressive. |
| K09 annoyed hold | 0.643 | Bag contact remains firm; right palm stays small and controlled, fingers together and elbow close. | Half-lidded wary eyes, slightly lowered brow, tiny dry displeased mouth. |
| K12 recovery | 0.857 | Right hand lowers toward strap; left arm releases; attached bag settles toward canonical hip; shoulders descend. | One residual side-eye; silhouette nearly neutral. |

## Hard identity locks

Hat, cool gray-beige low-luminance hair, rounded face and head size, four-head-tall compact proportions, skirt length, leg thickness, shoes, collar, orange bow, approved brass buttons, lace hem, strap path, one satchel and one rabbit cannot change. The bag, strap and rabbit cannot deform, detach, multiply or swap sides.

## Revision 2: grounded proportion lock

- User review found small apparent height changes and an overly airy weight read in the first key-pose pass.
- K04 and K07 are fully redrawn against the canonical hat-top, eye, shoulder, skirt-hem, knee, sock-seam and shoe-sole landmarks.
- K09 is fully redrawn from the repaired K07 body as an expression-only held beat, preventing body scale and garment volume from changing during the annoyed pause.
- Automated proportion QA now locks total visible height and requires the detected skirt-hem transition to remain within 3 pixels of the canonical reference.
- Both shoes remain planted on the same baseline; the skirt hangs downward with no wind, lift or secondary flutter in these keys.

## Revision 3: K09 canonical hair lock

- User review found that K09 had drifted toward pale, high-luminance hair.
- K09 is fully redrawn with pose, expression, body, costume, bag and rabbit locked; only the hair palette changes.
- The corrected hair uses the canonical matte cool ash-beige/gray-beige value range, with muted highlights and darker ash shadow masses.
- A dedicated hair-color QA proxy now compares fixed raw-source hair regions against the canonical anchor and requires mean luminance drift to stay within 8 levels.

## Revision 4: K09 clean base redraw

- User review found visible moire and accumulated high-frequency texture in the edited K09.
- K09 is freshly redrawn from the original three-view model sheet and original approved front view. No previous action frame is used as an identity, palette or rendering source.
- The earlier normalized K09 is used only as a low-resolution pose/contact guide; all surface pixels and texture are explicitly rejected.
- Navy fabric, hat, hair and accessories use smooth low-frequency fills with broad cel-shading masses and no weave, crosshatching, dithering, grain or repeated interference pattern.
- Texture QA compares dark-navy high-frequency residual against both the canonical reference and rejected K09; the clean redraw must improve over the rejected frame and stay within 105 percent of canonical residual energy.
