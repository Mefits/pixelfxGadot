# PixelFX Godot Toolkit — v0.2 development

Godot 4 toolkit using [original PixelFX](https://github.com/patch-gg/pixelfx), pinned in a Git submodule. No substitute rendering algorithms in the offline path.

## Запуск
1. Clone with submodules (or run setup after downloading a ZIP).
2. Install Node.js 18+, Git, Godot 4.
3. Run setup_windows.bat or npm run bootstrap. Seven original effects are exported.
4. Import godot/project.godot and run. Click to cast; Space spawns 32 simultaneous instances; B toggles background, M mirrors, C clears.
5. For any other effect: node tools/export.mjs lightning/ball-lightning --seed 3 --fps 30

Color and additive light are stored separately in paged atlases. The exported clip has a pivot, timebase, loop, original commit and hashes. Godot does not run JS at play time. Actor-dependent effects may paint the stock actor; these are not dynamic custom-character effects. This is not yet a native procedural runtime. The lab loads selected effects on selection; production code should preload required clips during loading.

Use AGENTS.md and SKILL.md when passing the toolkit to AI. Read CATALOG.md and docs/ROADMAP.md. Code implementation is not proof of visual or performance parity; see docs/STATUS.md.

Original PixelFX: MIT, Patch and Hugo Duprez. See LICENSE-PixelFX.txt.
