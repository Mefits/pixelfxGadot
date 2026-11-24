"""Build opt-in extension. Requires Git, Python/SCons and native C++ compiler."""
from pathlib import Path
import subprocess, shutil, sys, os
root=Path(__file__).resolve().parent
dep=root/"godot-cpp"
rev="e4b7c25e721ce3435a029087e3917a30aa73f06b"
def run(*args,cwd=root,env=None): subprocess.run(args,cwd=cwd,check=True,env=env)
if not dep.exists():
    run("git","clone","--no-checkout","https://github.com/godotengine/godot-cpp.git",str(dep))
run("git","checkout","--detach",rev,cwd=dep)
run("git","submodule","update","--init","--recursive",cwd=dep)
platform="windows" if sys.platform=="win32" else "linux"
if sys.platform not in ("win32","linux"): raise SystemExit("Currently supports Windows/Linux x86-64 only")
env=os.environ.copy()
if "--original" in sys.argv:
    qjs=root/"quickjs-ng"
    qrev="d7215b0ad3fc2c562e8317fd9bca058fd4863804"
    if not qjs.exists():
        run("git","clone","--no-checkout","https://github.com/quickjs-ng/quickjs.git",str(qjs))
    run("git","checkout","--detach",qrev,cwd=qjs)
    out=root/"quickjs-build"
    run("cmake","-S",str(qjs),"-B",str(out),"-DBUILD_SHARED_LIBS=OFF","-DQJS_ENABLE_INSTALL=OFF","-DQJS_BUILD_LIBC=OFF","-DCMAKE_BUILD_TYPE=Release","-DCMAKE_POSITION_INDEPENDENT_CODE=ON","-DCMAKE_MSVC_RUNTIME_LIBRARY=MultiThreaded")
    run("cmake","--build",str(out),"--config","Release","--target","qjs","--parallel","4")
    candidates=list(out.rglob("qjs.lib" if platform=="windows" else "libqjs.a"))
    if len(candidates)!=1: raise RuntimeError(f"Expected one static QuickJS lib, got {candidates}")
    env["PIXELFX_QJS_LIB"]=str(candidates[0].resolve())
run("scons","platform="+platform,"arch=x86_64","target=template_release","build_profile="+str(root/"build_profile.json"),"-j4",env=env)
shutil.copy2(root/"pixelfx.gdextension",root.parent/"godot/addons/pixelfx/pixelfx.gdextension")
