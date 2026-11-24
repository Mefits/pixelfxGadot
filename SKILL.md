---
name: pixelfx-godot
description: Create, integrate and optimize procedural pixel-art VFX in Godot using the original PixelFX catalog, verified native primitives and separate color/light rendering.
---
# PixelFX Godot Toolkit
Read AGENTS.md, PORTABLE.md, docs/INTEGRATION.md, docs/NATIVE_AUTHORING.md and the upstream original/pixelfx/skills/pixelfx/SKILL.md. For custom compositions also read docs/CUSTOM_EFFECTS.md.

## Choose the right backend
- Fixed animation, mass effects: export separate color/light clips with tools/export.mjs and use clip.gd/player.gd. Preload and pool.
- Original authored effect or choreography: use addons/pixelfx/original_runtime.gd and docs/ORIGINAL_RUNTIME.md. The complete archive contains the original JS bundle and Windows/Linux x86-64 GDExtension. No Node or compiler at runtime. Enable optional Painter acceleration only after checking parity for the intended effect. Heavy originals and weather are reference/offline candidates, not automatically suitable for real-time gameplay.
- New interactive effect: use existing native Painter, batch, lightning, particles, Bits, lights, noise, motion and runtime modules. Use the C++ raster where supported; keep the reference fallback. Start from the closest original source or verified native effect. Use effects/custom/ for new compositions, not original/pixelfx/.

## Required workflow
1. Inspect the nearest original code, metadata, palette, timing, origin and layering.
2. Design phases, movement, direction, anchors, collision needs and light; do not copy unrelated effect choreography.
3. Build a reproducible seeded implementation using existing primitives, preserving color/light separation.
4. Render, inspect and refine at least three times for complex custom effects. Compare both backends; for a port require upstream golden fixtures, for a new effect require deterministic replay, backend equality, nonempty intended phases and clean ending.
5. Measure cold preparation, repeated casts, style switching, concurrent effects and p95/p99/max frame time on the target system; distinguish CPU render timing from actual game FPS.
6. Deliver runnable Godot integration, source, test results, limitations and MIT notices. Never claim visual review or runtime tests not performed.

## Verified baseline
Godot 4.4.1, Windows/Linux x86-64, build f8a812f; 244 original effects and 73 authored acts passed smoke tests on both platforms. 84 same-engine accelerated/unaccelerated frames match exactly. This is not a native rewrite or full-duration golden comparison of all 244 effects. See docs/STATUS.md.

## Creature SDK authoring (0.31)
For anatomy, keyed clips, composer presets and ability templates, first read godot/addons/creature/SDK.md and template.schema.json beside it (or addons/creature/ in an exported package). Use sdk_validate.gd.validate / validate_file and compatibility before running simulations. Do not confuse strict authoring with legacy import. Use the existing kit_api.gd and runtime rather than introducing a parallel engine. Automated rendering and CLI are not yet provided by this milestone.
