> **Lab 1.0 RC1:** нативное расширение обязательно для стенда H (PixelFXBodyRaster); для прежнего офлайн PixelFX остаётся необязательным. См. [актуальное руководство](../docs/LAB_100_RU.md). Ниже исторические инструкции и архивы.

# Optional compiled lightning raster
The original GDScript path remains intact. C++ handles complete stroke/crackle (including light) in one call, with two packed buffers returned to Painter. It does not alter procedural geometry or particle physics.
Build on Linux/Windows x86-64 with Python, SCons, Git and GCC/MSVC: python native_cpp/build.py. This pins godot-cpp to Godot 4.4.1. The .gdextension descriptor is copied only after successful build. No binary required for ordinary use.
The accelerator is opt-in; use lightning.enable_acceleration(true), which returns false if unavailable. Measured results and verified binary downloads are in docs/STATUS.md and README.md at repository root.

### Downloads and installation (Godot 4.4.1, x86-64)
1. [Portable toolkit](https://github.com/Mefits/pixelfxGadot/actions/runs/45385382460/artifacts/14916235866).
2. [Windows accelerator](https://github.com/Mefits/pixelfxGadot/actions/runs/45385289890/artifacts/14916126309) or [Linux accelerator](https://github.com/Mefits/pixelfxGadot/actions/runs/45385289890/artifacts/14916185762).
3. Extract the toolkit; close Godot. Copy the accelerator archive contents (pixelfx.gdextension and bin/ with the corresponding DLL/SO) into godot/addons/pixelfx/. Open godot/project.godot, run, press L for the native lab, hold LMB, A toggles backend. HUD reports C++ or GDScript. To remove the extension, close Godot and remove the descriptor and bin/; GDScript remains usable. No compiler needed when using tested binary. GitHub login may be required for artifacts; artifacts expire according to repository settings.
