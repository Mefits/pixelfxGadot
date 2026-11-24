# Status — 2026-11-24, verified implementation 0ba5552
Latest implementation test: https://github.com/Mefits/pixelfxGadot/actions/runs/45382920708
Portable package: https://github.com/Mefits/pixelfxGadot/actions/runs/45382920708/artifacts/14913418629

## Verified
- Original pinned commit 5294518ce7c72e48b6100a744596e0acf57f2826; MIT notices retained. Portable snapshot contains 300 original files (effect sources, core, tools, docs/skill), seven exported clips. Offline regeneration from snapshot verified.
- Six Node unit tests; seven original exports / 614 frames. Max CPU composition difference 0 on three opaque backgrounds.
- Godot 4.4.1 clip smoke: all seven clips. Actual GL capture of Chain Lightning at three times on two backgrounds: max RGB difference 1/255.
- Native RNG/hash, palette subset, Painter transformed pixel/line/blend/glow, three seeded bolt geometry + stroke/crackle fixtures: zero differences in tested buffers.
- All 12 particle kinds, including fire-to-smoke, burning chunks, floor callbacks, and Lights: state and color/light fixtures at seven simulation times, zero failures.
- Bits: three kinds (shard, chunk, drip), six times, zero failures in state and pixels.
- Live interactive lab: automated scene smoke passed. Full visual quality judgment and representative hardware test still needed.
## Performance (Linux GitHub-hosted runner, headless CPU)
Benchmark: 160x112, one seeded bolt + steady sparks, 120 measured frames, excluding GPU upload. Original GDScript port p95 23.957 ms (55a24ca); first optimized p95 17.874 ms (73d9a8d); current p95 18.251 ms, p50 15.089, p99 18.586, max 23.022. Current stage p95: shape/clear 0.591 ms, ink/glow 16.120 ms, particles 1.561 ms, conversion 0.011 ms. Values are not target laptop FPS. The GDScript reference remains slow; the optional compiled bolt kernel is measured below. Use original offline clips when dynamic endpoints are unnecessary.
## Remaining
- Port remaining Painter primitives, callbacks, sprite/mask/text, native effect lifecycle, actor rig and moves, Blazes and other helpers; complete authored native effects.
- Accelerate ink/glow while preserving golden fixtures. Next priority: optional compiled GDExtension kernel (C++), with GDScript reference as fallback; benchmark before choosing default. The compiled bolt kernel is implemented and verified below.
- Add actual multi-instance GPU stress test, first-cast warmup, in-game collision adaptation and human visual review.
- Combined front/back in offline atlas; stock actor pixels in actor-dependent clips; per-clip multi-effect blend order may differ from original shared frame. These are known limitations, not parity claims.

## Compiled raster — verified 2026-11-24
C++ stroke/crackle preserves the original priority ink, dither, additive light and double-precision coordinate transforms. GDScript geometry/particles are unchanged. It remains optional; no binary is necessary for offline clips or reference mode.
Build and tests (both Linux x86-64 and Windows x86-64): https://github.com/Mefits/pixelfxGadot/actions/runs/45385289890 (implementation 87585dd).
- Original JS fixtures: 3 seeded bolts, exact color and light buffers; 6 successful C++ calls, no rejection on each OS.
- Extra layered comparison versus tested GDScript reference: 32/32 cases, 64 accelerated calls, no rejection on each OS.
- Same-job benchmark, 160x112, 120 measured frames, one bolt plus steady sparks, no GPU upload:
  - Linux: GDScript p95 13.940 ms, C++ 1.800 ms; ink/glow 12.265 → 0.229 ms.
  - Windows: GDScript p95 14.832 ms, C++ 2.021 ms; ink/glow 13.147 → 0.314 ms.
- Windows cached-geometry raster-only p95 (320x180): 1/4/8/16 bolts = 0.200/0.675/1.334/3.115 ms. Linux = 0.153/0.435/0.963/1.939 ms.
- New standalone kernel fixtures (714cc8e) add 32 direct upstream JS cases, including transform, clipping and shared buffers; standalone compile/test passed on both OS. Full subsequent workflow: https://github.com/Mefits/pixelfxGadot/actions/runs/45385382698.
These are host-runner CPU measurements, not the user's laptop FPS. Particle rendering is the next largest cost; GPU upload, first cast, style switch and visual review remain to be measured in a representative game.
