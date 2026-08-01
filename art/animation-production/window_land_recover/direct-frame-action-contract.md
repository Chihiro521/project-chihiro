# window_land_recover direct-frame contract

## Output

- Action: window top-edge landing and recovery (`window_land_recover`)
- Facing and camera: front-facing orthographic sprite; only a very small natural torso tilt during impact absorption
- Duration, FPS, and frame count: 1.875 seconds, 8 FPS, 15 complete independently drawn frames
- Loop or segments: non-looping one-shot; descent -> first contact -> impact absorption -> stabilization -> recovered standing
- Generation size and final cell: generate each whole character at 1024x1024 on flat `#FF00FF`; normalize uniformly into a fixed 512x512 RGBA cell
- Pivot and baseline policy: fixed pivot `(256, 492)`; airborne and compression beats may move vertically inside the cell, so sequence baseline lock is disabled; recovered standing must return both soles to the standing-authority baseline
- Production state: `automated_qa_pass`; awaiting full-sequence semantic acceptance

## Authorities

- Design authority: `../character-reference/model-sheet.png` and `../character-reference/identity-lock.json`
- Standing proportion authority: `../return_wave/anchors/reason_pose_frame_000_chroma.png` plus `../return_wave/frames/frame_000.png`
- Additional pose-family authorities: key K00 will become the airborne authority and key K06 will become the impact-compression authority only after explicit user acceptance
- Authority rule: temporal neighbors control motion and contacts only; they never replace design or proportion authority.

## Identity and material locks

- Head and face: preserve the large rounded head, face width and height, muted blue-gray eyes, fixed fringe and small ash-beige bob; no face shrinking during crouch or recovery
- Body and limb proportions: preserve the approximately four-head-tall compact build, torso thickness, short sturdy thighs and calves, sock cylinders, shoe size and foot spacing; impact flexion changes joint angles, not limb thickness
- Hair or fur palette and highlight level: matte subdued ash-beige hair with restrained original highlights; never brighten toward pale blonde or add noisy streaking
- Garment topology and landmarks: deep navy A-line dress, cream Peter Pan collar, orange ribbon, three brass buttons, loose sleeves, cream lace hem and all connected panels remain intact while the skirt compresses naturally with gravity
- Shoes and ground contact: one pair of black Mary Jane shoes; both soles approach and contact the same invisible horizontal window-top plane; no visible platform line, floor or shadow
- Accessories and companion objects: one tan cross-body strap on its original route, one viewer-right satchel and one small white rabbit with orange bow; bag and rabbit may lag upward then settle but may not detach, mirror, multiply or change owner side
- Line, shading, texture, camera, and light: fine dark outlines, restrained warm cel shading, smooth low-frequency navy fabric, fixed orthographic camera and neutral light; no moire, grain, crosshatching or per-frame grade drift

## Action arc

| Beat | Frame or range | Pose family | Motion and expression | Contact and occlusion |
|---|---:|---|---|---|
| slight descent | 0-2 | airborne | K00 begins slightly above the final standing root, knees softly prepared, toes angled down, arms close but balancing, attentive neutral face | no shoe contact; strap remains across torso; bag and rabbit trail slightly upward on viewer-right |
| first contact | 3-5 | contact | K03 places both shoe soles onto the same invisible horizontal edge, knees beginning to bend, torso still mostly upright | shoe soles first own the invisible contact plane; hem remains in front of thighs; bag begins to swing downward |
| peak absorption | 6-9 | compression | K06 is the deepest controlled crouch, knees and hips flexed, head and torso lowered without shrinking, eyes briefly narrowed or closed from impact | both soles stay planted on one plane; skirt widens and compresses; bag and rabbit lag upward behind the right forearm without detaching |
| stabilization | 10 | rising | K10 rises most of the way, re-centers weight over a still-wide landing stance and reopens the eyes; hem, strap and bag settle | both soles remain planted; bag swing decays; no platform art |
| stance recovery | 11-13 | foot settle | two restrained alternating inward shoe adjustments close the wide landing stance without horizontal root travel | one sole may briefly unweight at a time while the other owns the same invisible contact plane |
| recovery | 14 | standing | K14 independently redraws the approved neutral standing endpoint with the same face, body volume and foot spacing as the standing authority | both soles share the final standing baseline; bag and rabbit return to canonical topology |

