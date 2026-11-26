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
    cmd=["xvfb-run","-a",a.godot,"--path",str(ROOT/"godot"),"--audio-driver","Dummy","--disable-vsync","--rendering-method","gl_compatibility","--script","res://tests/impact_reactions_092.gd","--",str(out)]
    try:r=subprocess.run(cmd,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=160)
    except subprocess.TimeoutExpired as e:
        (out/"engine.log").write_bytes(e.stdout or b"");raise
    log=r.stdout.decode("utf8","replace");(out/"engine.log").write_text(log);print(log,flush=True)
    if r.returncode or "IMPACT_092_CAPTURE_OK" not in log or "SCRIPT ERROR" in log:raise RuntimeError(log[-4000:])
    rows=json.loads((out/"records.json").read_text());assert len(rows)==270

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
    for lane,name in enumerate(("A 091 hybrid","B stronger hybrid","C recovery step")):
        data=[r["lanes"][lane] for r in rows]
        assert all(v["accepted"]==sum(t<=i for t in (24,88,144,154,164)) for i,v in enumerate(data))
        assert max(v["error"] for v in data)<.01
        offset=np.array([v["offset"] for v in data])
        q0=np.array(list(data[0]["points"].values()))
        qend=np.array(list(data[-1]["points"].values()))
        assert np.max(np.abs(offset[-1]))<.05
        anchors=np.array([[v["anchors"][s] for s in ("near","far")] for v in data])
        assert np.max(np.abs(anchors[:164]-anchors[0]))<1e-5
        if lane<2:
            assert np.max(np.abs(qend-q0))<.1
            assert np.max(np.abs(anchors-anchors[0]))<1e-5
        else:
            mover=0 if data[173]["moving"]=="near" else 1
            assert np.max(np.abs(anchors[:,1-mover]-anchors[0,1-mover]))<1e-5
            assert abs(anchors[-1,mover,0]-anchors[0,mover,0]+4.5)<1e-5
            assert np.min(anchors[:,mover,1]-anchors[0,mover,1])<-2.8
            assert abs(anchors[-1,mover,1]-anchors[0,mover,1])<1e-5
            assert not any(v["swing"] for v in data[:164])
            assert not any(v["swing"] for v in data[189:])
            assert np.max(np.abs(anchors[189:]-anchors[189]))<1e-5
        assert np.max(np.abs(offset[24:44,2]))>3.
        assert np.max(offset[88:110,1])>3.
        metrics[name]={"root_shift_x":float(data[-1]["points"]["hips"][0]-data[0]["points"]["hips"][0]),"max_step_lift":float(np.max(anchors[0,:,1]-anchors[:,:,1])),"swing_frames":sum(v["swing"] for v in data),"max_head_reaction_deg":float(np.max(np.abs(offset[24:44,2]))),"max_body_fold_deg":float(np.max(offset[88:110,1])),"combo_peak_head_deg":float(np.max(np.abs(offset[144:190,2]))),"support_error_max":max(v["error"] for v in data),"pose_p95_us":float(np.percentile([v["pose_us"] for v in data],95)),"max_joint_step":max(v["joint_jump"] for v in data),"settled_offset_max":float(np.max(np.abs(offset[-1])))}
    assert metrics["B stronger hybrid"]["max_body_fold_deg"]>metrics["A 091 hybrid"]["max_body_fold_deg"]
    sheet=Image.new("RGB",(864,272*8))
    for j,k in enumerate((0,28,92,164,168,173,180,205)):sheet.paste(frames[k],(0,j*272))
    sheet.save(out/"review.png")
    import shutil
    if shutil.which("ffmpeg"):
        subprocess.run(["ffmpeg","-y","-loglevel","error","-framerate","60","-i",str(out/"frame-%03d.png"),"-c:v","libx264","-pix_fmt","yuv420p","-movflags","+faststart",str(out/"comparison-60fps.mp4")],check=True)
    (out/"metrics.json").write_text(json.dumps(metrics,indent=2))
    print(json.dumps(metrics),flush=True)
    print("IMPACT_092_REVIEW_OK")
if __name__=="__main__":main()
