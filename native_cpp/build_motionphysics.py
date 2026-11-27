"""Optional pinned Box2D extension; run after build.py, with Godot closed."""
from pathlib import Path
import os, shutil, subprocess, sys
root=Path(__file__).resolve().parent
rev="178495ba35695aefe9c321e569d2277f06db3b90"
def run(*args,cwd=root,env=None): subprocess.run(args,cwd=cwd,env=env,check=True)
if sys.platform not in ("win32","linux"): raise SystemExit("Windows/Linux x86-64 only")
platform="windows" if sys.platform=="win32" else "linux"
if not (root/"godot-cpp"/"SConstruct").exists(): raise SystemExit("Run native_cpp/build.py first")
box=root/"box2d-3.2.0"
if not box.exists(): run("git","clone","--no-checkout","https://github.com/erincatto/box2d.git",str(box))
run("git","checkout","--detach",rev,cwd=box)
assert subprocess.check_output(["git","rev-parse","HEAD"],cwd=box,text=True).strip()==rev
build=root/"box2d-build"
run("cmake","-S",str(box),"-B",str(build),"-DCMAKE_BUILD_TYPE=Release","-DCMAKE_POSITION_INDEPENDENT_CODE=ON","-DBUILD_SHARED_LIBS=OFF","-DBOX2D_SAMPLES=OFF","-DBOX2D_UNIT_TESTS=OFF","-DBOX2D_BENCHMARKS=OFF","-DCMAKE_POLICY_DEFAULT_CMP0091=NEW","-DCMAKE_MSVC_RUNTIME_LIBRARY=MultiThreaded")
run("cmake","--build",str(build),"--config","Release","--target","box2d","--parallel","4")
libs=list(build.rglob("box2d.lib" if platform=="windows" else "libbox2d.a"))
if len(libs)!=1: raise RuntimeError(f"Expected one Box2D static lib, found {libs}")
env=os.environ.copy()
env.update(MOTION_BOX2D_INCLUDE=str(box/"include"),MOTION_BOX2D_LIB=str(libs[0].resolve()))
out=root.parent/"godot/addons/motionphysics"
(out/"bin").mkdir(parents=True,exist_ok=True)
run("scons","-f","MotionPhysics099D.scons","platform="+platform,"arch=x86_64","target=template_release","build_profile="+str(root/"build_profile.json"),"-j4",env=env)
binary=out/"bin"/("motionphysics_099d.windows.x86_64.dll" if platform=="windows" else "libmotionphysics_099d.linux.x86_64.so")
if not binary.is_file(): raise RuntimeError(f"Missing {binary}")
shutil.copy2(root/"motionphysics_099d.gdextension",out/"motionphysics_099d.gdextension")
shutil.copy2(box/"LICENSE",out/"BOX2D_LICENSE.txt")
print("MOTIONPHYSICS_BUILD_OK",rev,binary)
