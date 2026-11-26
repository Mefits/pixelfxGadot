"""Actual Godot 0.74 material A/B/C capture; no synthetic renderer."""
import argparse,json,subprocess
from pathlib import Path
import numpy as np
from PIL import Image,ImageDraw
ROOT=Path(__file__).resolve().parents[1]
def main():
    p=argparse.ArgumentParser()
    p.add_argument("--godot",required=True)
    p.add_argument("--out",type=Path,required=True)
    a=p.parse_args(); out=a.out.resolve();out.mkdir(parents=True,exist_ok=True)
    metrics={}
    for v,label in enumerate(("A control","B spatial wind","C softer material")):
        lane=out/str(v);lane.mkdir(exist_ok=True)
        cmd=["xvfb-run","-a",a.godot,"--path",str(ROOT/"godot"),"--audio-driver","Dummy","--disable-vsync","--rendering-method","gl_compatibility","--script","res://tests/cloth_material_074.gd","--",str(lane),str(v)]
        try:
            r=subprocess.run(cmd,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=100)
        except subprocess.TimeoutExpired as e:
            (lane/"engine.log").write_bytes(e.stdout or b"");raise
        log=r.stdout.decode("utf8","replace");(lane/"engine.log").write_text(log);print(log,flush=True)
        if r.returncode or "CLOTH_074_CAPTURE_OK" not in log or "SCRIPT ERROR" in log:raise RuntimeError(log[-4000:])
        d=json.loads((lane/"records.json").read_text());rows=d["rows"]
        assert len(rows)==240
        tip=lambda lo,hi:np.array([r["tip"] for r in rows[lo:hi]]).mean(axis=0)
        curve=np.array([r["curve_turn"] for r in rows[60:180]])
        m={"max_strain":d["max_strain"],"replay_error":d["replay_error"],"tip_no_wind":tip(40,60).tolist(),"tip_steady":tip(100,120).tolist(),"tip_after":tip(220,240).tolist(),"curve_p50":float(np.median(curve)),"curve_p95":float(np.percentile(curve,95)),"raster_p95_us":float(np.percentile([r["raster_us"] for r in rows[10:]],95)),"physics_p95_us":float(np.percentile([r["physics_us"] for r in rows[10:]],95)),"cloth_pixels_min":min(r["cloth_pixels"] for r in rows)}
        metrics[label]=m
    # Crop identical native camera region only; no pixel or motion changes.
    frames=[]
    for i in range(240):
        im=Image.new("RGB",(720,221),(38,53,64)); draw=ImageDraw.Draw(im)
        for v,label in enumerate(("A / 0.72 CONTROL","B / SPATIAL WIND","C / SOFTER MATERIAL")):
            with Image.open(out/str(v)/f"frame-{i:03}.png") as src:
                im.paste(src.crop((126,30,366,211)).convert("RGB"),(v*240,24))
            draw.text((v*240+8,6),label,fill="white")
        draw.text((8,207),f"t={i/30:.2f}s  |  wind {'OFF' if i<60 or i>=180 else 'STEADY' if i<120 else 'GUSTS'}",fill="white")
        frames.append(im)
    for speed,name in [(1.,"comparison-1x.gif"),(.5,"comparison-half.gif")]:
        ends=[round((i+1)/(30*speed)*100)*10 for i in range(240)]
        frames[0].save(out/name,save_all=True,append_images=frames[1:],duration=np.diff([0,*ends]).tolist(),loop=0,disposal=1)
        with Image.open(out/name) as im:
            delays=[]
            for i in range(im.n_frames):im.seek(i);delays.append(im.info["duration"])
            assert sum(delays)==ends[-1]
    sheet=Image.new("RGB",(720,221*4))
    for j,i in enumerate((55,110,155,235)):sheet.paste(frames[i],(0,j*221))
    sheet.save(out/"review.png")
    (out/"metrics.json").write_text(json.dumps(metrics,indent=2));print(json.dumps(metrics),flush=True)
    for m in metrics.values():
        assert m["max_strain"]<.25 and m["replay_error"]<1e-6
        assert m["tip_steady"][0]>m["tip_no_wind"][0]+3
        assert m["tip_after"][1]>m["tip_steady"][1]+3
        assert m["cloth_pixels_min"]>15
    print("CLOTH_074_REVIEW_OK")
if __name__=="__main__":main()
