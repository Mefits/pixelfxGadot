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
    cmd=["xvfb-run","-a",a.godot,"--path",str(ROOT/"godot"),"--audio-driver","Dummy","--disable-vsync","--rendering-method","gl_compatibility","--script","res://tests/attack_timing_076.gd","--",str(out)]
    try:r=subprocess.run(cmd,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=100)
    except subprocess.TimeoutExpired as e:
        (out/"engine.log").write_bytes(e.stdout or b"");raise
    log=r.stdout.decode("utf8","replace");(out/"engine.log").write_text(log);print(log,flush=True)
    if r.returncode or "TIMING_076_CAPTURE_OK" not in log or "SCRIPT ERROR" in log:raise RuntimeError(log[-4000:])
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
    for j,i in enumerate((13,18,20,30,32,50)):sheet.paste(frames[i],(0,j*264))
    sheet.save(out/"review.png")
    metrics={}
    for lane,name in enumerate(("A original","B moderate","C stronger")):
        impacts=[]
        for tick,anchor in [(20,"hand_near"),(32,"hand_far"),(50,"foot_far")]:
            points=np.array([r["lanes"][lane]["endpoints"][anchor] for r in rows])
            speeds=np.linalg.norm(np.diff(points,axis=0),axis=1)*60
            impacts.append({"tick":tick,"anchor":anchor,"peak_last_4_ticks":float(max(speeds[tick-4:tick])),"travel_last_4_ticks":float(sum(speeds[tick-4:tick])/60),"contact_xy":points[tick].tolist()})
            assert np.array_equal(points[tick],rows[tick]["lanes"][0]["endpoints"][anchor])
        feet=[]
        for anchor in ["foot_near","foot_far"]:
            points=np.array([r["lanes"][lane]["endpoints"][anchor] for r in rows])
            feet.append(float(np.max(np.linalg.norm(np.diff(points,axis=0),axis=1))))
        metrics[name]={"impacts":impacts,"max_foot_frame_displacement":feet,"max_joint_frame_displacement":max(r["lanes"][lane]["joint_jump"] for r in rows),"raster_p95_us":float(np.percentile([r["lanes"][lane]["raster_us"] for r in rows],95))}
    (out/"metrics.json").write_text(json.dumps(metrics,indent=2));print(json.dumps(metrics),flush=True)
    print("TIMING_076_REVIEW_OK")
if __name__=="__main__":main()
