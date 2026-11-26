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
    cmd=["xvfb-run","-a",a.godot,"--path",str(ROOT/"godot"),"--audio-driver","Dummy","--disable-vsync","--rendering-method","gl_compatibility","--script","res://tests/stance_recovery_078.gd","--",str(out)]
    try:r=subprocess.run(cmd,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=100)
    except subprocess.TimeoutExpired as e:
        (out/"engine.log").write_bytes(e.stdout or b"");raise
    log=r.stdout.decode("utf8","replace");(out/"engine.log").write_text(log);print(log,flush=True)
    if r.returncode or "RECOVERY_078_CAPTURE_OK" not in log or "SCRIPT ERROR" in log:raise RuntimeError(log[-4000:])
    rows=json.loads((out/"records.json").read_text());assert len(rows)==128
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
    for j,i in enumerate((76,84,92,100,110,127)):sheet.paste(frames[i],(0,j*264))
    sheet.save(out/"review.png")
    metrics={}
    for lane,name in enumerate(("A hold","B blend","C procedural step")):
        data=[r["lanes"][lane] for r in rows[77:]]
        end=data[-1]
        hold=[r["lanes"][lane] for r in rows[110:]]
        metrics[name]={"final_foot_gap":end["gap"],"final_pelvis_inside_base":end["inside"],"max_support_drift":max(r["support_error"] for r in data),"max_swing_target_error":max(r["moving_error"] for r in data),"max_ankle_lift":-min(r["moving_y"] for r in data),"max_recovery_joint_step":max(r["joint_jump"] for r in data),"hold_max_joint_step":max(r["joint_jump"] for r in hold[1:]),"support_dx_entry":rows[76]["lanes"][lane]["support_dx"],"support_dx_load_end":rows[84]["lanes"][lane]["support_dx"],"raster_p95_us":float(np.percentile([r["raster_us"] for r in data],95))}
    c=metrics["C procedural step"]
    assert c["final_foot_gap"]>metrics["A hold"]["final_foot_gap"]*1.5
    assert c["final_pelvis_inside_base"] and c["max_support_drift"]<.03
    assert c["max_swing_target_error"]<.03 and c["max_ankle_lift"]>2.5
    assert c["hold_max_joint_step"]<.001
    assert c["support_dx_load_end"]<c["support_dx_entry"]
    (out/"metrics.json").write_text(json.dumps(metrics,indent=2));print(json.dumps(metrics),flush=True)
    print("RECOVERY_078_REVIEW_OK")
if __name__=="__main__":main()
