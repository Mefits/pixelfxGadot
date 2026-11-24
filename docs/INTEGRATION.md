# Integration guide for AI and game developers
## Select the execution path first
Use original offline clips for noninteractive explosions, impacts, attacks, loops and ambience. Use native components only if positions/trajectory/ground contacts must change in real time. Native reference is exact on its tests but is not yet a production optimized renderer. For a new custom effect, study the closest upstream source; do not replace algorithms with approximate polylines or generic emitters.
## Offline path
Copy godot/addons/pixelfx (and required generated clip directories) into your Godot project. Prepare needed clips in a loading scene before any attacks:
```gdscript
const BANK=preload("res://addons/pixelfx/clip_bank.gd")
const POOL=preload("res://addons/pixelfx/pool.gd")
var bank=BANK.new()
var pool=POOL.new()
func _ready():
    add_child(pool)
    assert(bank.prepare("impact","res://generated/melee_sword-slash/clip.json"))
func impact(at: Vector2):
    pool.play(bank.get_clip("impact"),at,1,2.0)
```
Export other source effects with node tools/export.mjs category/name --name unique-name. For options read upstream meta/options and use --opts JSON. Original colors, light, pivot and time are retained. Keep MIT notices with distribution. Actor-dependent exports may paint stock actor pixels. Do not use them as dynamic character masks.
## Native path
Inspect godot/lab/live_lightning.gd and native/ modules. Painter has separate color/light buffers, native Surface presents both. Lightning methods consume deterministic RNG and palette. Particles.advance(dt) steps at 120 Hz or finer, floor callback takes local x and returns floor y; it is not arbitrary wall collision. Bits.update(dt) is a single step, call at a fixed rate. Keep effects local in art pixels; scale display independently. Set explicit caps; do not multiply native surfaces for hundreds of entities. Use actual in-game profiling; do not assert FPS based on Linux CI.
## Acceptance
Run original rendering tools, compare equal-scale frames on dark and bright backgrounds, inspect motion (at least three iterations for authored effects), run parity and stress tests. Check first cast, repeat, switch, simultaneous instances. Keep original files immutable and port changes outside original/. Document any intentional visual deviation.
