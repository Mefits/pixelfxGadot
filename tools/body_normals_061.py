"""Capture the original and three art profiles; verify all 192 native poses."""
import argparse,json,subprocess
from pathlib import Path
import numpy as np
from PIL import Image,ImageDraw
from scipy.ndimage import label
from body_deformation_058 import ROOT,FIXTURES,LINKS,fetch,intervals,union_volume,stats
LABELS=("A / original 060 B","B / subtle normals","C / wider blend")
def labelled(path):
    src=Image.open(path).convert("RGB")
    im=Image.new("RGB",(864,266),"#192632");im.paste(src,(0,26))
    d=ImageDraw.Draw(im)
    for i,title in enumerate(LABELS):d.text((288*i+12,7),title,fill="white")
    return im
def review(out,clips):
    data=json.loads((out/"records.json").read_text())
    rows=data["rows"];solids=json.loads((out/"solids.json").read_text())
    assert len(rows)==len(solids)==192
    summary=[]
    golden={(c["clip"],s["tick"]) for c in clips for s in c["samples"]}
    for i in range(3):
        gaps=0;min_overlap=float("inf");pelvic_overlap=float("inf");vol=[];maskdiff=0
        for r,s in zip(rows,solids):
            clip,tick=r["clip"],r["tick"]
            assert (clip,tick)==(s["clip"],s["tick"])
            rgb=np.asarray(Image.open(out/f"{clip}-{tick:03}.png").convert("RGB"))[:,288*i:288*(i+1)]
            mask=np.any(rgb!=rgb[0,0],axis=-1)&np.any(rgb!=0,axis=-1)
            gaps+=int(label(mask)[1]!=1)
            # Quantitative 3D proxy on stand and the historical frozen pose set.
            if clip!="stand" and (clip,tick) not in golden:continue
            yy,xx=np.where(mask);sy=slice(max(0,yy.min()-8),min(240,yy.max()+9));sx=slice(max(0,xx.min()-8),min(288,xx.max()+9))
            y,x=np.mgrid[sy,sx];x=(x-128)/3;y=(y-200)/3
            lo,hi=(np.array(v) for v in zip(*(intervals(p,x,y) for p in s["lanes"][i])))
            vol.append(float(union_volume(lo,hi,3)))
            min_overlap=min(min_overlap,min(float(np.maximum(0,np.minimum(hi[a],hi[b])-np.maximum(lo[a],lo[b])).sum()/9) for a,b in LINKS))
            pelvic_overlap=min(pelvic_overlap,min(float(np.maximum(0,np.minimum(hi[a],hi[b])-np.maximum(lo[a],lo[b])).sum()/9) for a,b in [(0,5),(5,6),(0,11),(11,12)]))
            maskdiff=max(maskdiff,int(np.sum(np.any(hi>=lo,axis=0)!=mask[sy,sx])))
        summary.append({"lane":LABELS[i],"disconnected_frames":gaps,"min_attachment_overlap":min_overlap,"min_pelvic_overlap":pelvic_overlap,"sampled_poses":len(vol),"normal_pixels":stats([r["lanes"][i]["normal_pixels"] for r in rows]),"changed_pixels":stats([r["lanes"][i]["changed_pixels"] for r in rows]),"volume_ratio_min":min(vol)/vol[0],"volume_ratio_max":max(vol)/vol[0],"mask_difference_max_px":maskdiff,"timings_us":{k:stats([r["lanes"][i][k] for r in rows[8:]]) for k in ("prepare_us","raster_us","bridge_us")}})
    (out/"metrics.json").write_text(json.dumps({"poses":len(rows),"fk_max_error":data["max_xy"],"lanes":summary},indent=2))
    sheet=Image.new("RGB",(864,266*5))
    for i,(name,tick) in enumerate([("stand",0),(clips[2]["clip"],0),(clips[0]["clip"],12),(clips[1]["clip"],38),(clips[2]["clip"],50)]):
        tile=labelled(out/f"{name}-{tick:03}.png");ImageDraw.Draw(tile).text((710,7),f"{tick:02}",fill="white");sheet.paste(tile,(0,266*i))
    sheet.save(out/"review.png")
    stand=Image.open(out/"stand-000.png").convert("RGB")
    preview=Image.new("RGB",(630,420),"#192632")
    d=ImageDraw.Draw(preview)
    for i,n in enumerate(LABELS):
        crop=stand.crop((288*i+75,15,288*i+180,225)).resize((210,420),Image.Resampling.NEAREST)
        preview.paste(crop,(210*i,0));d.text((210*i+8,5),n,fill="white")
    preview.save(out/"stand-review.png")
    for speed,name in [(1.1,"comparison-1p1.gif"),(.5,"comparison-half.gif")]:
        frames=[];ends=[];elapsed=0.
        for c in clips:
            clip=c["clip"];duration=json.loads((out/(clip+".json")).read_text())["payload"]["clip"]["duration"];ticks=round(duration*60)
            for t in range(0,ticks,2):
                im=labelled(out/f"{clip}-{t:03}.png");ImageDraw.Draw(im).text((710,7),f"{t:02}",fill="white");frames.append(im)
                elapsed+=min(2,ticks-t)/(60*speed);ends.append(round(elapsed*100)*10)
        frames[0].save(out/name,save_all=True,append_images=frames[1:],duration=np.diff([0,*ends]).tolist(),loop=0,disposal=1)
        with Image.open(out/name) as im:
            assert im.n_frames==len(frames)
            delays=[]
            for i in range(im.n_frames):im.seek(i);delays.append(im.info["duration"])
            assert sum(delays)==ends[-1] and min(delays)>=20
    print("BODY_NORMALS_061_REVIEW_OK",json.dumps(summary))
if __name__=="__main__":
    p=argparse.ArgumentParser();p.add_argument("--godot",required=True);p.add_argument("--out",type=Path,required=True);a=p.parse_args()
    out=a.out.resolve();out.mkdir(parents=True,exist_ok=True)
    clips=json.loads(FIXTURES.read_text())["clips"]
    for clip in clips:fetch(out,clip)
    r=subprocess.run(["xvfb-run","-a",a.godot,"--path",str(ROOT/"godot"),"--audio-driver","Dummy","--disable-vsync","--rendering-method","gl_compatibility","--script","res://tests/body_normals_061.gd","--",str(out)],stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=180)
    log=r.stdout.decode("utf8","replace");(out/"engine.log").write_text(log);print(log)
    if r.returncode or "BODY_061_OK" not in log or "SCRIPT ERROR" in log:raise RuntimeError(log[-4000:])
    review(out,clips)
