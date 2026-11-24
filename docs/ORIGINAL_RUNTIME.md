# Original execution mode (compatibility, not native rewrite)

The toolkit now has three independent execution modes:

- Offline original frames: fastest when the animation is fixed. The original renderer exports two atlases; no JS engine is required during gameplay.
- Native Godot Painter + GDScript simulation + optional C++ raster: editable components, moving endpoints, custom particle systems, original effects individually ported and tested.
- Original runtime: locked original effect modules and their original actor rig/choreography executed by embedded QuickJS-NG. No Node, browser or network at game runtime. This is a compatibility backend, not a claim that every effect has been rewritten or optimized.

The complete package is built only after cross-platform checks. While those checks are pending, use the last verified complete artifact.

## Usage
Open the Godot project; press J in the main lab. Select an effect, enable Original choreography if desired, Space replays, B changes background. The displayed timing includes CPU rendering and texture upload submission, not GPU completion.

```gdscript
const ORIGINAL = preload("res://addons/pixelfx/original_runtime.gd")
const SURFACE = preload("res://addons/pixelfx/native/surface.gd")
var runtime = ORIGINAL.new()
var handle: int
var surface
func _ready():
    assert(runtime.open())
    surface = SURFACE.new()
    add_child(surface)
    surface.configure(160,112)
    handle=runtime.create("lightning/chain-lightning",{"x":28,"y":85})
func _process(dt):
    surface.painter.clear()
    runtime.draw(handle,surface.painter)
    surface.present()
    runtime.update(handle,minf(dt,0.1))
func _exit_tree():
    runtime.destroy(handle)
```

Load the interpreter once, preload any effects needed, and reuse shared surfaces where appropriate. Consult each entry's actual meta.size and meta.origin instead of the example dimensions. The wrapper exposes create/update/draw/stop/state/destroy, placement for FX (not Act), timing/bounds and pose. For an external character use draw(...,"back") and draw(...,"front") around the body; combined act mode uses the original procedural character and target. Act placement and authored trajectories are not arbitrary game physics. Pose returns the original rig's raster data, not an editable Godot Skeleton2D resource. Custom masks are supported by FX options when represented as ordinary JSON arrays. The native actor adapter is a separate path.

## Build
From a checked-out toolkit (original submodule pinned):
```sh
npm install --no-package-lock
npm run build:original
python native_cpp/build.py --original
node tools/make_original_fixture.mjs
godot --headless --path godot --script res://tests/original.gd
```
The embedded interpreter is pinned to QuickJS-NG d7215b0ad3fc2c562e8317fd9bca058fd4863804. See LICENSE-QuickJS-NG.txt. The JS bundle is generated at build time; do not replace it with unrelated effects or an approximation. Only trusted local effect code should be bundled. No host I/O bindings are registered. The interpreter is main-thread only, bounded to 128 sessions, 256 MiB and a two-second execution watchdog; this watchdog is not a frame-time budget. Package the bundle.txt file (original_bundle.txt) in the Godot export include filter if exporting a standalone game. Profile in context, avoid many expensive CPU effects at once.

## Validation
CI builds both Windows/Linux binaries, tests representative color/light buffers and choreography state against Node using the untouched original sources, checks that every catalog module can instantiate, render and update, and checks act metadata and render for modules with choreography. A smoke pass is not proof of full-duration visual parity for every module. See actual workflow logs before reporting success. Original path currently has no arbitrary Godot collision callback or custom bone retargeter. Preserve the original paths when creating new effects; choose native only when needed and prove equivalence.
