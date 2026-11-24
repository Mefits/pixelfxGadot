# Verification status
- Original pinned as Git submodule.
- Exporter uses upstream renderFrames and composite; separate color and light, parity check on three opaque backgrounds, paged atlases and SHA-256 hashes.
- Godot clip reader and pooled playback (2 sprites per clip), lab with p95/p99/max HUD: code added, engine execution not yet verified.
- Unit tests added; execution of this revision pending.
- Actual original exports and in-engine pixel parity pending. Native runtime not started.
- Known limitation: combined back/front layers in atlas; actor-specific effects can contain stock character pixels. Multi-effect blend order may differ from upstream shared-buffer compositing. No performance claims until real runs.
