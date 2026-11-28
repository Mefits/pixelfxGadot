# Ability Lab 0.01 — composition prototype / pending acceptance

Base: experiment/combat-lab-005 @ cd940fee03480548f8f89fdea50e95ca73140140. Baseline CI 46143984366 success. New isolated branch experiment/ability-lab-001; no merge, no Project N change. Knowledge: main N-KB OG-04/05/12.

## Reuse audit
- Existing creature/ability.gd: phases, anchor, pose/VFX profiles; fixed charge/dash/contact/recovery shape, not universal.
- physical_ability.gd and physical_ability_runtime.gd: projectile sweep and lifecycle concepts reusable, runtime incompatible: direct target.hp mutation, direct targeting and independent cooldowns. No runtime import.
- ability_dialog.gd edits old phase schema, deferred until composition verified.
- Hybrid091 retained; existing cross retimed as diagnostic placeholder, original markers removed from three new clips so no double contact.
- Combat005 inherits 001–004; only new default no-op collection hook in 001, all candidate contacts use original pending/resolution and 005 classification. No new HP, no combo/resource policy.
- PixelFX existing native Painter beam, circle, ring, line, glow (separate color/light buffers), not a new engine or exact original effect port. Original submodule catalog unavailable through the repository file API; inspected toolkit CATALOG.md and NATIVE/INTEGRATION docs.

## Implemented candidate
profiles.gd: Motion (clip/anchor/ticks), Movement (bounded gait speed/distance), Interaction (projectile, blade, hand), Impact (research rules), Visual (id), Lifecycle (life). Static data, not a DSL or editor.
world.gd: stable cast IDs, moving-target relative sweeps, detached projectile fixed forward direction, hand/forearm blade (9 samples across segment; approximate continuous rotating collision), dash inherited approach budget, exact local snapshot including entities and IDs. Hitstop freezes entity advancement; interruption removes attached effects before release, detached projectile continues. Existing ground-only starts and no new cancels pending design. Parry on detached projectile inherits attacker stun policy: intentionally not final. Fixed facing/two combatants, no projectile-v-projectile collision, no cross-platform proof.
view.gd: existing native body raster plus PixelFX reference primitives drawn at art pixel scale, no game state writes. First visual candidate only; no artistic acceptance or three-round refinement yet.

## Verification
Branch-specific push workflow runs 001–005 regression, native Godot ability trace and media encoder. Test scans fixed gap grid and records actual results, never forces a hit. Tests include hit/block/miss, mirror, moving target, simultaneous actions, pre-release interruption, lifespan, unique IDs, local replay, parent-state equality and VFX off invariant. Logs metrics and separate simulation/body-only/combined view p95. Capture 120 PNGs per hit/miss scenario; 60fps normal/half MP4, normal GIF, six key frames. CI and visual review pending at this handoff. Do not infer actual results from source or claim 60fps performance from media export.

Next: check exact candidate CI and artifacts, fix any errors, inspect visual results before owner acceptance; do not advance 0.02.
