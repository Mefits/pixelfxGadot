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
    cmd=["xvfb-run","-a",a.godot,"--path",str(ROOT/"godot"),"--audio-driver","Dummy","--disable-vsync","--rendering-method","gl_compatibility","--script","res://tests/support_adaptation_077.gd","--",str(out)]
    try:r=subprocess.run(cmd,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=100)
    except subprocess.TimeoutExpired as e:
        (out/"engine.log").write_bytes(e.stdout or b"");raise
    log=r.stdout.decode("utf8","replace");(out/"engine.log").write_text(log);print(log,flush=True)
    if r.returncode or "SUPPORT_077_CAPTURE_OK" not in log or "SCRIPT ERROR" in log:raise RuntimeError(log[-4000:])
    rows=json.loads((out/"records.json").read_text());assert len(rows)==78
    assert [r["tick"] for r in rows if r["event"]]==[20,32,50]
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
    for j,i in enumerate((0,20,32,44,50,64)):sheet.paste(frames[i],(0,j*264))
    sheet.save(out/"review.png")
    metrics={}
    for lane,name in enumerate(("A authored","B feet IK","C feet and pelvis")):
        data=[r["lanes"][lane] for r in rows]
        near=np.array([r["near_error"] for r in data])
        far=np.array([r["far_error"] for r in data if r["airborne"]<.001])
        dx=np.array([r["pelvis_support_dx"] for r in data if r["airborne"]>.999])
        shift=np.array([r["root_shift"] for r in data])
        impacts=[]
        for tick,anchor in [(20,"hand_near"),(32,"hand_far"),(50,"foot_far")]:
            a=np.array(rows[tick]["lanes"][lane]["endpoints"][anchor])
            b=np.array(rows[tick]["lanes"][0]["endpoints"][anchor])
            impacts.append(float(np.linalg.norm(a-b)))
        metrics[name]={"near_error_p95":float(np.percentile(near,95)),"near_error_max":float(max(near)),"far_ground_error_p95":float(np.percentile(far,95)),"far_ground_error_max":float(max(far)),"single_support_pelvis_dx_mean":float(np.mean(dx)),"root_shift_max":float(np.max(np.linalg.norm(shift,axis=1))),"root_shift_step_max":float(np.max(np.linalg.norm(np.diff(shift,axis=0),axis=1))),"contact_endpoint_shift":impacts,"max_joint_frame_displacement":max(r["joint_jump"] for r in data),"raster_p95_us":float(np.percentile([r["raster_us"] for r in data],95))}
    assert metrics["B feet IK"]["near_error_p95"]<metrics["A authored"]["near_error_p95"]
    assert metrics["C feet and pelvis"]["near_error_p95"]<metrics["A authored"]["near_error_p95"]
    assert metrics["C feet and pelvis"]["root_shift_max"]<=4.001
    (out/"metrics.json").write_text(json.dumps(metrics,indent=2));print(json.dumps(metrics),flush=True)
    print("SUPPORT_077_REVIEW_OK")
if __name__=="__main__":main()
