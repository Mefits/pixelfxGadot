# Portable handoff
This package contains the original source snapshot (locked upstream revision), tools, documentation, seven ready-made clips, native Godot modules, original JS bundle and compiled extension for Windows/Linux x86-64. Upstream gallery media and Git history are omitted.

## Start
Extract the entire archive and open godot/project.godot in Godot 4.4.1. Run the main scene. No Node, compiler, network, or manual DLL copying is needed for included runtime modes.
- Main lab: click to play a clip, Space stress test, C clear, B background, M mirror.
- J: full original catalog (244). Choose an effect, enable Original choreography where supported, A toggles optional Painter acceleration, Space replays. Weather uses manual Space stepping; preparation may take seconds. Esc returns.
- H: native Chain Lightning; E: native Electrified; O: native Ball Lightning; L: live lightning; K: original workshop.
- For other platforms, remove the .gdextension descriptor to use offline clips and the GDScript native fallback; original embedded runtime requires a compatible binary.

## Use in another game or AI chat
Supply the whole archive, not only the DLL. Tell the AI to read SKILL.md and AGENTS.md. Copy the relevant Godot addon, generated assets/bundle and dependencies into the target project according to docs/INTEGRATION.md and docs/ORIGINAL_RUNTIME.md. Preserve resource paths or update preloads. Do not modify original/pixelfx or snapshot.json.
Node 18+ is required only to export additional offline clips or rebuild the JS bundle. Rebuilding C++ requires the documented compiler/dependencies. Check BUILD.json for binary provenance and hashes.

## Limits
Full catalog smoke coverage is not exhaustive visual parity. Expensive effects should use offline clips or native ports for gameplay. See docs/STATUS.md and docs/ORIGINAL_RUNTIME.md.
