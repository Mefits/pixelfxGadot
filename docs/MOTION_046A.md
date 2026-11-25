# Lab 0.46a — first anatomy/style visual checkpoint (pending native review)

0.45 D is preserved by calling the unchanged variants() and using the unchanged 0.44 skin. --stage 45 reproduces the historical A/B/C/D board. Default --stage 46 renders five equal-scale lanes, D original, D with revised shell on identical joint coordinates, E moderate / F strong / G extreme. Exact source BVH SHA is required. Contact tick and duration are identical across all five lanes.

Changes: visual head position lowered 2.6 rig px toward chest (diagnostic shell, not a changed skeleton or SDK anatomy); thicker short neck and connected shoulders; far sleeve contrast. New variants use local anticipation/contact/release envelopes, pelvis/chest counter-rotation, a small root weight shift, compact passive guard blended from recorded wrist targets. No stretch of limb lengths, no change to the source bend poles, no VFX. This is a hypothesis, not acceptance; far arm occlusion and pole switches still require visual review. Capture evaluates exported CLIPS.sample, reports bone and support residuals, max joint step and contact wrist. SDK validation remains mandatory.

Astra archive compiler and Python adapter were read: threshold on root-relative joint displacement, preserve event/support boundaries, recursively split by actual sampler error. Current sampler has hold/snap per-key modes, but JSON schema may not expose them; no runtime change is needed for this checkpoint. Cadence and key reduction are deliberately deferred until pose review, as required by handoff. No Project N or shared runtime files changed.

Run: python tools/mocap_style.py --godot godot --xvfb --out review-046
Native run and artistic inspection pending. Do not infer acceptance from this commit.
