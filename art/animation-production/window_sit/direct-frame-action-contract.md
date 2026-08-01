# window_sit direct-frame contract

## Output

- Action: window-edge sitting, quiet seated observation, and standing recovery (`window_sit_enter` / `window_sit_loop` / `window_sit_exit`)
- Facing and camera: front-facing orthographic camera; only restrained torso and gaze turns inside the loop
- Duration, FPS, and frame count: 32 planned frames at 6 FPS; enter 8, loop 16, exit 8
- Loop or segments: frames 0-7 enter; frames 8-23 repeatable loop; frames 24-31 exit; the combined review sequence is non-looping
- Generation size and final cell: one complete 1024x1024 drawing per call on flat `#FF00FF`, normalized uniformly to fixed 512x512 RGBA
- Pivot and baseline policy: fixed engine pivot `(256,492)` and visible bottom near `y=472`; no per-frame crop; no horizontal root travel
- Platform-contact policy: the invisible platform contact transfers from shoe soles near `y=472` in standing frames to the normalized seated pelvis/skirt compression point near `y=350` in the loop. Per-frame contact coordinates will be recorded for Godot vertical compensation; the artwork itself remains x-centered.
- Production state: `continuous_frames_ready_for_user_review`

## Authorities

- Design authority: `../character-reference/model-sheet.png` and `../character-reference/identity-lock.json`
- Standing proportion authority: `../return_wave/anchors/reason_pose_frame_000_chroma.png` plus `../return_wave/frames/frame_000.png`
- Seated proportion guide only: `../sit_rest/direct-frames-v1/scale-stabilized-v2/frames/frame_008.png`
- Additional pose-family authority: a new user-approved window-edge stable seated key will become the sole window-seated proportion authority after key review
- Authority rule: temporal neighbors and the floor-sit guide control motion/contact ideas only; they never replace the original design authority or standing/window-seated proportion authorities.

## Identity and material locks

- Head and face: preserve the broad rounded head and face, fixed muted blue-gray eyes, fringe geometry, eye spacing and small restrained mouth; no face shrinking between standing, seated and leaning keys.
- Body and limb proportions: preserve the approximately four-head-tall compact identity, broad dress volume, sturdy short thighs/calves, sock cylinders, shoe size and hand size; sitting changes joint angles and depth, never body thickness.
- Hair palette and highlight level: dark muted ash-beige/gray-beige matching the original; no bright blond, white-gold highlights, washed-out grading or texture accumulation.
- Garment topology and landmarks: one continuous navy dress, cream Peter Pan collar, orange ribbon, three brass-button layout, loose sleeves, uninterrupted cream lace hem; sitting gathers the same garment around the pelvis and upper thighs without split panels or knee holes.
- Shoes and contact: two cream socks and two black Mary Jane shoes remain fully readable. Standing begins/ends on both soles; seated legs pass over the invisible edge and hang downward without fused ankles or disappearing footwear.
- Accessories and companion objects: one tan cross-body strap follows its original shoulder-to-viewer-right route; one compact satchel stays on viewer-right; one white rabbit with one orange bow remains attached to the satchel front and hangs with gravity.
- Line, shading, texture, camera, and light: fine dark outline, restrained warm cel shading, smooth low-frequency navy cloth, original subdued hair highlights, fixed orthographic camera, neutral light, no shadow or scene.

## Action arc

| Beat | Frame or range | Pose family | Motion and expression | Contact and occlusion |
|---|---:|---|---|---|
| standing anticipation | 0-1 | standing | neutral stance notices the edge, gaze lowers slightly | both shoe soles own platform contact; bag and rabbit hang viewer-right |
| controlled descent | 2-5 | standing-to-edge transition | knees flex, pelvis moves backward/down, free hand opens beside the hip for balance | contact transfers from both soles toward pelvis; skirt stays one connected volume over thighs |
| first seated contact | 6-7 | edge-seated transition | pelvis reaches the implied edge, legs pass over it and begin hanging | pelvis/skirt compression becomes primary support; both lower legs remain visible below the common hem |
| stable seated master | 8 | window-edge seated | upright compact seat, legs naturally dangling, right hand controls strap, free hand rests/braces beside the opposite hip | seated contact fixed near `(256,350)` after normalization; platform remains invisible; bag/rabbit vertical beside viewer-right thigh |
| small leg swing | 9-13 | window-edge seated | one restrained forward/back leg swing with tiny gaze response | pelvis and torso root remain fixed; shoes never collide or merge; skirt hem reacts minimally |
| return through center | 14-16 | window-edge seated | both legs settle and shoulders return to neutral | stable contact and strap route remain unchanged |
| brief side lean / observation | 17-20 | window-edge seated lean | torso shifts a little toward the free bracing hand, head turns slightly to observe below, never a large recline | free palm owns the implied edge support; pelvis stays seated; strap hand prevents the bag from sliding |
| loop recovery | 21-23 | window-edge seated | torso and gaze return to the exact stable seated family | frame 23 approaches frame 8 without duplicating it; contact and gravity reset cleanly |
| rise preparation | 24-27 | edge-seated-to-standing transition | torso comes forward, feet draw under the body, legs accept weight and pelvis lifts | support transfers from pelvis to both soles; dress stays connected and bag remains controlled |
| standing recovery | 28-31 | standing | knees extend, torso settles, hands and expression return to neutral | frame 31 visually returns to the standing authority with both soles on the platform |

## Contact ledger

