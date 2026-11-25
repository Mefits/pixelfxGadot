#!/usr/bin/env python3
"""Black-box SDK acceptance via public CLI, no internal runtime imports."""
import argparse
import json
import os
from pathlib import Path
import subprocess
import sys
import zipfile

p=argparse.ArgumentParser()
p.add_argument("--project",required=True)
p.add_argument("--out",required=True)
p.add_argument("--godot",default="godot")
a=p.parse_args()
out=Path(a.out).resolve()
out.mkdir(parents=True,exist_ok=False)
cli=Path(__file__).with_name("creature_sdk.py")
records=[]
def invoke(*args,expect=True,xvfb=False):
    cmd=[sys.executable,str(cli),"--godot",a.godot,"--project",a.project]
    if xvfb:cmd+=["--xvfb"]
    cmd+=list(map(str,args))
    r=subprocess.run(cmd,text=True,encoding="utf-8",capture_output=True,timeout=200)
    try:data=json.loads(r.stdout)
    except Exception:raise RuntimeError(r.stdout+r.stderr)
    assert bool(data.get("ok"))==expect and (r.returncode==0)==expect,(args,data,r.stderr)
    records.append({"command":list(map(str,args)),"exit":r.returncode,"result":data})
    (out/"commands.json").write_text(json.dumps(records,ensure_ascii=False,indent=2),encoding="utf-8")
    return data

assert len(invoke("list")["templates"])==37
assert len(invoke("list","creature")["templates"])==5
invoke("show","does_not_exist",expect=False)
base=out/"base.json"; mutant=out/"mutant.json"; grab=out/"grab.json"
invoke("clone","creature_tentacled",base)
patch=out/"patch.json"
patch.write_text(json.dumps({"id":"six_leg_mutant","name":"Six-leg mutant","payload":{"name":"Six-leg mutant","leg_count":6,"tail":4,"mass":1.4,"tentacles":2,"tentacle_segments":5}}))
invoke("patch",base,patch,mutant)
invoke("clone","physical_grab",grab)
invoke("validate",mutant)
invoke("compat",mutant,grab)
invoke("compat","creature_quadruped",grab,expect=False)
bad=out/"bad_patch.json";bad.write_text('{"payload":{"leg_count":7}}')
rejected=out/"rejected.json"
r=invoke("patch",mutant,bad,rejected,expect=False)
assert not rejected.exists() and any(e["path"]=="/payload/leg_count" for e in r["report"]["errors"])
invoke("clone","physical_grab",grab,expect=False)
move=invoke("simulate",mutant,"-",600)
assert move["displacement"][0]>10
sim=invoke("simulate",mutant,grab,600)
assert sim["hits"]==1 and sim["target_moved"]>2,sim
again=invoke("simulate",mutant,grab,600)
assert sim==again,"Fixed-tick replay differs"
capture=out/"grab_frames"
r=invoke("render",grab,capture,15,45,mutant,xvfb=True)
assert r["diagnostics"]["legs"]==6 and r["diagnostics"]["tentacles"]==2
assert r["diagnostics"]["ability_started"] and r["diagnostics"]["hits"]==1 and r["diagnostics"]["target_moved"]>2,r
assert r["unique_frames"]>5
invoke("media",capture)
for id in ("fx_5","anim_strike","ability_electric"):
    path=out/(id+".json");invoke("clone",id,path)
    r=invoke("render",path,out/(id+"_frames"),15,30,xvfb=True)
    assert r["unique_frames"]>3,r
    if id=="ability_electric":assert r["diagnostics"]["attacks"]==1,r
    invoke("media",out/(id+"_frames"))
body_zip=out/"mutant.zip"; ability_zip=out/"grab.zip"
invoke("export",mutant,body_zip);invoke("export",grab,ability_zip)
invoke("export",grab,ability_zip,expect=False)
clean=out/"clean_project"
with zipfile.ZipFile(ability_zip) as z:
    assert z.testzip() is None
    z.extractall(clean)
(clean/"content"/"creature.json").write_bytes(mutant.read_bytes())
for args in (["--editor","--import"],["--","--smoke","--anatomy","res://content/creature.json"]):
    proc=subprocess.run([a.godot,"--headless","--path",str(clean)]+args,text=True,encoding="utf-8",stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=80)
    (out/("clean_import.log" if args[0]=="--editor" else "clean_smoke.log")).write_text(proc.stdout,encoding="utf-8")
    assert proc.returncode==0 and not any(s in proc.stdout for s in ("SCRIPT ERROR","Parse Error","Failed to load script")),proc.stdout
    if args[0]=="--":
        assert "DEMO_SMOKE_OK" in proc.stdout
        data=json.loads(next(s.removeprefix("DEMO_DIAGNOSTICS ") for s in proc.stdout.splitlines() if s.startswith("DEMO_DIAGNOSTICS ")))
        assert data["legs"]==6 and data["tentacles"]==2 and data["hits"]==1 and data["target_moved"]>2,data
(out/"acceptance.json").write_text(json.dumps({"ok":True,"mode":"black_box_reference","independent_ai":False,"visual_review":False,"commands":len(records),"simulation":sim},ensure_ascii=False,indent=2),encoding="utf-8")
print("SDK_BLACK_BOX_OK",len(records))
