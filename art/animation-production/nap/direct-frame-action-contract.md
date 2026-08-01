# nap direct-frame contract

## Output

- Action: tired standing preparation -> floor-sitting descent -> stable doze -> subtle sleeping-breath loop -> interrupted wake -> standing recovery
- Facing and camera: front-facing orthographic game-sprite camera; no camera change
- Duration, FPS, and frame count: `nap_enter` 8 frames, `nap_loop` 8 frames, `nap_wake` 14 frames; 30 complete drawings total at 6 FPS, with loop hold timing supplied by metadata rather than duplicate drawings
- Loop or segments: `nap_enter` frames 000-007, `nap_loop` frames 008-015 and loops on `[0, 1)`, `nap_wake` frames 016-029
- Generation size and final cell: every source is generated independently at 1024x1024 on flat `#FF00FF`, then uniformly normalized to a fixed 512x512 RGBA cell
- Pivot and baseline policy: fixed pivot `(256, 492)`; standing and seated ground contacts target visible baseline y=472; root descends inside the fixed cell without trimming
- Production state: `automated_qa_pass_final_user_review_pending`

## Authorities

- Design authority: `../character-reference/model-sheet.png` and `../character-reference/identity-lock.json`
- Standing proportion authority: `../return_wave/anchors/reason_pose_frame_000_chroma.png`, cross-checked against `../return_wave/frames/frame_000.png`
- Additional pose-family authorities: key K08 is the approved sleeping/floor-sitting proportion authority; K00/K29 remain governed by the standing authority
- Authority rule: temporal neighbors control motion and contacts only; they never replace design or proportion authority.

## Identity and material locks

- Head and face: preserve the broad rounded head and face dimensions, fringe, muted blue-gray eyes, cheek placement and compact roughly four-head-tall identity; eyelids and a small sleepy mouth may change only with the declared beat
- Body and limb proportions: preserve torso volume, shoulder width, arm thickness, thigh/calf thickness and small sturdy feet; sitting foreshortening must not slim the body or hide limbs implausibly
- Hair or fur palette and highlight level: matte dark ash-beige hair matching the original, with restrained highlights; never pale, bright gold, washed out or high-contrast striped
- Garment topology and landmarks: one connected deep-navy A-line dress, cream Peter Pan collar, orange ribbon, three brass buttons, puffed cuffs and continuous cream lace hem; sitting fabric gathers under gravity without becoming a different garment
- Shoes and ground contact: both black Mary Jane shoes and both cream socks remain present; standing feet share the approved spacing, while the sleeping family keeps two believable folded legs and a stable floor contact without drawing a floor
- Accessories and companion objects: tan strap stays continuous across the torso to one viewer-right satchel; exactly one rabbit remains attached to the satchel front with its orange bow, never held, duplicated, mirrored or detached
- Line, shading, texture, camera, and light: fine dark outlines, restrained warm cel shading, smooth navy fabric without moire, fixed orthographic camera, neutral light, no shadow or scenery

## Action arc

| Beat | Frame or range | Pose family | Motion and expression | Contact and occlusion |
|---|---:|---|---|---|
| fatigue preparation | 000-001 | standing | shoulders soften, eyelids grow heavy, chin lowers slightly while feet remain planted | strap remains in front of dress; right hand may loosen but does not release topology |
| lowering and sitting | 002-007 | standing -> crouch -> floor-sitting | knees bend and root descends through 003; at 004 the paired F07-authority seated leg pose is established and held through 007 while the hands, eyelids and head continue settling | both shoes retain the same far-upper-left / near-lower-right ordering from 004 through 007; satchel settles at viewer-right without detaching |
| sleep master | 008 | sleeping/floor-sitting | compact seated doze, eyes closed, chin gently lowered, shoulders relaxed | hands rest together on the lap; rabbit remains fixed on the bag; no rabbit embrace |
| sleeping breath | 009-015 | sleeping/floor-sitting | subtle chest/shoulder rise and fall, tiny head nod and minimal rabbit-ear response; no pose redesign | pelvis/root and floor contacts remain fixed; strap and bag maintain the same occlusion order |
| interrupted wake | 016-017 | sleeping/floor-sitting | eyelids open slowly into a heavy, unfocused gaze; head lifts only slightly | bag stays beside viewer-right hip; no external hand or prop enters the frame |
| eye rub | 018-020 | sleeping/floor-sitting | one hand rises to rub one eye with relaxed knuckles, then begins travelling toward the mouth; the other hand remains on the lap | raised hand stays in front of face and never crosses through hair, strap or collar |
| small yawn | 021-022 | sleeping/floor-sitting | the same hand lightly covers a small restrained yawn; eyelids narrow again, then the hand lowers | mouth opening remains small and partly hidden by the hand; no exaggerated stretch |
| rise preparation | 023 | sleeping/floor-sitting -> forward lean | both hands leave the face, feet prepare for load and torso inclines forward | bag remains beside the hip while strap gains only natural slack |
| rise and recovery | 024-029 | floor-sitting -> crouch -> standing | weight transfers through feet, legs extend, dress falls back into the standing silhouette and expression returns to composed neutral | both shoes regain the standing baseline; strap, satchel and rabbit return without popping |

