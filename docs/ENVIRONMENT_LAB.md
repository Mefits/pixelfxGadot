# Environment Lab v0.01 — Cosmic Ruins

An original, code-authored background study, not an exact port of an upstream effect or an image trace. No source raster, generated media, or baked animation is used at runtime. Base toolkit and Motion Lab are unchanged.

Open godot/project.godot and run res://lab/environment/cosmic_ruins.tscn (F6).
Set internal_width to 640 (default) or 960 in the Inspector; the world fits the viewport at 16:9.
The floor is a visual plane, not a physics collider.

## Existing technology reused

- Native PixelFX Painter: polygon rasterization, ellipses, lines, packed color/light buffers and light glow.
- Native Palette and deterministic math hash.
- Upstream weather/clouds.js: layered overlapping puff silhouettes and separated tones. Here the silhouettes are art-directed and cached; this is an adaptation, not its cloud lifetime/lighting algorithm.
- Upstream weather/shooting-stars.js: fixed star positions, independent seeded phase and integer harmonics. Brightness moves continuously on GPU, no thresholded arm resizing.
- Original MIT notices retained; no changes to pinned upstream.

## Runtime

Ten independently generated textures (sky, stars, distant atmosphere, moon light, moon, three cloud masses, ruins, floor), plus one star phase texture. Static Painter generation on ready; textures are reused. Moon halo and four cloud layers are independently animated with explicit 12-second periodic time. Nearest filtering on static pixel layers; linear only on slowly moving clouds to prevent position stepping. No per-frame texture upload or CPU rerasterization. Runtime star shader is a new environment-specific optimization, not an upstream shader. Additive light is a separate sprite beneath moon/clouds.

## Acceptance / status

The branch adds a dedicated Godot 4.4.1 CI preview: exact rendered loop closure, nonidentical intermediate frame, static floor, texture reuse, CPU update timings, both internal resolutions, 720 rendered frames at 60 samples/sec and actual PNG/GIF/MP4. The MP4 is 60 fps, GIF is a 30 fps convenience preview. CI captures via software OpenGL; it is not a target-GPU benchmark. Startup generation and CPU update are reported separately. Target budget 1–2 ms incremental background render remains unverified; profile with combat on target hardware. Visual acceptance and three visual refinement rounds are pending until actual captures are reviewed. No parallax, combat event binding or full environment editor in v0.01; those are follow-up scope.

Run locally with ENV_CAPTURE_DIR pointing to an output directory and Godot (non-headless rendering) using --path godot --script res://tests/environment_preview.gd.
