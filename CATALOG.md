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
All seven are verified offline exports; their complete authored native ports are not yet implemented.

## Native authored effects
| Original ID | Implementation | Status |
|---|---|---|
| lightning/ball-lightning | godot/addons/pixelfx/effects/ball_lightning.gd | 120/120 default frames exact against original JS on Linux, both backends |

Ball Lightning: size 136×104 art pixels, pivot (68,92), duration 4 s, 30 FPS, loops, seed/palette/spark palette. Open O in the main lab. Geometry follows the authored loop; it is not a collision-aware projectile yet.
