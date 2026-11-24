# Verification status
## Verified
- Original pinned via submodule; original MIT notice retained.
- Actions run [45381798574](https://github.com/Mefits/pixelfxGadot/actions/runs/45381798574): six Node tests passed, seven original exports (614 frames) have zero CPU composition error across three opaque backgrounds; seven Godot 4.4.1 clip smoke tests passed.
- Real GL capture of Chain Lightning, three times and two backgrounds: max RGB difference 1/255, zero channels above 2.
- Native tests in [45382102168](https://github.com/Mefits/pixelfxGadot/actions/runs/45382102168): seeded RNG, hash, transformed Painter color and light and three seeded branched bolt fixtures all passed with zero differing pixels. This verifies the implemented subset, not all of PixelFX.
## Latest work pending validation
- Portable package with original source snapshot and seven clips; CI validates offline re-export.
- Seven hard particle kinds and Lights direct port; state and buffer parity fixtures and CPU benchmark added.
- Not yet implemented: soft particles, fire, Bits, complete Painter, actor masks/rig, native live display, performance optimization.
- Offline playback limitation: combined front/back, stock actor pixels in body-dependent clips, shared-buffer multi-effect blend order can differ. No real-user laptop FPS measurements.
