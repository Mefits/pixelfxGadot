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

## Ordered C++ Painter batch and complete native Ball Lightning — 2026-11-24
- C++ batch accepts ordered dot/blend/line/glow/circle/disc commands, preserving particle/debris state and drawing order. All 12 particle kinds and Lights passed original state/pixel fixtures on Linux and Windows (run 45389736267); Bits batch passed Linux in run 45389967911.
- Windows same-job test, one bolt + steady sparks: p95 14.734 ms GDScript, 2.007 ms C++ bolt only, 1.275 ms C++ bolt + particle batch. Physics remains GDScript. No GPU upload measured.
- First full native authored effect: Ball Lightning, 120 original frames at 30 FPS, default seed/palette. Both GDScript and C++ buffers match the original exactly on Linux (run 45389967911); p95 5.019 → 0.629 ms. This tests native effect buffers, not a screenshot of every frame or a laptop FPS claim.
- Regular fallback regression: https://github.com/Mefits/pixelfxGadot/actions/runs/45389967895 passed.
- Cross-platform build and complete archive: https://github.com/Mefits/pixelfxGadot/actions/runs/45389967911. Previous verified unified archive (bolt-only C++): https://github.com/Mefits/pixelfxGadot/actions/runs/45389604977/artifacts/14918625502.
- Remaining: full effect lifecycle/API, native authored effects beyond Ball Lightning, actual arbitrary wall collisions, actor masks/rig, full Painter, target-hardware first-cast/multi-instance/GPU timing and visual inspection. The orb trajectory is the original fixed authored loop; dynamic game-specific trajectories require explicit adaptation and validation.

## Core completion and original runtime integration (2026-11-24)
- Full Painter including callback shapes, masks, sprites, fonts and palettes: three original reference cases exact, Windows/Linux compiled package verified in run 45393190916.
- Native math/shapes/noise/emitter/actor/lifecycle and sim helper fixtures: all pass. Native Chain Lightning 54 frames exact; Electrified 120 frames exact for two actor masks. Linux C++ tests pass in run 45394278270; Windows job canceled due to newer commits, not a verified pass for these additions. GDScript fast run 45394278240 succeeds. Chain C++ p95 1.931 ms, Electrified C++ p95 3.669 ms on Linux hosted runner, excluding GPU upload.
- Embedded original QuickJS runtime, module bundle, effect/act API, catalog lab and reference/smoke tests committed. This uses the original rig and choreography rather than a Godot bone-for-bone rewrite. Cross-platform integration run 45394956913 pending at time of writing. See docs/ORIGINAL_RUNTIME.md.
- Last verified complete archive at time of writing: https://github.com/Mefits/pixelfxGadot/actions/runs/45393190916/artifacts/14919084321. Do not confuse it with the newer unverified original-runtime build.
