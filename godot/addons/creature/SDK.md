# Creature & PixelFX SDK 0.35 — authoring contract

Godot 4.4.1 · data schema 1 · portable GDScript runtime.

## 1. Choose the runtime before authoring

| Goal | Template kind | Runtime |
|---|---|---|
| Physical creature, custom anatomy | creature | physical_creature.gd |
| Humanoid keyed animation | animation | clips.gd + rig.gd + skin.gd |
| Humanoid phased attack | ability (no engine field) | ability.gd + fighter.gd + combat.gd |
| Physical creature action | ability, engine=physical | physical_ability_runtime.gd |
| Procedural pixel VFX | vfx | composer/preset.gd + renderer.gd |

These are different engines. A two-leg physical prototype is not the humanoid keyed rig. Do not apply humanoid abilities to the physical body or assume VFX changes collision/damage.

## 2. Canonical data

Read template.schema.json (JSON Schema Draft 2020-12). The outer entry is schema=1, stable id, kind, display name, payload, optional source. Keep runtime identifiers in English; display names may be Russian. Start by cloning a built-in template from catalog.gd (full editor) or defaults/templates/demo functions in the individual runtime modules. Never edit bundled defaults. An exported content/template.json is also a valid starting point.

Example authoring entry:
```json
{"schema":1,"id":"six_leg_mutant","kind":"creature","name":"Шестиногий мутант","source":"authored","payload":{"schema":1,"name":"Шестиногий мутант","type":"tentacled","tail":4,"mass":1.4,"limbs":true,"leg_count":6,"reach":1.1,"trunk":20,"speed":105,"jump":200,"tentacles":2,"tentacle_segments":5,"tentacle_length":8}}
```

Strict schema intentionally rejects unknown keys, fractional counts, unknown marker anchors and noncanonical clip times. Old editor files may use looser accepted data; do not silently delete them or claim all old data is strict. Bare profiles import in the library; the SDK authoring validator expects the full envelope. Physical anatomy supports bounded chains and support legs, not arbitrary soft-body meshes. Physics uses art pixels, seconds, degrees for authored joint angles; curves are absolute channel values versus normalized time [0,1]. Crawler currently shares the basic motor, not peristalsis. Tentacles collide with static Rect2 obstacles; no body/body solver.

## 3. Diagnose, then instantiate

```gdscript
const VALIDATOR=preload("res://addons/creature/sdk_validate.gd")
const API=preload("res://addons/creature/kit_api.gd")
var validator=VALIDATOR.new()
func load_checked(path:String)->Dictionary:
    var report:Dictionary=validator.validate_file(path)
    if not report.ok:
        print(JSON.stringify(report))
        return {}
    return API.read(path)
```

validate(value), validate_file(path) and compatibility(anatomy_entry, ability_entry) return {sdk_version, ok, errors, warnings}. Errors/warnings: {path, code, message}; path is a JSON Pointer (RFC 6901; empty path means document root). Codes are machine-readable; English messages may change. Up to 64 errors per call. Warnings do not set ok=false. Schema errors are reported first; semantic cross-field checks and the existing runtime validator run only once the structure is valid. Unknown fields are rejected in authoring. A missing schema file is a hard error. The bundled validator implements the keyword subset used by the checked-in schema, not a general JSON Schema engine. Independent CI uses a standard Draft202012Validator. Do not interpret a successful structural check as an artistic or gameplay acceptance test.

Typical repair: /payload/leg_count + schema.enum -> choose 0,2,4,6,8; /payload/phases/1/id + ability.phase_order -> dash. If a curve has curve.order, fix normalized times without reordering values accidentally.

## 4. API reference

