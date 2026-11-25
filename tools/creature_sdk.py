#!/usr/bin/env python3
"""Portable agent entrypoint; no third-party packages required except optional media."""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys

def run(argv, *, check=True):
    proc=subprocess.run(argv, text=True, encoding="utf-8", errors="replace", stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=180)
    lines=proc.stdout.splitlines()
    reports=[s[len("CREATURE_SDK "):] for s in lines if s.startswith("CREATURE_SDK ")]
    if not reports:
        raise RuntimeError("Godot did not return SDK JSON:\n"+proc.stdout[-12000:])
    data=json.loads(reports[-1])
    bad=any(s.startswith(("SCRIPT ERROR:", "Parse Error:")) for s in lines)
    if bad or (proc.returncode==0)!=bool(data.get("ok")):
        raise RuntimeError("SDK status mismatch or script error:\n"+proc.stdout[-12000:])
    if check and proc.returncode:
        raise RuntimeError(json.dumps(data,ensure_ascii=False))
    return data,proc.returncode

def media(folder):
    from PIL import Image, ImageDraw
    folder=Path(folder)
    report=json.loads((folder/"report.json").read_text(encoding="utf-8"))
    frames=[]
    import hashlib
    for frame in report["frames"]:
        path=folder/frame["file"]
        if path.parent!=folder or hashlib.sha256(path.read_bytes()).hexdigest()!=frame["sha256"]:
            raise ValueError("Frame integrity failed: "+str(path))
        frames.append(Image.open(path).convert("RGB"))
    if not frames:raise ValueError("No frames")
    gif=folder/"animation.gif"
    sheet=folder/"contact_sheet.png"
    if gif.exists() or sheet.exists():raise FileExistsError("Media output already exists")
    frames[0].save(gif,save_all=True,append_images=frames[1:],duration=round(1000/report["fps"]),loop=0,optimize=False)
    indices=sorted({round(i*(len(frames)-1)/11) for i in range(12)})
    canvas=Image.new("RGB",(4*320,((len(indices)+3)//4)*200),(22,33,45))
    draw=ImageDraw.Draw(canvas)
    for n,i in enumerate(indices):
        x=n%4*320;y=n//4*200
        canvas.paste(frames[i],(x,y))
        draw.text((x+5,y+182),f'{i:04d}  {report["frames"][i]["time"]:.3f}s',fill=(220,230,240))
    canvas.save(sheet)
    return {"ok":True,"gif":str(gif),"contact_sheet":str(sheet)}

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument("--godot",default=os.environ.get("GODOT_BIN","godot"))
    p.add_argument("--project",default=str(Path(__file__).resolve().parent.parent/"godot"))
    p.add_argument("--xvfb",action="store_true",help="Launch graphical capture via xvfb-run (Linux)")
    p.add_argument("command",choices=["help","list","show","clone","patch","validate","compat","simulate","export","render","media"])
    p.add_argument("args",nargs="*")
    opt=p.parse_args()
    try:
        if opt.command=="media":
            if len(opt.args)!=1:raise ValueError("media OUT_DIR")
            print(json.dumps(media(Path(opt.args[0]).resolve()),ensure_ascii=False))
            return 0
        project=Path(opt.project).resolve()
        if not (project/"project.godot").is_file():raise ValueError("Not a Godot project: "+str(project))
        args=list(opt.args)
        path_positions={"clone":[1],"patch":[0,1,2],"validate":[0],"compat":[0,1],"simulate":[0,1],"export":[0,1],"render":[0,1,4]}
        for i in path_positions.get(opt.command,[]):
            if i>=len(args) or args[i]=="-" or args[i].startswith(("res://","user://")):continue
            if opt.command in ("compat","simulate","export") and i==0 and not args[i].endswith(".json") and not Path(args[i]).exists():continue
            if opt.command in ("compat","simulate") and i==1 and not args[i].endswith(".json") and not Path(args[i]).exists():continue
            args[i]=str(Path(args[i]).resolve())
        render=opt.command=="render"
        argv=[opt.godot,"--path",str(project)]
        if render:
            if opt.xvfb:
                if not shutil.which("xvfb-run"):raise RuntimeError("xvfb-run missing")
                argv=["xvfb-run","-a"]+argv
            argv+=["--rendering-method","gl_compatibility","--script","res://sdk/render.gd","--"]+args
        else:
            argv+=["--headless","--script","res://sdk/cli.gd","--",opt.command]+args
        report,code=run(argv,check=False)
        print(json.dumps(report,ensure_ascii=False))
        return code
    except (OSError,ValueError,RuntimeError,subprocess.TimeoutExpired,ImportError) as exc:
        print(json.dumps({"ok":False,"error":str(exc)},ensure_ascii=False))
        return 2
if __name__=="__main__":
    sys.exit(main())
