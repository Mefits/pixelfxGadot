---
name: creature-sdk
description: Author, validate, simulate, render and export reusable Godot creature anatomy, animation, physical abilities and procedural VFX using the Creature PixelFX SDK.
---
# Creature SDK

Read godot/addons/creature/SDK.md and its template.schema.json before authoring. Use a verified full SDK archive, not only an exported runtime ZIP. The SDK CLI is tools/creature_sdk.py. On a new project import Godot first (Godot 4.4.1); use --godot PATH and --project PATH when needed. Inspect the machine-readable JSON, not just exit status.

1. Select the engine: physical creature vs humanoid rig vs VFX. Never conflate them. See references/anatomy.md, references/animation-vfx.md, references/integration.md for specialized procedures.
2. Run list and show to discover built-ins; clone to a new JSON file. Use RFC 7396 patch or author data against schema. Keep IDs stable and filenames unique. Never change bundled defaults.
3. Validate every authored template; compat for physical ability plus anatomy. Repair precise JSON Pointer errors. Do not bypass a validator or claim a warning proves runtime failure.
4. Simulate creature and ability. Inspect finite state, penetration, displacement, contact count and actual target changes. ok does not prove hits. Test miss, wall and repeat as relevant, not just a successful start.
5. Render with real Godot: render INPUT OUT_DIR 15 45 [CREATURE]; --xvfb before command on Linux CI. Read report.json, inspect actual PNGs or media OUT_DIR (Pillow). Iterate visually; do not present a schematic as a capture. Capture is deterministic fixed-tick input, not a benchmark of frame rate.
6. Export selected template via export. Validate in a fresh Godot project, preserving res:// paths. Existing project files may not be overwritten without approval. Record exact input, commands, reports, images, limitations and licenses.

Do not invent undocumented fields or claim actual visual review, native performance, or independent-agent success without evidence. If a feature is not supported, report the gap and propose the smallest runtime extension. No autonomous network or install actions are required by this skill.
