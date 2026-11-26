"""Independent native simulation traces, same actual PixelFX raster in Godot."""
import argparse,json,subprocess,shutil,hashlib
from pathlib import Path
import numpy as np
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
def run(cmd,log,marker,timeout=240):
    r=subprocess.run(cmd,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=timeout)
    s=r.stdout.decode("utf8","replace")
    log.write_text(s)
    print(s,flush=True)
    if r.returncode or marker not in s or "SCRIPT ERROR" in s or "ERROR:" in s:raise RuntimeError(s[-6000:])
def load(path):
    rows=json.loads(path.read_text())
    arr=np.array([r["state"] for r in rows],dtype=np.float64)
    assert len(rows)==600 and arr.ndim==3 and arr.shape[2]==6 and np.isfinite(arr).all()
    return rows,arr
def main():
    p=argparse.ArgumentParser();p.add_argument("--godot",required=True);p.add_argument("--box2d",required=True);p.add_argument("--out",type=Path,required=True)
    a=p.parse_args();out=a.out.resolve();out.mkdir(parents=True,exist_ok=True)
    godot=[a.godot,"--path",str(ROOT/"godot"),"--audio-driver","Dummy"]
    repeat=out/"repeat";repeat.mkdir(exist_ok=True)
    # independent processes, no raster in timed simulations
    for dest in (out,repeat):
        for mode in ("custom","godot"):
            run(godot+["--headless","--fixed-fps","120","--script","res://tests/physics_backends_sim_099.gd","--",str(dest),mode],dest/(mode+".log"),"PHYSICS_099_SIM_OK")
        run([a.box2d,str(dest/"model.txt"),str(dest/"box2d.json")],dest/"box2d.log","BOX2D_099_SIM_OK")
    stats={}
    for name in ("custom","godot","box2d"):
        rows,x=load(out/(name+".json"));_,y=load(repeat/(name+".json"))
        delta=np.abs(x-y)
        stats[name]={"fresh_process_exact":bool(np.array_equal(x,y)),"fresh_process_max_position_delta":float(delta[:,:,:2].max()),"fresh_process_max_raw_state_delta":float(delta.max()),"p95_substep_us":float(np.percentile([v["us"] for v in rows],95)),"timing_scope":"whole Godot physics-process monitor, not isolated solver" if name=="godot" else "controller + solver, excluding trace serialization"}
        if name=="godot":stats[name]["p95_controller_us"]=float(np.percentile([v["control_us"] for v in rows],95))
        if name=="custom":assert stats[name]["fresh_process_exact"],stats[name]
    (out/"benchmark.json").write_text(json.dumps(stats,indent=2))
    run(["xvfb-run","-a"]+godot+["--disable-vsync","--rendering-method","gl_compatibility","--script","res://tests/physics_backends_render_099.gd","--",str(out)],out/"render.log","PHYSICS_099_RENDER_OK")
    rows=json.loads((out/"records.json").read_text())
    assert len(rows)==318
    frames=[Image.open(out/f"frame-{i:03d}.png").convert("RGB") for i in range(len(rows))]
    for step,suffix in ((2,"1x"),(1,"half")):
        images=frames[::step]
        ends=[round((i+1)/30*100)*10 for i in range(len(images))]
        path=out/f"comparison-{suffix}.gif"
        images[0].save(path,save_all=True,append_images=images[1:],duration=np.diff([0,*ends]).tolist(),loop=0,disposal=1)
        with Image.open(path) as im:
            durations=[]
            for i in range(im.n_frames):im.seek(i);durations.append(im.info["duration"])
            assert sum(durations)==ends[-1]
    for lane,name in enumerate(("custom","godot","box2d")):
        d=[r["lanes"][lane] for r in rows]
        com=np.array([v["com"] for v in d])
        s=stats[name]
        s.update({"com_shift_x":float(com[-1,0]-com[17,0]),"max_com_rise":float(com[17,1]-com[:,1].min()),"max_anchor_residual":max(v["anchor"] for v in d),"max_floor_penetration":max(v["penetration"] for v in d),"max_relative_angle_violation_deg":max(v["angle_error_deg"] for v in d),"max_fk_difference":max(v["fk_error"] for v in d),"max_raster_floor_overlap_px":max(v["raster_floor_overlap"] for v in d),"final_speed_peak":max(v["speed"] for v in d[-30:]),"final_trunk_dy":abs(d[-1]["hip"][1]-d[-1]["chest"][1]),"near_floor_final":d[-1]["near_floor"],"airborne_sample_count":sum(v["near_floor"]==0 for v in d[18:])})
        # Report backend quality rather than hiding a poor native result.
        s["quality_gate"]=bool(s["com_shift_x"]<-10 and s["max_anchor_residual"]<1 and s["max_floor_penetration"]<.6 and s["max_fk_difference"]<2 and s["max_relative_angle_violation_deg"]<8 and s["final_speed_peak"]<18)
    w,h=frames[0].size
    sheet=Image.new("RGB",(w,h*10))
    for j,k in enumerate((0,18,24,32,44,60,85,120,200,317)):sheet.paste(frames[k],(0,j*h))
    sheet.save(out/"review.png")
    (out/"metrics.json").write_text(json.dumps(stats,indent=2))
    print(json.dumps(stats),flush=True)
    print("PHYSICS_099_COMPARISON_OK (quality gates reported per backend, not all presumed passed)")
if __name__=="__main__":main()
