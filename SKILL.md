---
name: pixelfx-godot
description: Use original PixelFX effects in Godot 4, export separate color/light textures, design new VFX against upstream references and verify performance.
---
Read AGENTS.md. Locate an upstream effect, render and inspect it. Export via node tools/export.mjs category/name. Load the clip with addons/pixelfx/clip.gd before gameplay and play with player.gd. Use the lab to inspect original-derived output. New procedural effects must be compared to actual upstream frames and documented as adaptations until parity is demonstrated.
