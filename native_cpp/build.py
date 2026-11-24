"""Build opt-in extension. Requires Git, Python/SCons and native C++ compiler."""
from pathlib import Path
import subprocess, shutil, sys
root=Path(__file__).resolve().parent
dep=root/"godot-cpp"
rev="e4b7c25e721ce3435a029087e3917a30aa73f06b"
def run(*args,cwd=root): subprocess.run(args,cwd=cwd,check=True)
if not dep.exists():
    run("git","clone","--no-checkout","https://github.com/godotengine/godot-cpp.git",str(dep))
run("git","checkout","--detach",rev,cwd=dep)
run("git","submodule","update","--init","--recursive",cwd=dep)
platform="windows" if sys.platform=="win32" else "linux"
if sys.platform not in ("win32","linux"): raise SystemExit("Currently supports Windows/Linux x86-64 only")
run("scons","platform="+platform,"arch=x86_64","target=template_release","build_profile="+str(root/"build_profile.json"),"-j4")
shutil.copy2(root/"pixelfx.gdextension",root.parent/"godot/addons/pixelfx/pixelfx.gdextension")
