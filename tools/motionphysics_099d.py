import argparse,json,subprocess
from pathlib import Path
import numpy as np
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
def run(cmd,log,marker):
    p=subprocess.run(cmd,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=360)
    s=p.stdout.decode("utf8","replace");log.write_text(s);print(s,flush=True)
    if p.returncode or marker not in s or "SCRIPT ERROR" in s or "ERROR:" in s:
        raise RuntimeError(s[-6000:])
def main():
    p=argparse.ArgumentParser()
    p.add_argument("--godot",required=True)
    p.add_argument("--out",type=Path,required=True)
    a=p.parse_args();out=a.out.resolve();out.mkdir(parents=True,exist_ok=True)
    base=[a.godot,"--path",str(ROOT/"godot"),"--audio-driver","Dummy"]
    for folder in (out,out/"repeat"):
        folder.mkdir(exist_ok=True)
        run(base+["--headless","--script","res://tests/motionphysics_099d.gd","--",str(folder)],folder/"test.log","MOTIONPHYSICS_099D_TEST_OK")
    report=json.loads((out/"qualification.json").read_text())
    report["fresh_process_exact"]={}
    for name in ("profileA","profileB","profileC"):
        a1=json.loads((out/(name+".json")).read_text())
        a2=json.loads((out/"repeat"/(name+".json")).read_text())
        exact=[v["state"] for v in a1]==[v["state"] for v in a2]
        report["fresh_process_exact"][name]=exact
        if not exact:report["failures"].append("fresh process "+name)
    report["qualified"]=not report["failures"] and report["selected"]>0
    (out/"qualification.json").write_text(json.dumps(report,indent=2))
    run(["xvfb-run","-a"]+base+["--disable-vsync","--rendering-method","gl_compatibility","--script","res://tests/motionphysics_render_099d.gd","--",str(out)],out/"render.log","MOTIONPHYSICS_099D_RENDER_OK")
    rows=json.loads((out/"records.json").read_text())
    assert len(rows)==318
    frames=[Image.open(out/f"frame-{i:03d}.png").convert("RGB") for i in range(len(rows))]
    for step,suffix in ((2,"1x"),(1,"half")):
        images=frames[::step]
        ends=[round((i+1)/30*100)*10 for i in range(len(images))]
        file=out/f"comparison-{suffix}.gif"
        images[0].save(file,save_all=True,append_images=images[1:],duration=np.diff([0,*ends]).tolist(),loop=0,disposal=1)
        with Image.open(file) as im:
            delays=[]
            for i in range(im.n_frames):im.seek(i);delays.append(im.info["duration"])
            assert sum(delays)==ends[-1]
    w,h=frames[0].size
    sheet=Image.new("RGB",(w,h*12))
    for j,k in enumerate((0,18,24,32,44,60,75,90,110,150,220,317)):
        sheet.paste(frames[k],(0,j*h))
    sheet.save(out/"review.png")
    print("MOTIONPHYSICS_099D_RESULT",json.dumps(report),flush=True)
    assert report["qualified"],report["failures"]
if __name__=="__main__":main()
