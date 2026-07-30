# sit_rest direct-frame contract

## Output

- Action: `sit_rest`
- Facing and camera: front-facing, orthographic, fixed neutral camera
- Duration, FPS, and frame count: 26 frames at 6 FPS
- Loop or segments: enter `F00-F07`; repeatable seated loop `F08-F17`; exit `F18-F25`
- Generation size and final cell: one complete 1024x1024 drawing per generated frame, normalized to 512x512
- Pivot and baseline policy: pivot `(256,492)` and visible baseline `y=472`; no per-frame crop
- Production state: `scale_stabilized_v2_automated_qa_pass_pending_user`

## Authorities

- Design authority: `../../character-reference/model-sheet.png` and `../../character-reference/identity-lock.json`
- Standing proportion authority: `../key-poses/transition-keys-v1/normalized/frame_000.png`
- Additional pose-family authorities: descent `F04`; seated `F08`; selected rise v1 `F19-F22`
- Authority rule: temporal neighbors control motion and contacts only; they never replace design or proportion authority.

## Identity and material locks

- Head and face: approved rounded face, muted blue-gray eyes, ash-beige bob, fixed head width and approximately four-head-tall character
- Body and limb proportions: compact torso, sturdy legs, unchanged leg thickness, no lateral body narrowing
- Hair or fur palette and highlight level: low-luminance gray-beige hair; no bright blond shift or washed highlights
- Garment topology and landmarks: one continuous navy A-line dress, cream collar, orange bow, three brass buttons, one uninterrupted cream lace hem
- Shoes and ground contact: two complete cream socks and two black Mary Jane shoes; both soles remain anatomically connected and visibly support weight
- Accessories and companion objects: one tan cross-body strap, one satchel on viewer-right, one attached white rabbit with orange bow; route and count remain fixed
- Line, shading, texture, camera, and light: approved soft anime-game rendering, restrained texture, neutral light, no cast shadow

## Action arc

| Beat | Frame or range | Pose family | Motion and expression | Contact and occlusion |
|---|---:|---|---|---|
| anticipation | F00-F03 | standing to shallow crouch | gaze lowers, knees soften, free hand opens slightly | both soles remain planted |
| descent | F04-F07 | deep crouch to floor sit | pelvis lowers behind knees; thighs foreshorten; shins extend forward | skirt remains one connected front panel over both thighs |
| seated rest | F08-F17 | approved seated family | user-approved rabbit pat, blink, and withdrawal | approved loop is frozen byte-for-byte |
| rise preparation | F18-F20 | seated to loaded crouch | torso pitches forward; feet draw under knees; both legs accept weight | both planted soles become the support base |
| rise | F21-F24 | crouch to standing | two-leg push, hips and torso rise, skirt falls back to A-line | selected v1 F19-F22 are frozen |
| recovery | F25 | standing | exact visual return to F00 | F25 is byte-identical to F00 |

## Contact ledger

| Object | Count and side | Attachment or owner | Contact points | Occlusion order | Allowed secondary motion |
|---|---|---|---|---|---|
| cross-body strap | one, shoulder to viewer-right hip | held by strap hand | hand remains naturally around strap except slight balance relaxation | strap stays in front of dress | slight slack from torso pitch |
| satchel | one, viewer-right | attached to strap | rests beside hip/thigh | in front of skirt edge, behind rabbit | restrained gravity swing only |
| rabbit | one, attached to satchel | satchel front | remains attached throughout | in front of satchel | tiny passive response only |
| shoes | two | feet | soles contact implied ground | in front of socks | ankle rotation and foreshortening only |

## Motion boundary

- Allowed motion: root height, hip/knee/ankle flexion, torso pitch, mild free-hand balancing, perspective-correct skirt pooling and recovery
- Forbidden changes: interpolation, optical flow, warping, part compositing, local limb translation, body slimming, face resizing, bright hair, missing limbs, knee holes, split skirt, detached bag/rabbit, extra props, scenery, shadow, text, watermark
- Intentional holds and timing metadata: seated rest timing is expressed by the approved `F08-F17` drawings; no duplicate synthetic holds
- Segment seams to inspect: `F07->F08`, `F17->F18`, `F18->F19`, `F22->F23`, `F24->F25`

## Key approval gate

- Planned key poses: F00, F04, F08, F19-F22, F25
- Key contact sheet: `../key-poses/transition-keys-v1/qa/transition-key-contact-sheet.png` and `../key-poses/stand-up-prep-v1/qa/stand-up-prep-contact-sheet.png`
- Automated key report: PASS
- User verdict and date: seated loop and stand-up-prep-v1 accepted on 2026-07-30; remaining direct frames authorized on 2026-07-30
- Approved keys are frozen: `yes`

## Full-sequence gate

- Generic QA report: `scale-stabilized-v2/qa/automated/qa-report.json` (`PASS`)
- Local identity/material report: `scale-stabilized-v2/qa/local-identity-report.json` (`PASS`)
- Scale continuity report: `scale-stabilized-v2/qa/scale-continuity-report.json` (`PASS`; head width 107-108 px, maximum adjacent delta 1 px)
- Target-FPS preview: `scale-stabilized-v2/qa/preview.gif`
- Slow preview: `scale-stabilized-v2/qa/preview-slow.gif`
- Close-up identity/contact sheet: `scale-stabilized-v2/qa/scale-continuity-head-sheet.png` and guided enter/exit contact sheets
- User verdict and date: pending
- Ready for engine integration: `no`
