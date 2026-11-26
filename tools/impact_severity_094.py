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
    cmd=["xvfb-run","-a",a.godot,"--path",str(ROOT/"godot"),"--audio-driver","Dummy","--disable-vsync","--rendering-method","gl_compatibility","--script","res://tests/impact_severity_094.gd","--",str(out)]
    try:r=subprocess.run(cmd,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=160)
    except subprocess.TimeoutExpired as e:
        (out/"engine.log").write_bytes(e.stdout or b"");raise
    log=r.stdout.decode("utf8","replace");(out/"engine.log").write_text(log);print(log,flush=True)
    if r.returncode or "IMPACT_094_CAPTURE_OK" not in log or "SCRIPT ERROR" in log:raise RuntimeError(log[-4000:])
    rows=json.loads((out/"records.json").read_text());assert len(rows)==132

    frames=[Image.open(out/f"frame-{i:03d}.png").convert("RGB") for i in range(len(rows))]
    for step,suffix in ((2,"1x"),(1,"half")):
        images=frames[::step]
        ends=[round((i+1)/30*100)*10 for i in range(len(images))]
        images[0].save(out/f"comparison-{suffix}.gif",save_all=True,append_images=images[1:],duration=np.diff([0,*ends]).tolist(),loop=0,disposal=1)
        with Image.open(out/f"comparison-{suffix}.gif") as im:
            delays=[]
            for i in range(im.n_frames):im.seek(i);delays.append(im.info["duration"])
            assert sum(delays)==ends[-1]
    metrics={}
    for lane,name in enumerate(("A light","B medium","C heavy")):
        data=[r["lanes"][lane] for r in rows]
        assert all(v["accepted"]==int(i>=18) for i,v in enumerate(data))
        assert max(v["error"] for v in data)<.01
        pts=[v["points"] for v in data]
        shift=pts[-1]["hips"][0]-pts[0]["hips"][0]
        anchors=np.array([[v["anchors"][s] for s in ("near","far")] for v in data])
        assert np.max(np.abs(anchors[:18]-anchors[0]))<1e-5
        air=[i for i,v in enumerate(data) if v["phase"]=="AIR"]
        if lane==0:
            assert abs(shift)<.1 and all(v["support_count"]==2 for v in data)
            assert np.max(np.abs(anchors-anchors[0]))<1e-5
        elif lane==1:
            assert -8.1<shift<-7.9 and data[-1]["steps"]==2
            assert all(v["support_count"]>=1 for v in data)
            assert np.max(np.abs(anchors[-1,:,0]-anchors[0,:,0]+8))<1e-5
            for i in range(1,len(data)):
                assert min(np.linalg.norm(anchors[i]-anchors[i-1],axis=1))<1e-5
        else:
            assert shift<-24. and len(air)>15
            assert max(data[i]["clearance"] for i in air)>5.
            assert data[-1]["phase"]=="CONTACT" and abs(data[-1]["clearance"])<.01
            assert all(data[i]["support_count"]==0 for i in air)
            # Third reference: limbs project ahead of hips in early flight.
            assert any(min(pts[i]["foot_near"][0],pts[i]["foot_far"][0])-pts[i]["hips"][0]>12 and min(pts[i]["hand_near"][0],pts[i]["hand_far"][0])-pts[i]["hips"][0]>5 for i in air)
        metrics[name]={"root_shift_x":shift,"steps":data[-1]["steps"],"air_ticks":len(air),"max_clearance":max(v["clearance"] for v in data),"support_error_max":max(v["error"] for v in data),"pose_p95_us":float(np.percentile([v["pose_us"] for v in data],95)),"max_joint_step":max(v["joint_jump"] for v in data)}
    sheet=Image.new("RGB",(1152,272*8))
    for j,k in enumerate((0,19,24,31,42,55,67,84)):sheet.paste(frames[k],(0,j*272))
    sheet.save(out/"review.png")
    import shutil
    if shutil.which("ffmpeg"):
        subprocess.run(["ffmpeg","-y","-loglevel","error","-framerate","60","-i",str(out/"frame-%03d.png"),"-c:v","libx264","-pix_fmt","yuv420p","-movflags","+faststart",str(out/"comparison-60fps.mp4")],check=True)
    (out/"metrics.json").write_text(json.dumps(metrics,indent=2))
    print(json.dumps(metrics),flush=True)
    print("IMPACT_094_REVIEW_OK")
if __name__=="__main__":main()
