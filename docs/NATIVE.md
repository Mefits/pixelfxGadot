# Native reference runtime
Direct ports of locked PixelFX (MIT, Patch/Hugo Duprez): math/hash/RNG; integer palette operations; Painter's Bayer writes, true alpha blending, transform, line, radial glow and constant-color circle/disc/ellipse/ring/rect/beam; lightning zigzag/bowed/stroke/crackle; all 12 particle types, Lights and Bits.
Native tests compare original JS output, including exact packed color and light. See STATUS.md for measured results and limitations. Remaining Painter API, full effect lifecycle, actor masks/rig and complete authored native effect ports are not finished.
Native Surface uses two persistent textures and packed int32 bulk conversion. Live lightning scene (L from lab) is a custom moving-endpoint composition using these source primitives, not original Chain Lightning choreography. Particle cap is host policy; tests stay below cap. Current CPU reference remains expensive: ink/glow is the next optimization target. Do not use for many simultaneous effects until profiled. Original offline player remains the preferred production path where interactivity is unnecessary.
Run node tools/make_native_fixture.mjs, node tools/make_particles_fixture.mjs and node tools/make_bits_fixture.mjs after setup, then Godot headless scripts res://tests/native.gd, res://tests/particles.gd and res://tests/bits.gd. Benchmark res://tests/native_benchmark.gd. No GPU upload measured by the benchmark.


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

Use lightning.enable_acceleration(true) to select the tested optional backend. It exposes accelerated_calls and rejected_calls for validation. The lab chooses C++ automatically when installed; A switches. No accelerated particle rendering yet.

## Ordered Painter batch (development)
Batch.gd records the unchanged particle, debris and light draw calls in order; a single C++ call handles dot/blend/line/glow/circle/disc. Physics, color logic and ordering stay in the reference implementation. Use var draw=batch.begin(painter); particles.draw(draw); lights.draw(draw); batch.finish(). Do not alter painter transform/fade or draw directly to painter while recording. Unsupported binaries return the original Painter; rejected batches replay the exact commands. Test counts ensure benchmarks actually use C++. Verification pending.
