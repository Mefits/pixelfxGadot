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
    cmd=["xvfb-run","-a",a.godot,"--path",str(ROOT/"godot"),"--audio-driver","Dummy","--disable-vsync","--rendering-method","gl_compatibility","--script","res://tests/impact_impulse_098.gd","--",str(out)]
    try:r=subprocess.run(cmd,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=300)
    except subprocess.TimeoutExpired as e:
        (out/"engine.log").write_bytes(e.stdout or b"");raise
    log=r.stdout.decode("utf8","replace");(out/"engine.log").write_text(log);print(log,flush=True)
    if r.returncode or "IMPACT_098_CAPTURE_OK" not in log or "SCRIPT ERROR" in log:raise RuntimeError(log[-4000:])
    rows=json.loads((out/"records.json").read_text());assert len(rows)==360

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
    for lane,name in enumerate(("A x1","B x3","C x5")):
        data=[r["lanes"][lane] for r in rows]
        assert all(v["accepted"]==int(i>=18) for i,v in enumerate(data))
        pts=[v["points"] for v in data]
        air=[i for i,v in enumerate(data) if v["phase"]=="AIR"]
        assert len(air)>10
        contact=next((i for i,v in enumerate(data) if v["touched"]),None)
        assert contact is not None
        assert max(v["physics_anchor_error"] for v in data)<1.
        assert max(v["physics_penetration"] for v in data)<.6
        assert max(v["physics_pose_error"] for v in data)<2.
        assert all(v["motor"]==0 for v in data[contact:])
        assert all(v["support_count"]==0 for v in data[21:])
        assert any(v["physics_contacts"]>0 for v in data[-30:])
        assert max(v["physics_peak_speed"] for v in data[-20:])<18.
        # Final pose is observed, not enforced: stronger launch may tumble.
        assert any(v["motor"]>0 for v in data)
        assert any(v["tone_impulse"]>0 for v in data[contact:])
        fold=[]
        hipflex=[]
        foot_head=[]
        for i,q in enumerate(pts):
            trunk=np.array(q["chest"])-q["hips"]
            leg=(np.array(q["knee_near"])-q["thigh_near"]+np.array(q["knee_far"])-q["thigh_far"])*.5
            fold.append(float(np.degrees(np.arccos(np.clip(np.dot(trunk,leg)/(np.linalg.norm(trunk)*np.linalg.norm(leg)),-1,1)))))
            for side,rest in (("near",10.304846468766),("far",-10.304846468766)):
                hipflex.append((i,-data[i]["angles"]["thigh_"+side]+rest))
            foot_head.append(min(np.linalg.norm(np.array(q["foot_"+side])-q["head"]) for side in ("near","far")))
        com=np.array([v["com"] for v in data])
        postslide=float(com[contact,0]-np.min(com[contact:,0]))
        net_slide=float(com[contact,0]-com[-1,0])
        metrics[name]={"impulse_scale":[1,3,5][lane],"max_com_rise":float(com[20,1]-np.min(com[21:,1])),"com_shift":float(com[-1,0]-com[20,0]),"peak_speed":max(v["physics_peak_speed"] for v in data),"final_trunk_dy":abs(pts[-1]["hips"][1]-pts[-1]["chest"][1]),"shift":pts[-1]["hips"][0]-pts[0]["hips"][0],"air_ticks":len(air),"contact_tick":contact,"min_air_trunk_thigh_angle_deg":min(fold[i] for i in air),"max_post_contact_hip_flex_deg":max(v for i,v in hipflex if i>=contact),"min_post_contact_foot_head_distance":min(foot_head[contact:]),"post_contact_com_slide":postslide,"net_post_contact_com_slide":net_slide,"max_anchor_residual":max(v["physics_anchor_error"] for v in data),"max_floor_penetration":max(v["physics_penetration"] for v in data),"max_fk_proxy_difference":max(v["physics_pose_error"] for v in data),"final_speed_peak":max(v["physics_peak_speed"] for v in data[-20:]),"max_raster_floor_overlap_px":max(v["raster_bottom"]-(485+3*v["floor_y"]) for v in data),"p95_pose_us":float(np.percentile([v["pose_us"] for v in data[21:]],95)),"max_joint_step":max(v["joint_jump"] for v in data)}
    (out/"metrics.json").write_text(json.dumps(metrics,indent=2))
    print(json.dumps(metrics),flush=True)
    assert all(rows[i]["lanes"][0]["points"]==rows[i]["lanes"][1]["points"]==rows[i]["lanes"][2]["points"] for i in range(21))
    sheet=Image.new("RGB",(1560,572*12))
    for j,k in enumerate((0,20,30,45,60,80,105,135,165,200,260,359)):sheet.paste(frames[k],(0,j*572))
    sheet.save(out/"review.png")
    a,b,c=metrics.values()
    assert a["peak_speed"]<b["peak_speed"]<c["peak_speed"],metrics
    assert a["max_com_rise"]<b["max_com_rise"]<c["max_com_rise"],metrics
    assert abs(a["com_shift"])<abs(b["com_shift"])<abs(c["com_shift"]),metrics
    import shutil
    if shutil.which("ffmpeg"):
        subprocess.run(["ffmpeg","-y","-loglevel","error","-framerate","60","-i",str(out/"frame-%03d.png"),"-c:v","libx264","-pix_fmt","yuv420p","-movflags","+faststart",str(out/"comparison-60fps.mp4")],check=True)
    (out/"metrics.json").write_text(json.dumps(metrics,indent=2))
    print(json.dumps(metrics),flush=True)
    print("IMPACT_098_REVIEW_OK")
if __name__=="__main__":main()
