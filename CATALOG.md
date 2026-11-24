# Initial validation set
See original/pixelfx/docs/CATALOG.md for the full catalog.
| ID | Purpose |
|---|---|
| lightning/chain-lightning | branching / node timing |
| lightning/electrified | actor-dependent arcs |
| lightning/lightning-strike | strike / decay |
| lightning/charge-up | gathering / flash |
| nature/acid-splash | particles / ground |
| melee/sword-slash | timing / arc |
| explosions/big-explosion | large effect / atlas paging |
All seven are verified offline exports. Chain Lightning and Electrified now also have native effect implementations. Original choreography is handled separately.

## Native authored effects
| Original ID | Implementation | Status |
|---|---|---|
| lightning/ball-lightning | godot/addons/pixelfx/effects/ball_lightning.gd | 120/120 default frames exact against original JS on Linux, both backends |

Ball Lightning: size 136×104 art pixels, pivot (68,92), duration 4 s, 30 FPS, loops, seed/palette/spark palette. Open O in the main lab. Geometry follows the authored loop; it is not a collision-aware projectile yet.

## Original toolkit compositions
| ID | Source | Status |
|---|---|---|
| custom/rift-collapse | godot/addons/pixelfx/effects/custom/rift_collapse.gd | first original workshop effect; backend/replay tests pending |

| lightning/chain-lightning | effects/chain_lightning.gd | 54 frames exact (GDScript and Linux C++) |
| lightning/electrified | effects/electrified.gd | 120 frames exact across two actor sizes (GDScript and Linux C++) |

## Complete original catalog
The original-runtime build generates godot/generated/original_catalog.json from allIds() at the locked upstream revision. See docs/ORIGINAL_RUNTIME.md; verify the CI result before reporting complete runtime compatibility.
