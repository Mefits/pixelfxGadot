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
    cmd=["xvfb-run","-a",a.godot,"--path",str(ROOT/"godot"),"--audio-driver","Dummy","--disable-vsync","--rendering-method","gl_compatibility","--script","res://tests/run_cycle_083.gd","--",str(out)]
    try:r=subprocess.run(cmd,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=100)
    except subprocess.TimeoutExpired as e:
        (out/"engine.log").write_bytes(e.stdout or b"");raise
    log=r.stdout.decode("utf8","replace");(out/"engine.log").write_text(log);print(log,flush=True)
    if r.returncode or "RUN_083_CAPTURE_OK" not in log or "SCRIPT ERROR" in log:raise RuntimeError(log[-4000:])
    rows=json.loads((out/"records.json").read_text());assert len(rows)==72

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
    sheet=Image.new("RGB",(864,264*6))
    for j,i in enumerate((0,6,12,18,24,30)):sheet.paste(frames[i],(0,j*264))
    sheet.save(out/"review.png")
    metrics={}
    for lane,name in enumerate(("A held source","B cyclic interpolation","C procedural stride")):
        data=[r["lanes"][lane] for r in rows[:36]]
        ids=list(data[0]["points"])
        xyz=np.array([[v["points"][id] for id in ids] for v in data])
        moves=np.roll(xyz,-1,axis=0)-xyz
        speed=np.linalg.norm(moves,axis=-1).max(axis=1)
        accel=np.linalg.norm(moves-np.roll(moves,1,axis=0),axis=-1).max(axis=1)
        drift=[]
        for side in ("near","far"):
            toe=np.array([v["toes"][side] for v in data])
            stance=np.array([v["stance"][side] for v in data])
            world_delta=np.roll(toe,-1,axis=0)-toe+np.array([1.05,0.])
            mask=stance & np.roll(stance,-1)
            drift.extend(np.linalg.norm(world_delta[mask],axis=1).tolist())
        knees=np.array([[v["knee"][s] for s in ("near","far")] for v in data])
        metrics[name]={"held_frame_pairs":int(np.sum(speed<1e-4)),"joint_step_max":float(speed.max()),"joint_accel_p95":float(np.percentile(accel,95)),"loop_seam_step":float(speed[-1]),"reference_stance_drift_p95":float(np.percentile(drift,95)),"toe_target_error_max":max(v["error"] for v in data),"knee_min":float(knees.min()),"knee_max":float(knees.max()),"pose_p95_us":float(np.percentile([r["lanes"][lane]["pose_us"] for r in rows],95)),"raster_p95_us":float(np.percentile([r["lanes"][lane]["raster_us"] for r in rows],95))}
        assert all(np.allclose(rows[k]["lanes"][lane]["points"][id],rows[k+36]["lanes"][lane]["points"][id],atol=1e-5) for k in range(36) for id in ids)
        if lane>0:assert metrics[name]["held_frame_pairs"]==0 and knees.min()>=-.001
    assert metrics["A held source"]["held_frame_pairs"]>=20
    assert metrics["C procedural stride"]["reference_stance_drift_p95"]<.01
    assert metrics["C procedural stride"]["toe_target_error_max"]<.01
    # Optional native 60fps MP4 for players that throttle short GIF delays.
    import shutil
    if shutil.which("ffmpeg"):
        subprocess.run(["ffmpeg","-y","-loglevel","error","-framerate","60","-i",str(out/"frame-%03d.png"),"-c:v","libx264","-pix_fmt","yuv420p","-movflags","+faststart",str(out/"comparison-60fps.mp4")],check=True)
    (out/"metrics.json").write_text(json.dumps(metrics,indent=2));print(json.dumps(metrics),flush=True)
    print("RUN_083_REVIEW_OK")
if __name__=="__main__":main()
