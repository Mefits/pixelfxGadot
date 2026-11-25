# PixelFX Godot Toolkit — v0.2 development

## Активная лаборатория анимаций — Lab 0.45

**[Актуальная передача проекта следующему агенту](docs/MOTION_HANDOFF_RU.md)**. Ветка `experiment/motion-temporal-rd`: исправленные суставы 0.44, перенос реального мокапа ACCAD, сравнение A/B/C/D. Пользователь выбрал D как базу дальнейшей стилизации. Не путать с замороженным Lab 0.42 и отдельным Project N. [Нативный сравнительный рендер 0.45](https://github.com/Mefits/pixelfxGadot/actions/runs/45656732943/artifacts/15042302641) (артефакт Actions имеет срок хранения).

Godot 4 toolkit using [original PixelFX](https://github.com/patch-gg/pixelfx), pinned in a Git submodule. No substitute rendering algorithms in the offline path.

## Запуск
1. Clone with submodules (or run setup after downloading a ZIP).
2. Install Node.js 18+, Git, Godot 4.
3. Run setup_windows.bat or npm run bootstrap. Seven original effects are exported.
4. Import godot/project.godot and run. Click to cast; Space spawns 32 simultaneous instances; B toggles background, M mirrors, C clears.
5. For any other effect: node tools/export.mjs lightning/ball-lightning --seed 3 --fps 30

Color and additive light are stored separately in paged atlases. The exported clip has a pivot, timebase, loop, original commit and hashes. The offline player does not run JS at play time. Actor-dependent effects may paint the stock actor; these are not dynamic custom-character effects. Native and original-runtime paths are described separately below. The lab loads selected effects on selection; production code should preload required clips during loading.

Use AGENTS.md and SKILL.md when passing the toolkit to AI. Read CATALOG.md and docs/ROADMAP.md. Code implementation is not proof of visual or performance parity; see docs/STATUS.md.

Original PixelFX: MIT, Patch and Hugo Duprez. See LICENSE-PixelFX.txt.

## Переносимый архив
На странице Actions открой успешный запуск и скачай артефакт **PixelFX-Godot-Toolkit**. В отличие от обычного GitHub ZIP, он содержит все оригинальные исходники эффектов, инструменты, семь подготовленных клипов и Godot-проект. Для готовых клипов достаточно Godot; для экспорта новых — Node.js 18+, без интернета. Контрольные суммы исходников проверяются перед экспортом. Галерейные медиа и история Git не входят в архив. 

## Live native lab (experimental)
Press L in the export lab or run godot/lab/live_lightning.tscn. Hold left mouse and move to connect a live endpoint; 1/2 select original stroke/crackle helpers. This custom moving-endpoint effect uses native reference ports, not the baked Chain Lightning animation. Its CPU timing includes buffer conversion/upload submission but not full GPU cost. The native path is not yet optimized for many simultaneous effects.

## Embed offline effects in a game
Use addons/pixelfx/clip_bank.gd to prepare required manifests before combat and addons/pixelfx/pool.gd for fixed-capacity reuse. Call pool.play(bank.get_clip(id), position, facing, pixel_scale). No disk loading is performed by play(). Prewarm on the actual target GPU if first-use stalls occur.

## Проверенная сборка (24 ноября 2026)
[Переносимый архив с последними реализациями](https://github.com/Mefits/pixelfxGadot/actions/runs/45382920708/artifacts/14913418629) · [Результаты CI](https://github.com/Mefits/pixelfxGadot/actions/runs/45382920708) · [Статус и ограничения](docs/STATUS.md) · [Интеграция](docs/INTEGRATION.md).
Все семь оригинальных экспортов, нативные тесты молний, 12 видов частиц и три типа физических фрагментов прошли подготовленные проверки. Нативный CPU-рендерер ещё требует ускорения; не считать лабораторию готовым высокопроизводительным VFX-движком.

## Optional C++ accelerator (development)
Build instructions: [native_cpp/README.md](native_cpp/README.md). The live lightning lab automatically selects the extension if installed; press A to switch to GDScript and compare. The existing package still works without compiled binaries. Cross-platform build, strict parity and timing are tracked by the Optional C++ raster workflow; Linux and Windows verification passed; see the measured results in docs/STATUS.md.

### Downloads and installation (Godot 4.4.1, x86-64)
1. [Portable toolkit](https://github.com/Mefits/pixelfxGadot/actions/runs/45385382460/artifacts/14916235866).
2. [Windows accelerator](https://github.com/Mefits/pixelfxGadot/actions/runs/45385289890/artifacts/14916126309) or [Linux accelerator](https://github.com/Mefits/pixelfxGadot/actions/runs/45385289890/artifacts/14916185762).
3. Extract the toolkit; close Godot. Copy the accelerator archive contents (pixelfx.gdextension and bin/ with the corresponding DLL/SO) into godot/addons/pixelfx/. Open godot/project.godot, run, press L for the native lab, hold LMB, A toggles backend. HUD reports C++ or GDScript. To remove the extension, close Godot and remove the descriptor and bin/; GDScript remains usable. No compiler needed when using tested binary. GitHub login may be required for artifacts; artifacts expire according to repository settings.

## Единый архив (рекомендуемый)
[Unified toolkit package — последние сборки](https://github.com/Mefits/pixelfxGadot/actions/workflows/package.yml). Артефакт **PixelFX-Godot-Toolkit-Complete** содержит готовые Windows DLL и Linux SO, дескриптор расширения, исходники, семь клипов и лабораторию. Распакуй и открой godot/project.godot в Godot 4.4.1 (x86-64). Ручное копирование DLL не требуется. C++ включается автоматически в live lab. Для неподдерживаемых платформ удалите дескриптор pixelfx.gdextension, чтобы использовать GDScript. Отдельные архивы выше оставлены для разработчиков.

## Unified packages
The first verified complete package is [here](https://github.com/Mefits/pixelfxGadot/actions/runs/45389604977/artifacts/14918625502). New C++ workflow packages both binaries after the two platform jobs pass; [latest builds](https://github.com/Mefits/pixelfxGadot/actions/workflows/cpp.yml). O in lab opens the experimental full native Ball Lightning port; all 120 frames are compared in CI.

## Original workshop (development)
K in the main lab opens Rift Collapse, a new composition using the toolkit (not an upstream effect). 1/2/3 select three art directions; pause/scrub/replay, change seed and backend. See [custom effect authoring](docs/CUSTOM_EFFECTS.md). CI tests replay and backend parity; artistic review pending.

## Перенос оригинала: три режима
- Готовые двухслойные клипы — дешёвое воспроизведение.
- Нативные модули — Painter, частицы, физические фрагменты, молнии, эмиттеры, шумы, маски и оригинальные эффекты Ball Lightning, Chain Lightning, Electrified.
- Встроенный оригинальный JS — полный каталог и оригинальная хореография без Node.js в игре. Новый режим J; H — Chain Lightning, E — Electrified, O — Ball Lightning. Сборка оригинального режима проверяется отдельно.

[Описание и API оригинального рантайма](docs/ORIGINAL_RUNTIME.md) · [Последняя проверенная сборка с полным Painter](https://github.com/Mefits/pixelfxGadot/actions/runs/45393190916/artifacts/14919084321) · [CI оригинального рантайма](https://github.com/Mefits/pixelfxGadot/actions/runs/45394956913).

## Complete verified toolkit
[Windows/Linux complete archive](https://github.com/Mefits/pixelfxGadot/actions/runs/45397546384/artifacts/14921842877) · [passing build and package test](https://github.com/Mefits/pixelfxGadot/actions/runs/45397546384). All 244 effect modules and 73 choreography entries pass smoke tests on both platforms. Includes native C++ libraries and original JS bundle. J opens original catalog; A toggles acceleration. Read PORTABLE.md and the latest docs/STATUS.md for actual acceptance criteria and performance limits. For use by another AI, provide the whole archive and SKILL.md.
