# Roadmap and gates
- M0: locked upstream, portable repository and agent contract.
- M1: original JS export, separate color/light, channel parity test against composite, Godot playback and lab. Verify with CI, then inspect rendered screenshots.
- M2: automated original versus Godot capture comparison on dark/bright backgrounds, stress benchmark and paging.
- M3: native Painter, 4x4 Bayer, palette, deterministic RNG, fixed-step simulation; reference pixel tests.
- M4: native Particles/Bits/Lights, then lightning, charge, explosion, acid, slash. Each effect must pass parity and frame-budget tests before more ports.
- M5: actor mask and poses, live collision hooks, authoring UI, installable add-on, versioned documentation.
No milestone is accepted simply because code exists. Record passed/failed/not-run separately. The original JS source is never replaced by a similar algorithm.
