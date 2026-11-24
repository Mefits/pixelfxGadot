# Native reference implementation (experimental)
Directly derived from locked upstream math.js, color.js, painter.js and lightning/_lib.js. Not a complete native runtime. Implemented: hash/mulberry32, ramp operations, ordered Bayer writes, translucent blending, pixel transform, Bresenham line, radial additive glow, midpoint displacement, bowed bolts, priority ink, stroke and crackle. No per-particle physics, actor mask, full Painter primitives or native texture uploader yet.
Run node tools/make_native_fixture.mjs after npm run setup; then godot --headless --path godot --script res://tests/native.gd.
Fixtures compare original JS RNG integer outputs, bolt geometry, and every packed color/light pixel. Exact match is the gate; if float boundary differences appear, inspect the diffs before choosing a tolerance. CPU reference is not a performance-optimized shipping renderer.

## Hard particles and lights
SPARK, MOTE, STREAK, FLAKE, STAR, EMBER and GRIT with upstream fixed-step physics, ordered list, delays, floor callback, light and streak rendering. The 512-particle cap is an explicit host budget. Soft kinds and Bits remain unported. Fixtures compare state and packed pixels at six times. Native CPU benchmark measures one bolt plus sparks and buffer conversion; GPU uploads are excluded. No performance claim until the benchmark runs.

## Live test
Native surface uploads two persistent textures; the experimental lab composes a bolt between a fixed anchor and mouse at a 30 Hz visual rate, with fixed-step particle physics, 96 particle cap and separate flashes. This is a test of reusable source primitives, not a direct port of a complete authored effect. Do not use CPU reference as a shipping performance baseline until measured.

## First measured optimization
Baseline CI (55a24ca) measured p95 23.957 ms for one 160x112 bolt with steady sparks, excluding GPU. PackedInt32Array bulk conversion and inlined clipped additive glow replace per-pixel GDScript conversion/calls. Exact parity tests retained; new stage timings separate shape, ink/glow, particles and conversion. Compare CI before/after, never infer target hardware FPS.
