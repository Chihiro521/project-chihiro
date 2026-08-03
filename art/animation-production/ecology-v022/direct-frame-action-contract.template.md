# <action_id> direct-frame contract

## Output

- Action:
- Facing and camera:
- Duration, FPS, and frame count:
- Loop or segments:
- Generation size: `1024×1024`
- Final cell: `512×512`
- Pivot: `(256, 492)`
- Baseline policy:
- Production state: `contract_ready`

## Authorities

- Design authority: `../../../../character-reference/model-sheet.png`
- Identity lock: `../../../../character-reference/identity-lock.json`
- Proportion authority:
- Additional pose-family authorities:
- Authority rule: temporal neighbors control motion and contacts only; they never replace design or proportion authority.

## Identity and material locks

- Head and face: preserve the approved rounded face, head width, eye spacing and muted expression scale.
- Body and limbs: preserve approved shoulder, torso, dress volume, leg thickness, shoe size and full-body scale.
- Hair: ash-blonde with restrained original highlights; no brightening, stripes, grain, moire or texture accumulation.
- Garment: preserve collar, ribbon, three buttons, cuffs, dress panels, lace hem, socks and Mary Jane shoes.
- Accessories: one connected tan strap and satchel on the fixed side; exactly one intact white rabbit with orange bow.
- Rendering: original fine outline, restrained shading, orthographic camera and neutral light.

## Action arc

| Beat | Frame or range | Pose family | Motion and expression | Contact and occlusion |
|---|---:|---|---|---|
| anticipation | | | | |
| approach | | | | |
| peak or weight transfer | | | | |
| held beat | | | | |
| release | | | | |
| recovery | | | | |

## Contact ledger

| Object | Count and side | Attachment or owner | Contact points | Occlusion order | Allowed secondary motion |
|---|---|---|---|---|---|
| satchel strap | one, fixed side | shoulder and satchel | | | restrained sway only |
| satchel | one, fixed side | strap; optional declared hand | | | action-specific |
| rabbit | exactly one | satchel or explicitly declared hand | | | ears may react subtly without topology change |
| body support | n/a | feet, seat or window edge | | | declare every transfer |

## Motion boundary

- Allowed motion:
- Forbidden changes:
- Intentional holds use timing metadata rather than duplicate drawings:
- Segment seams to inspect:

## Key approval gate

- Planned key poses:
- Key contact sheet:
- Automated key report:
- Controller verdict and date:
- User verdict and date:
- Approved keys are frozen: `no`

## Full-sequence gate

- Generic QA report:
- Local identity/material report:
- Target-FPS preview:
- Half-speed preview:
- Close-up identity/contact sheet:
- Controller verdict and date:
- User verdict and date:
- Ready for engine integration: `no`
