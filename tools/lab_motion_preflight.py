"""Fast gate: no native builds, expose script failures before expensive CI."""
import os
import subprocess

base = [os.environ["GODOT"], "--headless", "--path", "godot", "--audio-driver", "Dummy", "--script"]
for script, args, marker in [
    ("tests/walk_control.gd", [], "WALK_CONTROL_OK"),
    ("tests/editor_parse.gd", [], "EDITOR_RESOURCE_PARSE res://lab/authoring/editor.gd true"),
    ("tests/motion_authoring.gd", ["60"], "TRACE "),
    ("tests/motion_authoring.gd", ["120"], "TRACE "),
]:
    try:
        p = subprocess.run(base + ["res://" + script] + (["--"] + args if args else []),
                           stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=45)
    except subprocess.TimeoutExpired as exc:
        print((exc.stdout or b"").decode("utf-8", "replace"), flush=True)
        raise RuntimeError(script + " timed out") from exc
    log = p.stdout.decode("utf-8", "replace")
    print(log, flush=True)
    assert p.returncode == 0 and marker in log and "SCRIPT ERROR" not in log and "ERROR:" not in log, script
print("LAB_PREFLIGHT_OK")
