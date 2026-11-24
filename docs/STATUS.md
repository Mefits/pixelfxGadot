# Verification status
## Verified (commit c12ff832, Actions run 45381798574)
- Node unit tests: 6/6 passed.
- Seven upstream exports: 614 frames total, max channel difference 0 against upstream composite over three opaque backgrounds.
- Godot 4.4.1: all seven clip smoke tests passed.
- Actual GL comparison (chain-lightning frames 6,12,20, two backgrounds): maximum RGB difference 1/255, zero channels above 2. See https://github.com/Mefits/pixelfxGadot/actions/runs/45381798574.
- This establishes the offline two-buffer playback path for the tested frames. It is not proof of live native effect parity or GPU performance on the user's laptop.
## Experimental
- Native math/RNG, palette, partial Painter, lightning geometry and inking implemented in native/. Reference fixtures from upstream; CI parity tests now added, result pending.
- Known limitations: combined back/front layers in atlas; actor-specific effects can contain stock actor pixels. Multi-effect blend order may differ from upstream shared-buffer compositing. No full native particles/rig/runtime yet.
