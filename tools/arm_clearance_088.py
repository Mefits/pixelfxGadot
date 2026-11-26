"""Native 60Hz transition comparison. GIF at 30Hz normal / 30Hz half-speed (all 60Hz poses)."""
import argparse,json,subprocess
from pathlib import Path
import numpy as np
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
def main():
    p=argparse.ArgumentParser()
    p.add_argument("--godot",required=True)
    p.add_argument("--out",type=Path,required=True)
    a=p.parse_args();out=a.out.resolve();out.mkdir(parents=True,exist_ok=True)
    cmd=["xvfb-run","-a",a.godot,"--path",str(ROOT/"godot"),"--audio-driver","Dummy","--disable-vsync","--rendering-method","gl_compatibility","--script","res://tests/arm_clearance_088.gd","--",str(out)]
    try:r=subprocess.run(cmd,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=160)
    except subprocess.TimeoutExpired as e:
        (out/"engine.log").write_bytes(e.stdout or b"");raise
    log=r.stdout.decode("utf8","replace");(out/"engine.log").write_text(log);print(log,flush=True)
    if r.returncode or "ARMS_088_CAPTURE_OK" not in log or "SCRIPT ERROR" in log:raise RuntimeError(log[-4000:])
    rows=json.loads((out/"records.json").read_text());assert len(rows)==366

    frames=[Image.open(out/f"frame-{i:03d}.png").convert("RGB") for i in range(len(rows))]
    for step,suffix in ((2,"1x"),(1,"half")):
        images=frames[::step]
        ends=[round((i+1)/30*100)*10 for i in range(len(images))]
        images[0].save(out/f"comparison-{suffix}.gif",save_all=True,append_images=images[1:],duration=np.diff([0,*ends]).tolist(),loop=0,disposal=1)
        with Image.open(out/f"comparison-{suffix}.gif") as im:
            delays=[]
            for i in range(im.n_frames):im.seek(i);delays.append(im.info["duration"])
            assert sum(delays)==ends[-1]
    sheet=Image.new("RGB",(576,264*8))
    for j,k in enumerate((59,65,76,100,155,242,257,330)):sheet.paste(frames[k],(0,j*264))
    sheet.save(out/"review.png")
    def crossing(a,b,c,d):
        u=b-a;v=d-c
        cross=lambda x,y: x[0]*y[1]-x[1]*y[0]
        den=cross(u,v)
        if abs(den)<1e-8:return False
        return 0<cross(c-a,v)/den<1 and 0<cross(c-a,u)/den<1
    metrics={}
    for lane,name in enumerate(("A original","B staged arms")):
        data=[r["lanes"][lane] for r in rows]
        hits=[];ext_hits=[]
        for tick,v in enumerate(data):
            q={k:np.array(p) for k,p in v["points"].items()}
            if lane:
                old=rows[tick]["lanes"][0]
                assert v["travel"]==old["travel"] and v["foot_start"]==old["foot_start"]
                for id in q:
                    if id.startswith(("shoulder","elbow","hand")):continue
                    assert np.allclose(q[id],old["points"][id],atol=1e-5,rtol=0), (tick,id)
            for s in ("near","far"):
                sh,el,ha=[q[k+"_"+s] for k in ("shoulder","elbow","hand")]
                tip=ha+2.55*(ha-el)/np.linalg.norm(ha-el)
                for t in ("near","far"):
                    for a,b in ((q["thigh_"+t],q["knee_"+t]),(q["knee_"+t],q["foot_"+t])):
                        if crossing(sh,el,a,b) or crossing(el,ha,a,b):hits.append(tick)
                        if crossing(sh,el,a,b) or crossing(el,tip,a,b):ext_hits.append(tick)
        metrics[name]={"projected_crossing_frames":len(set(hits)),"crossing_ticks":sorted(set(hits)),"extended_hand_crossing_frames":len(set(ext_hits)),"extended_ticks":sorted(set(ext_hits)),"pose_p95_us":float(np.percentile([v["pose_us"] for v in data],95)),"toe_error_max":max(v["error"] for v in data),"max_joint_step":max(v["joint_jump"] for v in data)}
    assert metrics["A original"]["projected_crossing_frames"]>0
    assert metrics["B staged arms"]["projected_crossing_frames"]==0
    assert metrics["B staged arms"]["extended_hand_crossing_frames"]==0
    import shutil
    if shutil.which("ffmpeg"):
        subprocess.run(["ffmpeg","-y","-loglevel","error","-framerate","60","-i",str(out/"frame-%03d.png"),"-c:v","libx264","-pix_fmt","yuv420p","-movflags","+faststart",str(out/"comparison-60fps.mp4")],check=True)
    (out/"metrics.json").write_text(json.dumps(metrics,indent=2));print(json.dumps(metrics),flush=True)
    print("ARMS_088_REVIEW_OK")
if __name__=="__main__":main()
