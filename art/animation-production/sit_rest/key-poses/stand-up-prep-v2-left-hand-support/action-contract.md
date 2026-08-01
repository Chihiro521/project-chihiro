# sit_rest stand-up v2 direct-frame contract

## Output

- Action: seated-to-standing revision with active anatomical-left-hand support and follow-through
- Facing and camera: fixed frontal orthographic view
- Duration, FPS, and frame count: F19-F22 sparse review keys inside the existing 26-frame, 6 FPS action
- Loop or segments: exit segment only
- Generation size and final cell: 1024x1024 source, 512x512 final
- Pivot and baseline policy: pivot (256,492), visible shoe baseline y=472
- Production state: `contract_ready`

## Authorities

- Design authority: `../../anchors/model-sheet.png`
- Standing proportion authority: `../../anchors/approved_idle_chroma.png`
- Seated pose-family authority: `git-history://5e67e44/art/animation-production/sit_rest/seated-loop-master-v1/direct-frame-sources/frame_017_chroma.png`
- Low-crouch pose guide: `../stand-up-prep-v1/chroma/frame_020.png`
- Authority rule: temporal poses control motion and contacts only; they never replace design or proportion authority.

## Identity and material locks

- Head and face: broad rounded approved face and fixed head scale; muted blue-gray eyes
- Body and limb proportions: compact approximately four-head body with sturdy legs and normal arm length
- Hair palette: low-luminance ash-beige bob with subdued highlights
- Garment topology: one continuous navy dress panel and one uninterrupted cream lace hem
- Shoes and ground contact: both Mary Jane soles visible and planted on one baseline during F19-F22
- Accessories: viewer-right satchel with one attached white rabbit; strap remains held by the character's right hand on viewer-left
- Rendering: approved fine outlines, restrained cel shading, frontal camera, neutral lighting

## Action arc

| Beat | Frame | Motion and expression | Left-hand contact and occlusion |
|---|---:|---|---|
| reach | F19 | torso leans forward while feet draw under the knees | anatomical left hand, on viewer-right, reaches down outside the satchel toward the implied ground; palm opens |
| support | F20 | both feet load while pelvis begins to unweight | left palm plants beside the hip, fingers splayed; elbow straightens and visibly bears part of the load |
| release | F21 | legs provide the first upward drive | left palm peels off the ground; elbow bends and forearm swings outward-forward for balance |
| follow-through | F22 | knees extend into controlled rise | left arm swings slightly backward-outward with relaxed wrist and fingers, preparing to settle during F23-F24 |

## Contact ledger

| Object | Count and side | Owner/contact | Occlusion order | Allowed secondary motion |
|---|---|---|---|---|
| strap | one diagonal strap | right hand on viewer-left grips throughout | hand over strap over dress | tiny grip adjustment only |
| satchel | one, viewer-right hip | attached to strap | free left forearm/hand stays outside the bag silhouette | small gravity swing |
| rabbit | one attached to satchel | no hand contact | rabbit remains in front of bag | tiny passive bob only |
| implied ground | invisible | left palm contacts only at F20; both shoe soles contact F19-F22 | no visible floor or shadow | none |

## Motion boundary

- Allowed: left shoulder/elbow/wrist/finger arc, torso pitch, root height, hip/knee/ankle extension, slight bag/rabbit gravity response
- Forbidden: frozen left hand, duplicated arm, hand gripping rabbit or bag, broken wrist, hand passing through satchel/skirt, lifted shoe, knee holes, split skirt, bright hair, thin limbs, small face
- Segment seams: inspect F17->F19 reach and F22->F25 arm recovery

## Key approval gate

- Planned keys: F19, F20, F21, F22 v2
- Approved keys are frozen: `no`

## Full-sequence gate

- Ready for engine integration: `no`
