# Environment Lab v0.03 — Cosmic Ruins

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


## v0.02 polish (pending actual capture review)

Moon placed above the central cloud cover, brighter and denser stars, extra shaded cloud lobes, less repetitive ruins and quieter floor. Cloud translation reduced 75–77%; wind is concentrated in six fixed-root shrubs with tip-weighted GPU deformation and five sparse, fading leaves beside ruins. All motion uses the same 12-second phase. Leaf resets occur at zero opacity. Small foliage textures generated once using the native Painter; no upstream or Motion Lab changes. Main layer count remains ten, plus eleven small sprites (five leaves share a texture). Scanline intersection fill reuses Painter.line for polygon spans; CI compares coverage against the original Painter on a test polygon. Startup and render costs must be measured; no 60 fps GPU performance claim. v0.01 measured startup 42.87/95.53 s (640/960) on software-rendered CI; this revision targets that bottleneck without changing core. CI checks capped cloud travel, fixed roots, invisible leaf reset, actual rendered wind, exact cycle closure, unchanged floor and texture reuse. Visual approval remains separate.


## v0.03 — combat light receivers

The normal arena remains ambient-only by default. Run res://lab/environment/lighting_demo.tscn (F6) for a six-second demonstration: actual native Chain Lightning with warm and violet palettes, no substitute effects. L toggles reflected light without disabling VFX; Space restarts. The effect's own 30 fps ink is preserved; preview samples at 60 fps. The source bridge reads the existing native Lights list, preserving its shrinking radius and quadratic lifetime fade, translating effect-local coordinates to arena coordinates. The demo uses a 2.1x artistic reach and sustained core light derived from actual FX.level. No modification to upstream, native core or Motion Lab.

Integration:
- arena.emit_combat_light(position, radius, Color, energy, lifetime) for game events (native Lights pool).
- arena.publish_combat_lights([{"lights": fx.lights, "origin": Vector2(...), "scale": 1.0, "reach": 1.0}]) once per visual update after effects have stepped. Pass all sources at once, [] when gone; optional sustained entries carry position/radius/color/energy. Caller owns effect simulation. Coordinates use 640x360 arena local units; convert world coordinates using arena.world.to_local if necessary.
- arena.combat_lighting.set_enabled(false) disables only reflections; clear() clears the light snapshots/pool.

Two terrain-only GPU receivers consume up to eight strongest light entries. The final Painter alpha is the coverage mask; normals/reflectance are derived at bake time from the authored face palette, with a separate floor normal. PixelFX quadratic radial falloff, colored directional reflected addition and bounded saturation. This is an approximate 2.5D material response, not true ray-cast occlusion or dynamic shadows. No sky lighting, no foliage lighting, no per-frame terrain texture upload. The visual plane is unchanged, independent from combat physics/rollback.

CI retains ambient regression checks (skips redundant 720-frame ambient capture), verifies exact idle/expiry/loop, two simultaneous colors, range and sky masking, real native effect bridge, toggle, and captures 360 actual Godot frames at 60 time samples/sec. CPU update metrics include demo VFX raster/submission, not GPU completion. No hardware FPS or artistic approval claim before actual validation.
