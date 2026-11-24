#!/usr/bin/env python3
"""Build the source-only runtime asset from an overlaid verified project."""
import argparse
import re
from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED

p=argparse.ArgumentParser()
p.add_argument("--project",type=Path,required=True)
p.add_argument("--example",type=Path,required=True)
p.add_argument("--licenses",type=Path,required=True)
args=p.parse_args()
root=args.project
files={}
for directory in ("addons/creature","addons/pixelfx/native","addons/pixelfx/composer"):
    for f in sorted((root/directory).glob("*.gd")):
        if f.name in ("catalog.gd","kit_export.gd"): continue
        files[f.relative_to(root).as_posix()]=f.read_bytes()
for n in ("project.godot","README.md"):
    files[n]=(args.example/n).read_bytes()
for n in ("demo.gd","demo.tscn"):
    files["example/"+n]=(args.example/n).read_bytes()
for n in ("LICENSE-PixelFX.txt","LICENSE-godot-cpp.txt","LICENSE-QuickJS-NG.txt"):
    files[n]=(args.licenses/n).read_bytes()
for path,data in files.items():
    if not path.endswith((".gd",".tscn")):continue
    for ref in re.findall(rb'res://([^"\s]+\.gd)',data):
        if ref.decode() not in files:raise SystemExit(f"Missing dependency: {path} -> {ref!r}")
assert "addons/creature/kit_api.gd" in files
out=root/"portable/runtime.zip"
out.parent.mkdir(exist_ok=True)
with ZipFile(out,"w",ZIP_DEFLATED,compresslevel=9) as z:
    for name,data in sorted(files.items()):z.writestr(name,data)
with ZipFile(out) as z:
    assert z.testzip() is None
print(f"Runtime source archive: {len(files)} files, {out.stat().st_size} bytes")
