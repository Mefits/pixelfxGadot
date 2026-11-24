# Optional compiled lightning raster
The original GDScript path remains intact. C++ handles complete stroke/crackle (including light) in one call, with two packed buffers returned to Painter. It does not alter procedural geometry or particle physics.
Build on Linux/Windows x86-64 with Python, SCons, Git and GCC/MSVC: python native_cpp/build.py. This pins godot-cpp to Godot 4.4.1. The .gdextension descriptor is copied only after successful build. No binary required for ordinary use.
The accelerator is opt-in; use lightning.enable_acceleration(true), which returns false if unavailable. Never claim faster rendering or exact parity until CI results are inspected.
