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
    cmd=["xvfb-run","-a",a.godot,"--path",str(ROOT/"godot"),"--audio-driver","Dummy","--disable-vsync","--rendering-method","gl_compatibility","--script","res://tests/leg_motor_082.gd","--",str(out)]
    try:r=subprocess.run(cmd,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=100)
    except subprocess.TimeoutExpired as e:
        (out/"engine.log").write_bytes(e.stdout or b"");raise
    log=r.stdout.decode("utf8","replace");(out/"engine.log").write_text(log);print(log,flush=True)
    if r.returncode or "LEGS_082_CAPTURE_OK" not in log or "SCRIPT ERROR" in log:raise RuntimeError(log[-4000:])
    rows=json.loads((out/"records.json").read_text());assert len(rows)==128

    frames=[Image.open(out/f"frame-{i:03d}.png").convert("RGB") for i in range(len(rows))]
    # Native 60Hz capture is retained in half-speed GIF; normal GIF uses
    # two-tick exposures, not reduced animation or simulation frequency.
    for step,name in [(2,"comparison-1x.gif"),(1,"comparison-half.gif")]:
        images=frames[::step]
        ends=[round((i+1)/30*100)*10 for i in range(len(images))]
        images[0].save(out/name,save_all=True,append_images=images[1:],duration=np.diff([0,*ends]).tolist(),loop=0,disposal=1)
        with Image.open(out/name) as im:
            delays=[]
            for i in range(im.n_frames):im.seek(i);delays.append(im.info["duration"])
            assert sum(delays)==ends[-1]
    sheet=Image.new("RGB",(1536,264*6))
    for j,i in enumerate((42,45,49,53,80,100)):sheet.paste(frames[i],(0,j*264))
    sheet.save(out/"review.png")
    metrics={}
    for lane,name in enumerate(("A 081 control","B leg constraints","C safe foot IK")):
        data=[r["lanes"][lane] for r in rows]
        events=[(r["tick"],e["instance"],e["anchor"]) for r in rows for e in r["lanes"][lane]["events"]]
        assert events==[(25,2,"hand_far"),(42,3,"foot_far"),(70,5,"hand_near")],events
        knees=np.array([[v["knee"][s] for s in ("near","far")] for v in data])
        ankles=np.array([[v["ankle"][s] for s in ("near","far")] for v in data])
        switches=[r["lanes"][lane] for r in rows if r["switch"] and r["tick"]>0]
        windows=[v["joint_jump"] for v in data if v["instance"]>1 and v["local"]<13]
        travel=np.array([v["travel"] for v in data])
        metrics[name]={"events":events,"negative_knee_samples":int(np.sum(knees<-.001)),"knee_min":float(knees.min()),"knee_max":float(knees.max()),"ankle_min":float(ankles.min()),"ankle_max":float(ankles.max()),"ankle_outside_samples":int(np.sum((ankles< -95.001)|(ankles>85.001))),"ankle_step_max":float(np.max(np.abs((np.diff(ankles,axis=0)+180)%360-180))),"window_p95":float(np.percentile(windows,95)),"window_max":max(windows),"durations":[v["duration"] for v in switches],"plan_us":[v["plan_us"] for v in switches],"candidate_counts":[v["candidate_count"] for v in switches],"run_lock_frames":sum(v["run_lock"] for v in data),"world_travel":float(travel[-1]),"step_p95_us":float(np.percentile([v["step_us"] for v in data],95))}
        assert max(v["candidate_count"] for v in switches)<=3
        if lane>0:
            assert metrics[name]["negative_knee_samples"]==0 and metrics[name]["ankle_outside_samples"]==0
            assert knees.max()<=155.001
    assert metrics["A 081 control"]["negative_knee_samples"]>0
    assert metrics["C safe foot IK"]["run_lock_frames"]>0
    (out/"metrics.json").write_text(json.dumps(metrics,indent=2));print(json.dumps(metrics),flush=True)
    print("LEGS_082_REVIEW_OK")
if __name__=="__main__":main()
