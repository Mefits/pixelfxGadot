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
    cmd=["xvfb-run","-a",a.godot,"--path",str(ROOT/"godot"),"--audio-driver","Dummy","--disable-vsync","--rendering-method","gl_compatibility","--script","res://tests/distance_gait_087.gd","--",str(out)]
    try:r=subprocess.run(cmd,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=160)
    except subprocess.TimeoutExpired as e:
        (out/"engine.log").write_bytes(e.stdout or b"");raise
    log=r.stdout.decode("utf8","replace");(out/"engine.log").write_text(log);print(log,flush=True)
    if r.returncode or "DISTANCE_087_CAPTURE_OK" not in log or "SCRIPT ERROR" in log:raise RuntimeError(log[-4000:])
    rows=json.loads((out/"records.json").read_text());assert len(rows)==366

    # All frames are captured by Godot. For convenient review crop
    # the native lanes, not their contents or timing.
    frames=[Image.open(out/f"frame-{i:03d}.png").convert("RGB") for i in range(len(rows))]
    def gif(images,name,step):
        images=images[::step]
        ends=[round((i+1)/30*100)*10 for i in range(len(images))]
        images[0].save(out/name,save_all=True,append_images=images[1:],duration=np.diff([0,*ends]).tolist(),loop=0,disposal=1)
        with Image.open(out/name) as im:
            delays=[]
            for i in range(im.n_frames):im.seek(i);delays.append(im.info["duration"])
            assert sum(delays)==ends[-1]
    # A/B comparison: 126 native ticks covers three new full strides.
    compare=[f.crop((0,0,576,244)) for f in frames[:126]]
    # C variable speed with the original shared speed/tick caption below.
    dynamic=[]
    for f in frames:
        im=Image.new("RGB",(288,264))
        im.paste(f.crop((576,0,864,244)),(0,0))
        im.paste(f.crop((0,244,288,264)),(0,244))
        dynamic.append(im)
    for step,suffix in ((2,"1x"),(1,"half")):
        gif(compare,f"comparison-{suffix}.gif",step)
        gif(dynamic,f"variable-{suffix}.gif",step)
    sheet=Image.new("RGB",(864,264*6))
    for j,k in enumerate((12,48,80,150,250,330)):sheet.paste(frames[k],(0,j*264))
    sheet.save(out/"review.png")
    metrics={}
    for lane,name in enumerate(("A 086 short run","B long run","C variable")):
        data=[r["lanes"][lane] for r in rows]
        xyz=np.array([[v["points"][id] for id in data[0]["points"]] for v in data])
        speed=np.linalg.norm(np.diff(xyz,axis=0),axis=-1).max(axis=1)
        accel=np.linalg.norm(np.diff(xyz,n=2,axis=0),axis=-1).max(axis=1)
        travel=np.array([v["travel"] for v in data])
        contact=np.array([[v["stance"][s] for s in ("near","far")] for v in data])
        toes=np.array([[v["toes"][s] for s in ("near","far")] for v in data])
        world=toes+travel[:,None,None]*np.array([1.,0.])[None,None,:]
        drift=[]
        for k in range(1,len(data)):
            for col,side in enumerate(("near","far")):
                if contact[k,col] and contact[k-1,col] and (lane==0 or data[k]["foot_start"][side]==data[k-1]["foot_start"][side]):
                    drift.append(float(np.linalg.norm(world[k,col]-world[k-1,col])))
        spread=np.abs(toes[:,0,0]-toes[:,1,0])
        both=contact.all(axis=1)
        flight=~contact.any(axis=1)
        metrics[name]={"step_distance_min":min(v["step_distance"] for v in data),"step_distance_max":max(v["step_distance"] for v in data),"toe_spread_max":float(spread.max()),"flight_frames":int(flight.sum()),"double_support_frames":int(both.sum()),"world_stance_drift_max":max(drift),"root_drop_max":max(v["root_drop"] for v in data),"joint_step_max":float(speed.max()),"joint_accel_p95":float(np.percentile(accel,95)),"pose_p95_us":float(np.percentile([v["pose_us"] for v in data],95)),"toe_error_max":max(v["error"] for v in data)}
        if lane>0:
            assert max(drift)<.01 and metrics[name]["toe_error_max"]<.01
            assert metrics[name]["root_drop_max"]<=2.001
            assert np.allclose(np.diff(travel),[v["travel_speed"] for v in data[1:]],atol=1e-5)
        if lane==2:
            # Settled walk windows, not the just-braked period with one
            # previously committed long step still in progress.
            assert not flight[:48].any() and not flight[-40:].any()
            assert both[:48].any() and both[-40:].any()
            assert flight[140:222].any()
            assert not both[140:222].any()
            metrics[name]["initial_walk_flight_frames"]=int(flight[:48].sum())
            metrics[name]["final_walk_flight_frames"]=int(flight[-40:].sum())
            metrics[name]["steady_run_flight_frames"]=int(flight[140:222].sum())
    assert metrics["B long run"]["step_distance_max"]>metrics["A 086 short run"]["step_distance_max"]*1.35
    assert metrics["B long run"]["toe_spread_max"]>metrics["A 086 short run"]["toe_spread_max"]*1.05
    assert metrics["C variable"]["step_distance_min"]<=16.001 and metrics["C variable"]["step_distance_max"]>=38.849
    import shutil
    if shutil.which("ffmpeg"):
        subprocess.run(["ffmpeg","-y","-loglevel","error","-framerate","60","-i",str(out/"frame-%03d.png"),"-c:v","libx264","-pix_fmt","yuv420p","-movflags","+faststart",str(out/"comparison-60fps.mp4")],check=True)
    (out/"metrics.json").write_text(json.dumps(metrics,indent=2));print(json.dumps(metrics),flush=True)
    print("DISTANCE_087_REVIEW_OK")
if __name__=="__main__":main()
