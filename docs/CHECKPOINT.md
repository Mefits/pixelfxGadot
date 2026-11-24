# 0.01
Verify locomotion foundation and graphical smoke; no combat yet.

Explicit screen-coordinate perpendicular for IK; test knee direction and actual support-point contact, faster sprint step cadence.

## 0.02
Guard retarget, fixed support, mirrored pose loop, constant limb lengths; capture 24 real frames at 20 fps. Retain previous locomotion tests. No combat or VFX added.

## 0.03
Reference-based locomotion posture, velocity-predicted step targets, fixed swing durations, guard backpedal, airborne tuck/extension and landing compression. Regression of mirrored stance and support; real 20 FPS capture sequences for walk/run/back/jump. No combat changes.

Final 0.03 checkpoint: initial regression passed; repeat after correcting opposing arm swing and adding its test.

## 0.04
Jab milestone: all locomotion regressions, one hit, held-key protection, mirrored hit, miss, trade, airborne rejection, six freeze ticks, root knockback, real 30 fps capture. No hybrid joint physics yet.

## 0.05
Heavy rear-hand attack, contact-derived torque, bounded angular spring dynamics with delayed channels, hitstop freeze and A/B reset. Verify old locomotion/jab, hybrid strength/lever/lag/settle, heavy miss/contact/trade, symmetry, bone lengths and actual capture comparisons.

Correct float32 clamp comparison: reset angular velocity only when a hard angular limit is exceeded, not on rounding. Keep original tests unchanged.

## 0.06
Freeze hybrid implementation, authored reaction default, draw-only original provisional skin. Retain all tests; explicitly enable hybrid in regression; verify toggling art preserves world state. Capture authored jab, authored heavy and same heavy with mannequin for comparison.