| Call | Result / contract |
|---|---|
| API.valid(entry) | Legacy runtime acceptance; boolean |
| API.read(path) | Valid entry or {}; 8 MiB max |
| API.create_creature(entry, at, obstacles:Array[Rect2]) | PhysicalCreature or null; host owns object |
| API.attach_ability(entry, creature) | bool; physical engine only; not during active ability |
| API.animation_bank(entry) | Default humanoid bank with selected clip replaced, or {} |
| API.compile_ability(entry) | Humanoid ability clip, or {} |
| creature.advance(dt, axis, jump, legacy_grab=false, climb=0, strike=false, held=true) | Fixed 120 Hz internal step; call from physics process; axis -1..1 |
| creature.anatomy_snapshot() | JSON-safe current anatomy, no world state |
| creature.special.begin(creature,target) | bool; requires configured compatible ability and current state |
| creature.special.drain_events() | Consume diagnostic event list |
| CLIPS.sample(clip, time, wrap_loop=true) | Local pose; RIG.evaluate(pose) updates joint points |
| combat.step(dt,left,right) | Fixed-step two-fighter example; existing arena limits |
| renderer.render(painter,preset,time,anchors,floor_y,provider) | CPU color/light rendering; present separately via surface.present() |

Host target contract: shared dictionary {id:String,p:Vector2,r:float,hp:int}; grab updates p, damaging actions update hp. This is not a Godot RigidBody2D adapter. Ability start may fail because target, range, cooldown, grounded state, wall, active attack or anatomy are unsuitable. compatibility() tests structural compatibility, not these transient conditions. Grab reach is clamped to total physical branch length. Claw uses the existing motion track and fixed attack damage (only cooldown is applied from physical ability profile); grow only uses duration/cooldown; acid adds four .25 s ticks. Do not assume every generic field affects every ability. Use existing motion_track.gd to author claw choreography.

## 5. Integration and verification

1. Select a built-in or export a template from the library. Duplicate the payload and change only required fields.
2. Run strict validation, then compatibility for creature + physical ability pair.
3. Instantiate in a clean project with a floor and target. Step fixed time; test both directions, miss, blocked path, repeat, and compatible/incompatible bodies. Track finite state, constraint errors, contact penetration and actual hits. Do not replace physical simulation with keyframed world positions.
4. Render real frames (native two-buffer surface for VFX, skin or body debug geometry for creatures). Inspect timing, silhouettes, clipping and visual endpoints. Measure performance in the real target project; CI alone cannot demonstrate frame rate or quality.
5. Deliver the JSON entry, runtime version, relevant code, actual tests, preview captures and limitations. Use existing exporter for independent example ZIP; preserve licenses. Source runtime in minimal export is GDScript only.

## 6. Agent CLI (full SDK)
Run from full archive after Godot import. Python 3 and Godot 4.4.1 required; Pillow only for media. CLI uses JSON on stdout and exit 0 success, 1 validation/simulation failure, 2 operational/usage error. Output paths are relative to caller via wrapper; output files/directories must be new. Examples:
```sh
python tools/creature_sdk.py list creature
python tools/creature_sdk.py show creature_tentacled
python tools/creature_sdk.py clone creature_tentacled mutant.json
python tools/creature_sdk.py patch mutant.json changes.json mutant_v2.json
python tools/creature_sdk.py validate mutant_v2.json
python tools/creature_sdk.py compat mutant_v2.json physical_grab
python tools/creature_sdk.py simulate mutant_v2.json physical_grab 600
python tools/creature_sdk.py clone physical_grab grab.json
python tools/creature_sdk.py --xvfb render grab.json frames 15 45 mutant_v2.json
python tools/creature_sdk.py media frames
python tools/creature_sdk.py export grab.json grab.zip
```
Omit --xvfb on a graphical desktop. Patch implements JSON Merge Patch (null removes fields, arrays replaced); schema validates before writing. simulate uses 120Hz ticks, floor and synthetic target, no custom gameplay; inspect hits, target_moved, target_hp, tail_delta separately from ok. render uses actual Godot viewport and runtime, 320x180, 15/30/60 fps, 2..180 frames, optional paired anatomy; PNG hashes, report.json and diagnostics. GIF/contact sheet via Pillow. Not real-time performance measurement. The CLI is not in minimal exported runtime.

## 7. Agent workflow
Use skills/creature-sdk/SKILL.md in full archive; specialized references cover anatomy, animation/VFX and integration. sdk_acceptance/BRIEF.md defines a clean-room agent task; tools/test_creature_sdk.py is a black-box automated reference, not an independent AI run or visual acceptance. Give brief and verified SDK to a fresh agent for that separate test.