| Object | Count and side | Attachment or owner | Contact points | Occlusion order | Allowed secondary motion |
|---|---|---|---|---|---|
| invisible window top edge | one horizontal support, not rendered | environment support | standing shoe soles -> seated pelvis/skirt compression -> standing shoe soles | no edge pixels may appear; its implied line passes behind skirt and in front of dangling upper legs | none; only the declared contact ownership changes |
| free hand | one, viewer-left side | character | opens near hip during descent; lightly braces beside hip during lean; releases before rise | hand may pass in front of sleeve/skirt but never behind the whole torso | small wrist/finger settling only |
| strap hand | one, near upper torso | character | maintains or briefly slides along the tan strap | hand in front of strap/dress; strap continues uninterrupted to bag | small controlled slide during sit/rise |
| satchel | one, viewer-right | tan strap | remains beside right hip/thigh and hangs below the strap | bag in front of dress edge; behind the rabbit body | small gravity lag and restrained sway |
| rabbit | exactly one, viewer-right bag front | attached to satchel | remains attached and vertical; never held separately | rabbit in front of bag; ears may overlap dress edge but do not detach | tiny delayed ear/body sway only |
| dress and lace hem | one continuous garment | torso/pelvis | gathers over seated pelvis and both upper thighs | continuous front panel covers upper thighs; two lower legs emerge below one common hem | restrained folds and hem lag, no split or knee holes |
| legs, socks and shoes | two | pelvis/knees/ankles | soles support standing; thighs cross implied edge; lower legs hang below in loop | left/right depth remains readable; no fused socks, ankles or shoes | small pendulum swing around knees in loop |

## Motion boundary

- Allowed motion: vertical root descent/rise inside the fixed cell, hip/knee/ankle articulation, small seated leg swing, restrained torso weight shift, tiny head/gaze turn, hand bracing/release, gravity-correct dress/bag/rabbit secondary response.
- Forbidden changes: no visible window/platform line, chair, floor, shadow, scenery, text or effects; no whole-character horizontal drift; no floor-sit pose, compressed standing pose, giant head, small face, thin body/legs, bright hair, dress split, knee holes, fused limbs, missing footwear, mirrored/detached bag, duplicate rabbit, rerouted strap, extra anatomy, per-frame trim, local compositing, warp, morph, optical flow or interpolation.
- Intentional holds and timing metadata: stable seated frame may receive timing hold metadata after approval; do not manufacture holds with drifting near-duplicate drawings.
- Segment seams to inspect: F07->F08 enter-to-loop contact; F23->F08 loop seam; F23->F24 loop-to-exit; F31->standing idle return.
- Godot integration note: stable seated platform contact is materially above the fixed sprite pivot. The final sequence must export per-frame platform-contact Y metadata so the controller can preserve the window-top world coordinate while contact transfers between feet and pelvis.

## Key approval gate

- Planned key poses: K00 standing authority; K04 deep controlled descent; K08 stable window-edge seated mother; K12 small leg-swing peak; K19 restrained side-lean observation; K27 rise/load; K31 standing return authority
- Key contact sheet: `key-poses/qa/window_sit-key-contact-sheet.png`
- Automated key report: `key-poses/qa/automated/qa-report.json` — `PASS`
- Local identity/material report: `key-poses/qa/local-identity-report.json` — `PASS`; maximum head-width delta 3 px and hair-luma delta 2.104 after the K27 repair
- Normalization report: `key-poses/qa/normalization-report.json` — `PASS`; whole-canvas downsample and whole-frame translation only
- Producer semantic review: `PASS_FOR_USER_REVIEW`; K08/K12/K19 preserve one seated support family and K12 reads as a small single-leg swing. User rejected the first K27 because its feet splayed into a wide squat and its free arm reached forward. The replacement keeps both feet close and parallel below the knees, leans the torso over them, lifts the pelvis only slightly, and keeps the free hand beside the hip for the final edge push. Rejected K19 and K27 candidates are excluded from every reference chain.
- User verdict and date: `通过，可以做连续帧了。` — 2026-07-30
- Approved keys are frozen: `yes`

## Full-sequence gate

- Normalization report: `direct-frames-v1/qa/normalization-report.json` — `PASS`; 32/32 frames present
- Generic QA report: `direct-frames-v1/qa/automated/qa-report.json` — `PASS`; zero failures and zero warnings
- Local identity/material report: `direct-frames-v1/qa/local-identity-report.json` — `PASS`; maximum head-width delta 9 px, face-width delta 8 px, hair-luma delta 8.320 and green/cyan fringe count 9 px
- Full contact sheet: `direct-frames-v1/qa/window_sit-full-contact-sheet.png`
- Target-FPS preview: `direct-frames-v1/qa/preview.gif` — 6 FPS
- Slow preview: `direct-frames-v1/qa/preview-slow.gif` — half speed
- Fixed-window-top review: `direct-frames-v1/qa/preview-world-contact.gif` and `preview-world-contact-slow.gif`
- Close-up identity sheet: `direct-frames-v1/qa/local-identity-contact-sheet.png`
- Platform-contact metadata: `direct-frames-v1/qa/support-contact-curve.json`
- Producer semantic review: `PASS_FOR_USER_REVIEW`; three independent segment reviews passed after repairing enter-scale drift, support-transfer poses, F17 scale, the F23-to-F08 loop seam and the F28-to-F31 rise scale.
- User verdict and date: pending
- Ready for engine integration: `no`
