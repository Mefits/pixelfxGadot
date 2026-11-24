# Native effect authoring contract

1. Choose the closest actual original effect in original/pixelfx/docs/CATALOG.md. Read its source, metadata, dependencies and original SKILL.md. Keep the upstream snapshot immutable.
2. Record whether the requested result is an exact port or an adaptation. For an exact port keep the original local coordinates, duration, palette, RNG calls and order, easing, emission, physics and color/light writes. Actor-dependent effects need their original actor/mask interface or an explicitly documented adaptation.
3. Pure effects expose draw(painter,t); persistent effects need explicit reset/update/draw lifecycle, deterministic state and fixed simulation steps. Reuse native/ modules; do not create independent replacement particles or shaders just to imitate visuals.
4. Reuse Painter, Lightning, Particles, Bits and Lights. For compatible primitives use batch.begin(painter), ordered draw calls, batch.finish(); flush before changing transform/fade, reading buffers or invoking other direct raster calls. Use original GDScript reference when extension is unavailable. Do not silently reduce counts or brightness.
5. Generate reference fixtures directly from the locked upstream JS. Compare packed color and light independently for every nominal frame of a pure effect, and multiple times/states for simulated effects. Include default seed, option cases and transformed/clipped cases where applicable. Require accelerated calls >0 and no rejections in compiled-path tests. Never use output of the port as the golden reference.
6. For adaptations record intentional differences, inspect original and result at the same scale, iterate visually at least three times, and profile real Godot scenes. Exact buffers do not replace final visual inspection or GPU/first-cast stress testing.
7. Update CATALOG.md, docs/STATUS.md, tests and integration example. Keep MIT notices. Ship the complete tested archive from the cross-platform workflow, not an untested source ZIP.

Reference: effects/ball_lightning.gd, tools/make_ball_fixture.mjs, godot/tests/ball.gd.
