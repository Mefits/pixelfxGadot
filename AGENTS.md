# PixelFX Godot Toolkit — agent contract
Read README.md, docs/ROADMAP.md and original/pixelfx/skills/pixelfx/SKILL.md first. Run npm run setup if needed. A portable archive carries the original source snapshot, verified by tools/verify_original.mjs; it does not require Git or internet. The locked upstream is the reference; do not edit it.
- Locate actual effects in upstream docs/CATALOG.md; inspect source, metadata, palette, and timing. Render reference before designing.
- Use the existing two-buffer export/player first. Native reference primitives, particle types and Bits now exist; read docs/NATIVE.md and docs/INTEGRATION.md. Use them for dynamic endpoints or physics, not for every cached effect. Native inking is still CPU-heavy. Do not describe cached frames as live particles or approximations as faithful ports.
- Preserve original color and additive light independently, seeded randomness, 1px scale, pivot and timings. Actor-dependent effects may contain pixels of the stock actor, not the game's sprite.
- For new effects make a separate working copy, perform at least three render/inspect/refine rounds. Show equal-scale original versus result; run upstream check.mjs. Do not fake Godot capture.
- Preload clips/materials, pool playback, avoid file loads during combat; measure first cast, repeat, switch and simultaneous instances; record p95/p99/max frame time and environment. No measured FPS claim without real evidence.
- Keep MIT notices. Update status/tests for every implementation. Keep toolkit independent of individual games.
