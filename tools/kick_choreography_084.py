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
    cmd=["xvfb-run","-a",a.godot,"--path",str(ROOT/"godot"),"--audio-driver","Dummy","--disable-vsync","--rendering-method","gl_compatibility","--script","res://tests/kick_choreography_084.gd","--",str(out)]
    try:r=subprocess.run(cmd,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=100)
    except subprocess.TimeoutExpired as e:
        (out/"engine.log").write_bytes(e.stdout or b"");raise
    log=r.stdout.decode("utf8","replace");(out/"engine.log").write_text(log);print(log,flush=True)
    if r.returncode or "KICK_084_CAPTURE_OK" not in log or "SCRIPT ERROR" in log:raise RuntimeError(log[-4000:])
    rows=json.loads((out/"records.json").read_text());assert len(rows)==84

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
    for j,i in enumerate((38,42,45,50,55,64)):sheet.paste(frames[i],(0,j*264))
    sheet.save(out/"review.png")
    metrics={}
    assert [r["tick"] for r in rows if r["event"]]==[20,32,50]
    for lane,name in enumerate(("A original","B smooth key poses","C new kick path")):
        data=[r["lanes"][lane] for r in rows[38:77]]
        ids=list(data[0]["points"])
        xyz=np.array([[v["points"][id] for id in ids] for v in data])
        moves=np.diff(xyz,axis=0)
        speed=np.linalg.norm(moves,axis=-1).max(axis=1)
        accel=np.linalg.norm(np.diff(moves,axis=0),axis=-1).max(axis=1)
        toe=np.array([v["toes"]["near"] for v in data])
        far=np.array([v["toes"]["far"] for v in data])
        drift=np.linalg.norm(toe-toe[0],axis=1)
        knees=np.array([[v["knee"][s] for s in ("near","far")] for v in data])
        metrics[name]={"kick_joint_step_max":float(speed.max()),"kick_joint_accel_p95":float(np.percentile(accel,95)),"entry_joint_step_max":float(speed[:6].max()),"support_toe_drift_max":float(drift.max()),"far_toe_speed_last4_max":float(np.linalg.norm(np.diff(far[8:13],axis=0),axis=1).max()*60),"toe_target_error_max":max(v["error"] for v in data),"knee_min":float(knees.min()),"knee_max":float(knees.max()),"pose_p95_us":float(np.percentile([v["pose_us"] for v in data],95))}
        for tick in (0,20,32,38,50,76):
            assert all(np.allclose(rows[tick]["lanes"][lane]["points"][id],rows[tick]["lanes"][0]["points"][id],atol=1e-5) for id in ids)
    assert metrics["C new kick path"]["support_toe_drift_max"]<.01
    assert metrics["C new kick path"]["toe_target_error_max"]<.01
    # Optional native 60fps MP4 for players that throttle short GIF delays.
    import shutil
    if shutil.which("ffmpeg"):
        subprocess.run(["ffmpeg","-y","-loglevel","error","-framerate","60","-i",str(out/"frame-%03d.png"),"-c:v","libx264","-pix_fmt","yuv420p","-movflags","+faststart",str(out/"comparison-60fps.mp4")],check=True)
    (out/"metrics.json").write_text(json.dumps(metrics,indent=2));print(json.dumps(metrics),flush=True)
    print("KICK_084_REVIEW_OK")
if __name__=="__main__":main()
