# Little Chihiro v0.22 ecology animation authority

This directory is the shared, read-only production contract for the five v0.22
animation worktrees. The controller owns this directory and all engine-facing
manifests. Workers own only the action directories assigned in
`action-assignments.json`.

## Approval flow

1. Copy `sprite-sequence.template.json` and
   `direct-frame-action-contract.template.md` into one assigned action folder.
2. Complete the action contract and generate sparse, full-character key poses.
3. Stop at `keys_generated_pending_user`; do not densify the sequence.
4. The controller compares every action against the same design and proportion
   authorities and records explicit user approval.
5. Only the approved worker resumes, draws direct interval frames, runs generic
   and local QA, and produces target-speed and half-speed previews.
6. Workers never edit `skins/`, `pet.json`, behavior data, Godot scripts, shared
   tests, or this authority directory.

Every frame is a complete drawing. Optical flow, tweening, morphing, local-part
translation, compositing, cross-fading, and per-frame trimming are forbidden.
Temporal neighbors control motion and contact only; they never replace the
design or proportion authority.

## Controller acceptance

The controller rejects any frame with face-size drift, body slimming, brightened
hair, altered garment topology, leg-width drift, detached or mirrored satchel,
deformed rabbit, root jitter, material noise, or a visible transition pop. The
first failing frame in temporal order is repaired before later frames proceed.

