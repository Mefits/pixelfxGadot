# Creature toolkit CI checkpoint

v0.26 — integration of animation markers, VFX runtime, preview, quick adjustment and multi-phase abilities. One full import, regression suite, visual tests and packaging. Future routine pushes need not start this workflow; change this checkpoint only for meaningful validation milestones. The reference v0.21 remains available at 71a483d.

Retry: run 45459076664 passed combat and visual tests; one VFX save/load assertion failed on dictionary identity. Preserve full floating-point precision, compare complete JSON data recursively (numeric type normalization only, tight tolerance), and verify pixel parity of both embedded effects. Re-run complete suite; no acceptance criteria removed.

## v0.27 catalogue checkpoint
Unified launcher, 27 templates, JSON imports and independent library copies, lazy previews and editor handoffs. Run complete regressions plus catalogue launcher tests. No changes to the v0.26 Windows release artifact.
