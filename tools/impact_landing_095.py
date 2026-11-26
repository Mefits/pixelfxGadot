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
    cmd=["xvfb-run","-a",a.godot,"--path",str(ROOT/"godot"),"--audio-driver","Dummy","--disable-vsync","--rendering-method","gl_compatibility","--script","res://tests/impact_landing_095.gd","--",str(out)]
    try:r=subprocess.run(cmd,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=160)
    except subprocess.TimeoutExpired as e:
        (out/"engine.log").write_bytes(e.stdout or b"");raise
    log=r.stdout.decode("utf8","replace");(out/"engine.log").write_text(log);print(log,flush=True)
    if r.returncode or "IMPACT_095_CAPTURE_OK" not in log or "SCRIPT ERROR" in log:raise RuntimeError(log[-4000:])
    rows=json.loads((out/"records.json").read_text());assert len(rows)==156

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
    for lane,name in enumerate(("A light unchanged","B medium slip + steps","C heavy fold + fall")):
        data=[r["lanes"][lane] for r in rows]
        assert all(v["accepted"]==int(i>=18) for i,v in enumerate(data))
        assert max(v["error"] for v in data)<.01
        pts=[v["points"] for v in data]
        shift=pts[-1]["hips"][0]-pts[0]["hips"][0]
        anchors=np.array([[v["anchors"][s] for s in ("near","far")] for v in data])
        assert np.max(np.abs(anchors[:18]-anchors[0]))<1e-5
        air=[i for i,v in enumerate(data) if v["phase"]=="AIR"]
        contact=[i for i,v in enumerate(data) if v["phase"]=="CONTACT"]
        fall=[i for i,v in enumerate(data) if v["phase"]=="FALL"]
        down=[i for i,v in enumerate(data) if v["phase"]=="DOWN"]
        flex=[]
        for q in pts:
            trunk=np.array(q["chest"])-q["hips"]
            leg=(np.array(q["knee_near"])-q["thigh_near"]+np.array(q["knee_far"])-q["thigh_far"])*.5
            flex.append(float(np.degrees(np.arccos(np.clip(np.dot(trunk,leg)/(np.linalg.norm(trunk)*np.linalg.norm(leg)),-1,1)))))
        if lane==0:
            assert abs(shift)<.1 and all(v["support_count"]==2 for v in data)
            assert np.max(np.abs(anchors-anchors[0]))<1e-5
        elif lane==1:
            assert -10.5<shift<-10.3 and data[-1]["steps"]==2
            assert all(v["support_count"]>=1 for v in data)
            assert abs(data[-1]["slip"]-2.4)<1e-5
            assert np.max(np.abs(anchors[-1,:,0]-anchors[0,:,0]+10.4))<1e-5
            assert any(v["support_count"]==1 for v in data)
            for i in range(26,len(data)):
                assert min(np.linalg.norm(anchors[i]-anchors[i-1],axis=1))<1e-5
        else:
            assert shift<-24. and len(air)>15
            assert max(data[i]["clearance"] for i in air)>5.
            assert len(contact)==1 and len(fall)>=20 and len(down)>10
            assert contact[0]<fall[0]<down[0]
            assert data[contact[0]]["contact_joint"] in ("chest","head","hips"), data[contact[0]]["contact_joint"]
            assert max(abs(data[i]["clearance"]) for i in contact+fall+down)<.01
            assert all(data[i]["support_count"]==0 for i in air+contact+fall+down)
            assert min(flex[i] for i in air)<85.
            assert any(min(pts[i]["foot_near"][0],pts[i]["foot_far"][0])-pts[i]["hips"][0]>12 and min(pts[i]["hand_near"][0],pts[i]["hand_far"][0])-pts[i]["hips"][0]>5 for i in air)
            assert abs(data[-1]["slide"])>1. and abs(data[-1]["slide"])<5.
            assert abs(pts[-1]["chest"][1]-pts[-1]["hips"][1])<.1
            assert max(abs(pts[-1]["foot_"+s][1]-pts[-1]["hips"][1]) for s in ("near","far"))<6.
            assert all(pts[i]==pts[down[0]] for i in down)
        metrics[name]={"root_shift_x":shift,"steps":data[-1]["steps"],"slip":data[-1]["slip"],"air_ticks":len(air),"min_trunk_thigh_angle_deg":min((flex[i] for i in air),default=None),"max_clearance":max(v["clearance"] for v in data),"contact_tick":contact[0] if contact else None,"contact_joint":data[-1]["contact_joint"],"fall_ticks":len(fall),"slide":data[-1]["slide"],"final_raster_floor_delta_px":data[-1]["raster_bottom"]-(195+3*data[-1]["floor_y"]),"support_error_max":max(v["error"] for v in data),"pose_p95_us":float(np.percentile([v["pose_us"] for v in data],95)),"max_joint_step":max(v["joint_jump"] for v in data)}
    sheet=Image.new("RGB",(1344,272*10))
    for j,k in enumerate((0,19,24,31,42,55,67,76,91,120)):sheet.paste(frames[k],(0,j*272))
    sheet.save(out/"review.png")
    import shutil
    if shutil.which("ffmpeg"):
        subprocess.run(["ffmpeg","-y","-loglevel","error","-framerate","60","-i",str(out/"frame-%03d.png"),"-c:v","libx264","-pix_fmt","yuv420p","-movflags","+faststart",str(out/"comparison-60fps.mp4")],check=True)
    (out/"metrics.json").write_text(json.dumps(metrics,indent=2))
    print(json.dumps(metrics),flush=True)
    print("IMPACT_095_REVIEW_OK")
if __name__=="__main__":main()
