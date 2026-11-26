"""Start independent Godot processes and compare every transition exactly."""
import argparse
import json
import os
from pathlib import Path
import subprocess

parser = argparse.ArgumentParser()
parser.add_argument("--godot", default="godot")
parser.add_argument("--out", type=Path, required=True)
args = parser.parse_args()
args.out.mkdir(parents=True, exist_ok=True)
project = Path(__file__).resolve().parents[1] / "godot"
for hz in (60, 120):
    records = []
    for process in range(2):
        trace = args.out.resolve() / f"{hz}-{process}.txt"
        run = subprocess.run([args.godot, "--headless", "--path", str(project),
                              "--script", "res://tests/hybrid_091.gd", "--", str(hz)],
                             env={**os.environ, "HYBRID_TRACE": str(trace)},
                             capture_output=True, text=True, timeout=60)
        print(run.stdout, run.stderr, flush=True)
        run.check_returncode()
        if "SCRIPT ERROR" in run.stderr:
            raise RuntimeError("Godot script error")
        result = next(line[7:] for line in run.stdout.splitlines() if line.startswith("RESULT "))
        records.append(json.loads(result))
    if (args.out / f"{hz}-0.txt").read_bytes() != (args.out / f"{hz}-1.txt").read_bytes():
        raise RuntimeError(f"per-tick divergence at {hz} Hz")
    if records[0]["sha256"] != records[1]["sha256"]:
        raise RuntimeError(f"terminal state divergence at {hz} Hz")
    (args.out / f"{hz}.json").write_text(json.dumps(records, indent=2))
