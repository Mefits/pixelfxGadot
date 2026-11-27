from pathlib import Path
import os, subprocess
root=Path(__file__).resolve().parents[1]
p=subprocess.run([os.environ["GODOT"],"--headless","--path",str(root/"godot"),"--audio-driver","Dummy","--script","res://tests/lab_rc2_smoke.gd"],stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=180)
log=p.stdout.decode("utf-8","replace")
print(log)
(root/"results"/"rc2-smoke.log").write_text(log,encoding="utf-8")
assert p.returncode==0 and "RC2_SMOKE_OK" in log and "SCRIPT ERROR" not in log and "ERROR:" not in log
