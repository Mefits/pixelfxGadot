"""Self-contained Windows project + official Godot executable; no compiler needed."""
from pathlib import Path
import os, shutil, subprocess, urllib.request
root=Path(__file__).resolve().parents[1]
dst=root/"dist"/"Lab-1.0-RC2"
dst.mkdir(parents=True,exist_ok=True)
src=root/"godot"
target=dst/"godot"
# Test fixtures contain the accepted body and motion data used by the workspaces.
shutil.copytree(src,target,dirs_exist_ok=True,ignore=shutil.ignore_patterns(".godot"))
p=target/".godot"
p.mkdir(exist_ok=True)
(p/"extension_list.cfg").write_text("res://addons/pixelfx/pixelfx.gdextension\nres://addons/motionphysics/motionphysics_099d.gdextension\n",encoding="utf-8")
console=Path(os.environ["GODOT"])
engine=console.with_name(console.name.replace("_console.exe",".exe"))
shutil.copy2(engine,dst/"Godot.exe")
# Windows console wrapper expects the matching executable basename.
shutil.copy2(console,dst/"Godot_console.exe")
for filename in ("LICENSE-PixelFX.txt","LICENSE-QuickJS-NG.txt","LICENSE-godot-cpp.txt"):
    shutil.copy2(root/filename,dst/filename)
for filename in ("LICENSE.txt","COPYRIGHT.txt"):
    urllib.request.urlretrieve("https://raw.githubusercontent.com/godotengine/godot/4.4.1-stable/"+filename,dst/("Godot-"+filename))
shutil.copy2(root/"docs"/"LAB_100_RU.md",dst/"LAB_100_RU.md")
shutil.copy2(root/"docs"/"MOTION_AUTHORING_RU.md",dst/"MOTION_AUTHORING_RU.md")
(dst/"START_LAB.bat").write_text('@echo off\ncd /d "%~dp0"\nstart "" "%~dp0Godot.exe" --path "%~dp0godot"\n',encoding="ascii")
required=["addons/pixelfx/bin/pixelfx.windows.x86_64.dll","addons/motionphysics/bin/motionphysics_099d.windows.x86_64.dll","generated/original_bundle.txt","generated/original_catalog.json","project.godot"]
for f in required:
    assert (target/f).is_file(),f
# Run from the packaged copy, not from checkout.
proc=subprocess.run([str(dst/"Godot_console.exe"),"--headless","--path",str(target),"--audio-driver","Dummy","--script","res://tests/lab_rc2_smoke.gd"],stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=180)
log=proc.stdout.decode("utf-8","replace")
print(log)
assert proc.returncode==0 and "RC2_SMOKE_OK" in log and "SCRIPT ERROR" not in log and "ERROR:" not in log
print("LAB_RC2_PORTABLE_OK")
