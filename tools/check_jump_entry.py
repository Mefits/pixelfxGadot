"""Run the same native scripts against pinned v14 and the candidate."""
import os
from pathlib import Path
import subprocess
import sys
import tempfile

base, head = map(Path, sys.argv[1:])
engine = os.environ.get("GODOT", "godot")
tests = "run_v14 adaptive_jump double_jump_v13 adaptive_attack attack_recovery fighter_profile dynamic_guard adaptive_guard training_control walk_control".split()


def execute(project, script, args=()):
    with tempfile.TemporaryDirectory() as home:
        env = dict(os.environ, XDG_DATA_HOME=home)
        proc = subprocess.run([engine, "--headless", "--path", str(project),
                               "--script", str(script), *args], env=env, timeout=75,
                              stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    errors = [line.strip() for line in proc.stdout.splitlines()
              if "ERROR:" in line]
    print(project, script, proc.returncode, proc.stdout, flush=True)
    return proc.returncode, sorted(errors)


failed = False
for name in tests:
    script = f"res://tests/{name}.gd"
    original = execute(base, script)
    candidate = execute(head, script)
    if candidate != (0, []) and candidate != original:
        failed = True
probe = (head / "tests/run_jump_entry.gd").resolve()
for project, args in [(base, ["--", "baseline"]), (head, [])]:
    if execute(project, probe, args) != (0, []):
        failed = True
sys.exit(int(failed))
