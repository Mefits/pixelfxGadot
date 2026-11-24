# Verification status
- Original pinned as Git submodule. MIT notice included.
- Exporter uses upstream renderFrames and composite; separate color and light, parity check on three opaque backgrounds, paged atlases and SHA-256 hashes.
- Godot clip reader and pooled playback (2 sprites per clip), lab with p95/p99/max HUD: code added.
- CI checks: six Node unit tests, seven actual original exports, manifest verification, Godot import and smoke, real GL capture versus six original composite fixtures. Check Actions for results, no pass assumed.
- Native runtime not started.
- Known limitation: combined back/front layers in atlas; actor-specific effects can contain stock character pixels. Multi-effect blend order may differ from upstream shared-buffer compositing. No FPS claims until real runs on representative hardware.
