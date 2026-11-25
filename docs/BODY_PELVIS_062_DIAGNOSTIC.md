# Lab 0.62 — reference digitization and preliminary rig audit

Source: owner-provided frontal (1404x2048) and three-quarter (357x560) anatomy images. See body-pelvis-062-reference.json for 20 external and 7 internal cross-sections. Approximate edge locations, not measurements of skeletal joints. Reference images not committed.

Using chest slice y=650 (389 px), waist y=825 is .738, navel y=900 .774, pelvic transition y=975 .820, upper thighs y=1050 .928, just below visible crotch y=1125 .974, widest proximal thighs y=1200 .990. The interior gap grows from 7px to 78px at y=1400. Actual background separation begins approximately y=1122. The internal shaded inguinal lines above that are not silhouette edges. Three-quarter reference indicates anterior/posterior mass and continuous hip/thigh transition qualitatively; no depth recovery or inferred internal joint position. These are different levels than the four prior approximate 060 measurements, not contradictory measurements of identical levels.

## Source-derived root placement (not a pose capture)

* rig_049.gd: hip_x=sqrt(32)*sin(deg_to_rad(45-pelvis_turn)); near/far offsets +/-hip_x in parent's local x axis. At turn 0/90 the magnitude is 4; at 45 the projected roots coincide. Source humanoid knees offsets (+/-2,11), ankles opposite x offsets and 11 down, length sqrt(125) each. hips->chest 16 units.
* body_deformation_058.gd: render root z=sign*(2+1.3*sqrt(1-(abs(hip_x)/4)^2)); this is a visual depth estimate, not an FK z joint or a physical rotation.
* body_pelvis_060.gd: trunk cross-section at t=0 has half-width 4.088571, half-depth 3.371429, exponent 2.6. 060 B moves connector endpoint z inward .52 and offsets thigh sections; does not change original FK.

Analytical check at the pelvis t=0 plane: for each turn, compute trunk half-depth at x as h*(1-(abs(x)/w)^2.6)^(1/2.6). A positive z excess means the raw estimated render joint/connector endpoint is outside that trunk cross-section. Negative means inside. Does not include hip connector volume or shifted asymmetric thigh section centers, and does not assert that the actual whole body or human bone is outside.

| turn degrees | abs(x) | raw abs(z) | trunk half-depth at x | raw z excess | 060B connector-end z excess |
|---:|---:|---:|---:|---:|---:|
|0/90|4.000|2.000|1.108|.892|.372|
|15/75|2.828|2.919|2.799|.120|-.400|
|30/60|1.464|3.210|3.280|-.070|-.590|
|45|0|3.300|3.371|-.071|-.591|

At turn 0/90 the root is at ~97.8% of trunk projected half-width, and the connector endpoint still lies outside the trunk-only depth interval. This supports testing a visual proxy root inward correction, but is not proof the game rig is wrong. Preserve clip FK/IK/knee/ankle, compare proxy only separately after 062 visual review. Next obtain neutral and combat Godot skeleton overlay and test proxy vs ref-shaped geometry independently. No rig changes in this checkpoint.
