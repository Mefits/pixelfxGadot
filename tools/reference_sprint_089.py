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
    cmd=["xvfb-run","-a",a.godot,"--path",str(ROOT/"godot"),"--audio-driver","Dummy","--disable-vsync","--rendering-method","gl_compatibility","--script","res://tests/reference_sprint_089.gd","--",str(out)]
    try:r=subprocess.run(cmd,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=160)
    except subprocess.TimeoutExpired as e:
        (out/"engine.log").write_bytes(e.stdout or b"");raise
    log=r.stdout.decode("utf8","replace");(out/"engine.log").write_text(log);print(log,flush=True)
    if r.returncode or "REFERENCE_089_CAPTURE_OK" not in log or "SCRIPT ERROR" in log:raise RuntimeError(log[-4000:])
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
    def crossing(a,b,c,d):
        u=b-a;v=d-c
        cross=lambda x,y: x[0]*y[1]-x[1]*y[0]
        den=cross(u,v)
        if abs(den)<1e-8:return False
        return 0<cross(c-a,v)/den<1 and 0<cross(c-a,u)/den<1
    metrics={}
    peak_ticks=[]
    for lane,name in enumerate(("A 088 control","B reference flight")):
        data=[r["lanes"][lane] for r in rows]
        hits=[];ext_hits=[];drift=[];flight=[]
        toes=np.array([[v["toes"][s] for s in ("near","far")] for v in data])
        travel=np.array([v["travel"] for v in data])
        world=toes+travel[:,None,None]*np.array([1.,0.])
        contact=np.array([[v["stance"][s] for s in ("near","far")] for v in data])
        for tick,v in enumerate(data):
            q={k:np.array(p) for k,p in v["points"].items()}
            if lane:
                old=rows[tick]["lanes"][0]
                assert v["travel"]==old["travel"] and v["foot_start"]==old["foot_start"]
                assert v["stance"]==old["stance"] and v["step_distance"]==old["step_distance"]
                for s in ("near","far"):
                    if v["stance"][s] or v["gait"]<=.65:
                        assert np.allclose(v["toes"][s],old["toes"][s],atol=1e-5,rtol=0),(tick,s)
                if v["gait"]<=.65:
                    assert all(np.allclose(q[id],old["points"][id],atol=1e-5,rtol=0) for id in q)
            if v["gait"]>.999 and not contact[tick].any():flight.append(tick)
            for col,s in enumerate(("near","far")):
                if tick and contact[tick,col] and contact[tick-1,col] and v["foot_start"][s]==data[tick-1]["foot_start"][s]:
                    drift.append(float(np.linalg.norm(world[tick,col]-world[tick-1,col])))
                sh,el,ha=[q[k+"_"+s] for k in ("shoulder","elbow","hand")]
                tip=ha+2.55*(ha-el)/np.linalg.norm(ha-el)
                for t in ("near","far"):
                    for a,b in ((q["thigh_"+t],q["knee_"+t]),(q["knee_"+t],q["foot_"+t])):
                        if crossing(sh,el,a,b) or crossing(el,ha,a,b):hits.append(tick)
                        if crossing(sh,el,a,b) or crossing(el,tip,a,b):ext_hits.append(tick)
        spread=np.abs(toes[:,0,0]-toes[:,1,0])
        peak=max(flight,key=lambda t:spread[t])
        peak_ticks.append(peak)
        q={k:np.array(p) for k,p in data[peak]["points"].items()}
        front="near" if toes[peak,0,0]>toes[peak,1,0] else "far"
        back="far" if front=="near" else "near"
        angle=lambda x:float(np.degrees(np.arctan2(-x[0],x[1])))
        metrics[name]={"flight_spread_max":float(spread[peak]),"flight_peak_tick":peak,"flight_frames":len(flight),"front_thigh_angle":angle(q["knee_"+front]-q["thigh_"+front]),"rear_thigh_angle":angle(q["knee_"+back]-q["thigh_"+back]),"rear_shin_angle":angle(q["foot_"+back]-q["knee_"+back]),"projected_crossing_frames":len(set(hits)),"extended_hand_crossing_frames":len(set(ext_hits)),"stance_drift_max":max(drift),"root_drop_max":max(v["root_drop"] for v in data),"pose_p95_us":float(np.percentile([v["pose_us"] for v in data],95)),"toe_error_max":max(v["error"] for v in data),"max_joint_step":max(v["joint_jump"] for v in data)}
    a,b=metrics["A 088 control"],metrics["B reference flight"]
    assert b["flight_spread_max"]>1.12*a["flight_spread_max"]
    assert b["flight_frames"]==a["flight_frames"]
    assert b["projected_crossing_frames"]==0 and b["extended_hand_crossing_frames"]==0
    assert b["stance_drift_max"]<.01 and b["toe_error_max"]<.01
    assert b["root_drop_max"]<=2.001
    # Native capture, same instant in both lanes, including peak silhouette.
    sheet=Image.new("RGB",(576,264*6))
    peak=peak_ticks[1]
    for j,k in enumerate((65,peak-4,peak-2,peak,peak+2,250)):sheet.paste(frames[k],(0,j*264))
    sheet.save(out/"review.png")
    import shutil
    if shutil.which("ffmpeg"):
        subprocess.run(["ffmpeg","-y","-loglevel","error","-framerate","60","-i",str(out/"frame-%03d.png"),"-c:v","libx264","-pix_fmt","yuv420p","-movflags","+faststart",str(out/"comparison-60fps.mp4")],check=True)
    (out/"metrics.json").write_text(json.dumps(metrics,indent=2));print(json.dumps(metrics),flush=True)
    print("REFERENCE_089_REVIEW_OK")
if __name__=="__main__":main()
