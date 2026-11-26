"""Capture the actual standalone Godot wind room; normal and half speed."""
import argparse,json,subprocess
from pathlib import Path
import numpy as np
from PIL import Image,ImageDraw
ROOT=Path(__file__).resolve().parents[1]
def stats(v):
    return dict(zip(("min","p50","p95","max"),map(float,np.percentile(v,[0,50,95,100]))))
def main():
    p=argparse.ArgumentParser();p.add_argument("--godot",required=True);p.add_argument("--out",type=Path,required=True);a=p.parse_args()
    out=a.out.resolve();out.mkdir(parents=True,exist_ok=True)
    r=subprocess.run(["xvfb-run","-a",a.godot,"--path",str(ROOT/"godot"),"--audio-driver","Dummy","--disable-vsync","--rendering-method","gl_compatibility","--script","res://tests/wind_room_072.gd","--",str(out)],stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=240)
    log=r.stdout.decode("utf8","replace");(out/"engine.log").write_text(log);print(log)
    if r.returncode or "WIND_072_CAPTURE_OK" not in log or "SCRIPT ERROR" in log:raise RuntimeError(log[-4000:])
    d=json.loads((out/"records.json").read_text());rows=d["rows"];assert len(rows)==240
    frames=[Image.open(out/f"frame-{i:03}.png").convert("RGB") for i in range(240)]
    for speed,name in [(1.,"comparison-1x.gif"),(.5,"comparison-half.gif")]:
        ends=[round((i+1)/(30*speed)*100)*10 for i in range(240)]
        frames[0].save(out/name,save_all=True,append_images=frames[1:],duration=np.diff([0,*ends]).tolist(),loop=0,disposal=1)
        with Image.open(out/name) as im:
            delays=[]
            for i in range(im.n_frames):im.seek(i);delays.append(im.info["duration"])
            assert sum(delays)==ends[-1]
    sheet=Image.new("RGB",(960,540))
    for j,i in enumerate([55,110,155,235]):sheet.paste(frames[i],((j%2)*480,(j//2)*270))
    sheet.save(out/"wind-review.png")
    frames[110].save(out/"stand-review.png")
    tip=lambda lo,hi:np.array([r["tip"] for r in rows[lo:hi]]).mean(axis=0).tolist()
    metrics={"nodes":d["nodes"],"triangles":d["triangles"],"frames":len(rows),"max_strain":d["max_strain"],"replay_error":d["replay_error"],"tip_no_wind":tip(40,60),"tip_steady":tip(100,120),"tip_gust":tip(140,180),"tip_after":tip(220,240),"cloth_pixels":stats([r["cloth_pixels"] for r in rows]),"timings_us":{k:stats([r[k] for r in rows[10:]]) for k in ["physics_us","prepare_us","raster_us","bridge_us"]}}
    (out/"metrics.json").write_text(json.dumps(metrics,indent=2));print(json.dumps(metrics))
    assert d["max_strain"]<.25 and d["replay_error"]<1e-6
    assert metrics["tip_steady"][0]>metrics["tip_no_wind"][0]+3
    assert metrics["cloth_pixels"]["min"]>15
    print("WIND_072_REVIEW_OK")
if __name__=="__main__":main()
