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
    cmd=["xvfb-run","-a",a.godot,"--path",str(ROOT/"godot"),"--audio-driver","Dummy","--disable-vsync","--rendering-method","gl_compatibility","--script","res://tests/action_interrupt_079.gd","--",str(out)]
    try:r=subprocess.run(cmd,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=100)
    except subprocess.TimeoutExpired as e:
        (out/"engine.log").write_bytes(e.stdout or b"");raise
    log=r.stdout.decode("utf8","replace");(out/"engine.log").write_text(log);print(log,flush=True)
    if r.returncode or "INTERRUPT_079_CAPTURE_OK" not in log or "SCRIPT ERROR" in log:raise RuntimeError(log[-4000:])
    rows=json.loads((out/"records.json").read_text());assert len(rows)==100

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
    for j,i in enumerate((15,16,25,42,50,70)):sheet.paste(frames[i],(0,j*264))
    sheet.save(out/"review.png")
    metrics={}
    for lane,name in enumerate(("A direct","B inertial","C contacts and phase")):
        data=[r["lanes"][lane] for r in rows]
        events=[(r["tick"],e["instance"],e["anchor"]) for r in rows for e in r["lanes"][lane]["events"]]
        assert events==[(25,2,"hand_far"),(42,3,"foot_far"),(70,5,"hand_near")],events
        switches=[r["lanes"][lane]["joint_jump"] for r in rows if r["switch"] and r["tick"]>0]
        windows=[v["joint_jump"] for v in data if v["instance"]>1 and v["local"]<7]
        metrics[name]={"events":events,"switch_jump":switches,"transition_p95":float(np.percentile(windows,95)),"transition_max":max(windows),"lock_frames":sum(v["lock_count"]>0 for v in data),"max_lock_error":max(v["lock_error"] for v in data),"run_entry_phases":[v["phase"] for v in data if v["action"]=="RUN" and v["local"]==0],"raster_p95_us":float(np.percentile([v["raster_us"] for v in data],95))}
    assert max(metrics["B inertial"]["switch_jump"])<.001
    c=metrics["C contacts and phase"]
    assert max(c["switch_jump"])<.001 and c["lock_frames"]>0 and c["max_lock_error"]<.20
    (out/"metrics.json").write_text(json.dumps(metrics,indent=2));print(json.dumps(metrics),flush=True)
    print("INTERRUPT_079_REVIEW_OK")
if __name__=="__main__":main()