F12-F14 include a restrained final rebound: F12 to F13 rises only 3 px at the crown, then K14 settles 8 px back to the canonical standing root. This is intentional secondary settling, not a proportion change; the local head-width range remains 1 px.

## Contact ledger

| Object | Count and side | Attachment or owner | Contact points | Occlusion order | Allowed secondary motion |
|---|---|---|---|---|---|
| invisible window top | one horizontal plane, not drawn | both shoe soles | first contact at K03; both planted through K10; one sole may briefly unweight during the tiny inward stance adjustment in F11-F13; both planted again at K14 | plane remains absent from artwork | none |
| cross-body strap | one, canonical shoulder-to-viewer-right route | fixed to satchel and held naturally against torso | remains connected at shoulder and bag hardware | strap crosses in front of dress and behind the holding hand where applicable | slight tension and settle only |
| satchel | one, viewer-right | strap attachment; follows hip | no platform contact | in front of viewer-right skirt/leg where canonical | small upward lag at impact, then damped settle |
| rabbit | one, viewer-right on satchel | fixed to satchel | never contacts platform | remains in front of satchel | ears and body may lag subtly with the bag |

## Motion boundary

- Allowed motion: vertical root travel inside the fixed cell; ankle, knee and hip flexion; restrained torso counter-tilt; small balancing motion of forearms; eyelid reaction; physically plausible hem, hair, strap, satchel and rabbit follow-through; after K10, two tiny alternating inward shoe adjustments may close the landing stance while the root remains fixed
- Forbidden changes: no horizontal root travel, walking away, large step, spin, side-facing redesign, visible window/floor/line/shadow, umbrella, scenery, effects, text, watermark, body slimming, smaller face, thinner legs, brighter hair, dress shortening, rerouted strap, detached/duplicated bag or rabbit, extra anatomy, crop, per-frame trimming, interpolation, morphing, warping or part compositing
- Intentional holds and timing metadata: no duplicate drawn hold; any final standing pause will be expressed later with frame duration metadata
- Segment seams to inspect: airborne-to-first-contact K00/K03, first-contact-to-deep-compression K03/K06, compression-to-rising K06/K10 and rising-to-standing K10/K14

## Key approval gate

- Planned key poses: `K00 descent`, `K03 first contact`, `K06 deepest absorption`, `K10 stabilized rise`, `K14 recovered standing`
- Key contact sheet: `key-poses/window_land_recover-key-contact-sheet.png`
- Automated key report: `key-qa/generic/qa-report.json` (`PASS`); complete-drawing normalization report: `key-qa/normalization-report.json` (`PASS`, local head-width range 1px)
- User verdict and date: accepted by the user on 2026-07-30
- Approved keys are frozen: `yes`

## Full-sequence gate

- Generic QA report: `qa/qa-report.json` (`PASS`)
- Local identity/material report: `qa/local-identity-report.json` (`PASS`; head-width range 1 px, face-width delta at most 7 px, hair-luma delta at most 3.849, contact baseline range 1 px)
- Target-FPS preview: `qa/preview.gif` (generated at 8 FPS)
- Slow preview: `qa/preview-slow.gif` (generated at 300 ms per frame)
- Close-up identity/contact sheet: `qa/local-identity-contact-sheet.png`, `qa/head-face-contact-sheet.png`, and `qa/material-topology-contact-sheet.png` (generated)
- User verdict and date: pending
- Ready for engine integration: `no`
