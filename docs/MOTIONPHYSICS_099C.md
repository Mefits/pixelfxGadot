# Lab 0.99c — staged impact flight and landing polish

Isolated from the failed overall 0.99b qualification; base commit 836cab4ba4e566b1c7b94510e5e3ef4cd6b432e7. No change to accepted Lab 1.0 RC1, Astra 0.91, Project N, or the 0.99b control.

Owner's artistic target: reference 3 is a pelvis-driven rearward launch, trunk folds, arms and legs travel forward, and the body rotates gradually in flight. Hold that readable silhouette briefly, then release into a quick but smooth back/upper-body landing, a visible ground slide and at most one or two small residual hops. No head-over-heels leg flip and no forced final down pose.

Three comparison lanes:
A: chest impulse, old short uniform motor fade, old floor material/damping (control).
B: chest impulse, staged local pose hold and fade, old floor material/damping (isolates flight-pose timing).
C: same staged pose hold, impulse applied at pelvis with a small upper lever, lower friction/linear damping and subtle restitution (tests pelvis-driven launch plus slide/bounce).

Only local joint targets are held; root remains dynamic. No kinematic legs during flight, no world-space pose/root motor, no scripted fall trajectory. Flight hold: torso/head and hip/knee targets held ~0.28–0.30s; arms release sooner; legs fade to residual tone by ~0.54s. Existing residual bands softened and damped. Physical profile C: friction .16, restitution .18, restitution threshold .05m/s, rolling resistance .03, linear damping .65, angular damping .9. Control A/B retain 0.22 friction, zero restitution and .9 linear/angular damping. Joint constraint tuning 120Hz; sweep 8/12/16 internal substeps.

Acceptance: same 120Hz model and horizontal impulse momentum conservation; joint-limit violation <8°, anchor residual <1 art unit, floor penetration <.6, FK proxy error <2, final speed <18, C post-contact COM slide between 15 and 45 art units; flight pose hold error <30°, bounce count <=2; two-body step+state-export p95 <500us; partial-support relative shape error <.1; no transform/velocity discontinuity on release; exact snapshot restore/replay at five cuts and independent-process trace equality. These are proxy gates; visual approval is separate. Box2D snapshots remain trusted in-process only; do not deserialize peer bytes. No self-collision, fighter-v-fighter contacts, Windows determinism or production integration claimed.

Actual Godot 4.4.1 capture, 318 frames, GIF ×1 and ×0.5. Review the rendered result before accepting the art direction.