## Contact ledger

| Object | Count and side | Attachment or owner | Contact points | Occlusion order | Allowed secondary motion |
|---|---|---|---|---|---|
| cross-body strap | one, descending to viewer-right | permanently connected to satchel | shoulder/chest route and both satchel attachment points remain continuous | strap in front of dress and behind any crossing hand | small slackening while sitting, then recovery |
| satchel | one, viewer-right | connected to the strap | rests beside the right hip/thigh in standing and beside the seated hip on the implied floor | in front of the lower dress edge where overlapping | small gravity-driven settle only |
| rabbit charm | exactly one on satchel front | fixed to satchel | attachment point never changes | in front of satchel; limbs may overlap the bag only naturally | tiny delayed ear/body response to breathing or wake, no independent action |
| hands | exactly two | character arms | standing strap-side hand relaxes; both hands end resting naturally on lap during sleep | hands in front of dress/lap, never fused with strap or rabbit | fingers relax, tense on wake, and return to neutral |
| legs and shoes | two legs, two socks, two shoes | body | planted -> fold into seated support -> planted | dress may overlap upper legs but must not erase or duplicate limbs | declared weight transfer only |

## Motion boundary

- Allowed motion: eyelids, gaze, small mouth change, head pitch, shoulders, elbows, wrists and fingers including one restrained eye rub and hand-covered yawn, hip/knee/ankle flexion, root descent/rise, gravity-driven dress/strap/bag/rabbit response
- Forbidden changes: no body slimming, small-face drift, thin legs, bright hair, costume redesign, missing buttons, changed bag side, detached or duplicated rabbit, rabbit holding, pillow, blanket, furniture, sleep symbols, scenery, floor plane, shadow, text, watermark, crop, optical flow, interpolation, morph, cross-fade, warp, translated parts or compositing
- Intentional holds and timing metadata: the approved sleeping master may receive a longer frame duration in the engine; do not create several near-duplicate hold drawings
- Segment seams to inspect: 007->008 enter-to-loop, 015->008 loop seam, 015->016 loop-to-wake, eye-rub hand path 017->018->020, yawn path 020->021->022, rise preparation 022->023->024, and 028->029 return to standing neutral

## Key approval gate

- Planned key poses: K00/frame 000 tired standing preparation; K04/frame 004 lowered center/first seated contact; K08/frame 008 sleeping pose-family mother; K12/frame 012 opposite breathing phase; K16/frame 016 interrupted sleepy wake; K18/frame 018 one-hand eye rub; K21/frame 021 small hand-covered yawn; K23/frame 023 forward rise preparation; K29/frame 029 recovered standing endpoint
- Key contact sheet: `key-qa/nap-key-contact-sheet.png`
- Automated key report: `key-qa/key-geometry-report.json` (`PENDING_SEMANTIC_REVIEW`; all nine keys are 512x512 RGBA with baseline y=472)
- User verdict and date: accepted by user on 2026-07-30, including the added sleepy-eye-open -> eye-rub -> small-yawn -> rise-preparation wake arc
- Approved keys are frozen: `yes`

## Full-sequence gate

- Generic QA report: `qa/qa-report.json` (`PASS`)
- Local identity/material report: `qa/local-identity-report.json` (`PASS`)
- Drift repair: frames 001, 002, 007, 014 and 024-027 were freshly redrawn as complete figures; the entire seated family was re-normalized to the standing world scale. Sleep head width is stable at 110 +/- 1 px and the rise silhouette height is monotonic.
- Leg-continuity follow-up (2026-07-31): frame 007 was freshly redrawn between frames 006 and 008 to establish the accepted paired-leg topology.
- Leg-pose synchronization (2026-07-31): frames 004, 005 and 006 were then freshly redrawn as complete figures using frame 007 as the lower-body authority. F04/F05/F06/F07 heights are 311/315/309/307 px, head widths are 108/107/108/107 px, and all four retain the same far-upper-left / near-lower-right shoe ordering. Review artifacts: `qa/leg-continuity-contact-sheet.png`, `qa/nap-enter-slow-3fps.gif`, `key-qa/nap-key-contact-sheet.png`.
- Target-FPS preview: `qa/nap-preview-6fps.gif`
- Slow preview: `qa/nap-preview-slow-3fps.gif`
- Sleep-loop preview: `qa/nap-loop-6fps.gif`
- Full contact sheet: `qa/contact-sheet.png`
- Close-up identity/contact sheets: `qa/local-identity-contact-sheet.png`, `qa/material-contact-sheet.png`
- User verdict and date: pending
- Ready for engine integration: `no`
