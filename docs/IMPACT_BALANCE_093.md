# Lab 0.93 — predictive grounded loss of balance (2026-11-26)

Base: accepted integration RC1 82814f808332c1bed2b9ca65b047fb4fd9a69a56 (CI 45884209993 success). Separate experiment; do not modify Astra core or editor branch, Project N, or the 092 control. Native CI pending.

## Reference interpretation
Four owner-supplied static images, not mocap or measured kinetics. 1: back-leaning body, one foot planted, other forward/free, bent arms trying to stabilize. This is the artistic target for 093, not exact retarget. 2: backward arch, head/shoulders trail, legs hang; 3: folded trunk with feet and hands forward. Owner notes 2 and 3 differ strongly in kinetics: treat as distinct flight families (extension vs folding), NOT compulsory successive keyframes. 4: pre-back-landing rotation, legs lifted. Defer flight and impact with floor to later experiments. No binary reference redistribution.

## Comparison
A exact 092 C, explicit step at final event. B automatic recovery policy: weighted joint-position center proxy and signed decaying translation momentum, extrapolate 0.11 s, compare predicted X with ankle support interval. Hit adds 65*power^2 signed velocity proxy, decay .86/tick, max 155. Threshold based on geometry, not event index; recovery step chosen toward escaped side, length 4.5–5.8 by overshoot. C B plus extra lean 9° hips, 15° chest, 5° head and delayed asymmetric arms, same anchored foot and 069 geometry. Compensating step is still planned trajectory, not physical falling; weighted center not measured COM; no force model or gameplay rules. Ordinary hits should not translate base, strong hits may cause recovery; do not infer hitstun or launch from visuals. No full collision or cross-platform claim.

## Acceptance
Native Godot 4.4.1 raster and 270 ticks at 60Hz, frozen fixture, same original schedule, A exact control, B/C single autonomous recovery, no step on earlier ordinary hits, solo ordinary/strong both directions, duplicate and snapshot replay (before and during step), fixed support, anatomy limits, no clipping, final stance, joint displacement and lean. GIF ×1/×0.5. Art review open. Further experiments test independent launch extension/folding profiles, rotational momentum, floor contact. Design data/target contract for later integration into Astra; do not change accepted kernel before review.
