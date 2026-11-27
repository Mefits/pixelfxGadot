from pathlib import Path
import shutil,zipfile,subprocess
root=Path("native").resolve()
project=root/"godot"
stage=Path("Lab-Dynamic-Guard")
shutil.copytree(project,stage/"godot",ignore=shutil.ignore_patterns(".godot"))
cache=stage/"godot"/".godot"
cache.mkdir()
(cache/"extension_list.cfg").write_text("res://addons/pixelfx/pixelfx.gdextension\nres://addons/motionphysics/motionphysics_099d.gdextension\n",encoding="utf-8")
for f in root.glob("LICENSE*.txt"):
    shutil.copy2(f,stage/f.name)
for f in ["LAB_100_RU.md","MOTION_AUTHORING_RU.md"]:
    if (root/f).is_file():shutil.copy2(root/f,stage/f)
shutil.copy2("docs/WALK_CONTROL_RU.md",stage/"WALK_CONTROL_RU.md")
(stage/"README-RU.txt").write_text("Lab Dynamic Guard. Полный проект без движка. Распакуйте в новую папку, откройте godot/project.godot в Godot 4.4.1 и нажмите F5. T — боевой стенд, A/D — ходьба, 1 — атака, R — сброс. Данные пользователя в отдельной папке PixelFX Lab Dynamic Guard; старые сохранения не изменяются. Нативные DLL включены. Не накладывайте на старый проект.",encoding="utf-8")
out=Path("Lab-Dynamic-Guard-Project.zip")
with zipfile.ZipFile(out,"w",zipfile.ZIP_DEFLATED,compresslevel=6) as z:
    for f in stage.rglob("*"):
        if f.is_file():z.write(f,f)
with zipfile.ZipFile(out) as z:
    assert z.testzip() is None
    z.extractall("fresh")
fresh=(Path("fresh")/stage/"godot").resolve()
required=["project.godot","addons/pixelfx/bin/pixelfx.windows.x86_64.dll","addons/motionphysics/bin/motionphysics_099d.windows.x86_64.dll","generated/original_bundle.txt","generated/original_catalog.json"]
for f in required:assert (fresh/f).is_file(),f
exe=str(root/"Godot_console.exe")
def run(args,marker=None):
    p=subprocess.run([exe,"--headless","--path",str(fresh)]+args,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=180)
    log=p.stdout.decode("utf-8","replace")
    print(log,flush=True)
    assert p.returncode==0 and "SCRIPT ERROR" not in log and "ERROR:" not in log and (marker is None or marker in log)
run(["--editor","--import"])
run(["--audio-driver","Dummy","--script","res://tests/lab_rc2_smoke.gd"],"RC2_SMOKE_OK")
run(["--audio-driver","Dummy","--script","res://tests/walk_control.gd"],"WALK_CONTROL_OK")
run(["--audio-driver","Dummy","--script","res://tests/training_control.gd"],"TRAINING_CONTROL_OK")
run(["--audio-driver","Dummy","--script","res://tests/lab_integration_100.gd"],"LAB_100_INTEGRATION_OK")
print("FULL_PROJECT_ZIP_OK",out.stat().st_size)
