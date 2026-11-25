"""Capture the original and three art profiles; verify all 192 native poses."""
import argparse,json,subprocess
from pathlib import Path
import numpy as np
from PIL import Image,ImageDraw
from scipy.ndimage import label,binary_erosion
from body_deformation_058 import ROOT,FIXTURES,LINKS,fetch,intervals,union_volume,stats
LABELS=("A / approved 063 C","B / shoulder profiles","C / visual shoulder roots")
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
    yy,xx=np.mgrid[0:240,0:288]
    x=(xx-128)/3;y=(yy-200)/3
    for i in range(3):
        gaps=0;maskdiff=0;overlaps=[];vol=[];root_excess=[]
        for r,s in zip(rows,solids):
            clip,tick=r["clip"],r["tick"]
            assert (clip,tick)==(s["clip"],s["tick"])
            rgb=np.asarray(Image.open(out/f"{clip}-{tick:03}.png").convert("RGB"))[:,288*i:288*(i+1)]
            mask=np.any(rgb!=rgb[0,0],axis=-1)&np.any(rgb!=0,axis=-1)
            gaps+=int(label(mask)[1]!=1)
            if clip!="stand" and (clip,tick) not in golden:continue
            parts=s["lanes"][i]
            lo,hi=(np.array(v) for v in zip(*(intervals(p,x,y) for p in parts)))
            maskdiff=max(maskdiff,int(np.sum(np.any(hi>=lo,axis=0)!=mask)))
            overlaps.append(min(float(np.maximum(0,np.minimum(hi[a],hi[b])-np.maximum(lo[a],lo[b])).sum()/9) for a,b in [(0,2),(2,3),(0,8),(8,9)]))
            vol.append(float(union_volume(lo,hi,3)))
            for k in [3,9]:
                ax,ay,az=parts[k]["a"]
                low,high=intervals(parts[0],np.array(ax),np.array(ay))
                root_excess.append(float(max(low-az,az-high,0)) if high>=low else None)
        summary.append({"lane":LABELS[i],"disconnected_frames":gaps,"oracle_mask_diff_max":maskdiff,"sampled_poses":len(vol),"min_shoulder_overlap":min(overlaps),"volume_ratio_min":min(vol)/vol[0],"volume_ratio_max":max(vol)/vol[0],"root_outside_count":sum(v is None or v>1e-5 for v in root_excess),"root_xy_outside_count":sum(v is None for v in root_excess),"root_excess_max":max((v for v in root_excess if v is not None),default=0),"maskdiff":stats([r["lanes"][i]["maskdiff"] for r in rows]),"body_pixels":stats([r["lanes"][i]["body_pixels"] for r in rows]),"proxy_xy_max":max(r["lanes"][i]["proxy_xy"] for r in rows),"proxy_z_max":max(r["lanes"][i]["proxy_z"] for r in rows),"timings_us":{k:stats([r["lanes"][i][k] for r in rows[8:]]) for k in ("prepare_us","raster_us","bridge_us")}})
    assert summary[0]["proxy_xy_max"]<1e-5 and summary[1]["proxy_xy_max"]<1e-5 and summary[2]["proxy_xy_max"]>.5
    assert summary[1]["maskdiff"]["max"]>0 and summary[2]["maskdiff"]["max"]>0
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
    # Real Godot pixel crop, not a synthetic render.
    pelvis=Image.new("RGB",(720,240),"#192632")
    for i,n in enumerate(LABELS):
        tile=stand.crop((288*i+88,44,288*i+168,124)).resize((240,240),Image.Resampling.NEAREST)
        pelvis.paste(tile,(240*i,0))
    pelvis.save(out/"shoulder-review.png")
    # Diagnostic overlay over actual Godot captures. Analytic individual
    # Loft XY contours are drawn separately from source FK and visual axes.
    diag=json.loads((out/"side.json").read_text())
    picks=[(rows[0],solids[0]),(diag["row"],diag["solids"])]
    for name,tick in [(clips[2]["clip"],0),(clips[1]["clip"],38),(clips[2]["clip"],50)]:
        picks.append(next((r,s) for r,s in zip(rows,solids) if r["clip"]==name and r["tick"]==tick))
    extra=json.loads((out/"shoulder-extra.json").read_text())
    picks.extend((v["row"],v["solids"]) for v in extra)
    sheet2=Image.new("RGB",(864,266*len(picks)))
    for n,(r,s) in enumerate(picks):
        tile=labelled(out/f'{r["clip"]}-{r["tick"]:03}.png')
        d=ImageDraw.Draw(tile)
        for i,parts in enumerate(s["lanes"]):
            def at(p):return (288*i+128+3*p[0],226+3*p[1])
            for j,color in [(0,"#5fe3f1"),(1,"#5fe3f1"),(2,"#f5b54f"),(8,"#f5b54f"),(3,"#8cf39c"),(9,"#8cf39c")]:
                lo,hi=intervals(parts[j],x,y)
                m=hi>=lo
                cy,cx=np.where(m&~binary_erosion(m))
                d.point([(int(a)+288*i,int(b)+26) for a,b in zip(cx,cy)],fill=color)
            joints=r["joints"]
            for side in ["far","near"]:
                for a,b in [("hips","chest"),("chest","shoulder_"+side),("shoulder_"+side,"elbow_"+side),("elbow_"+side,"hand_"+side)]:
                    d.line([at(joints[a]),at(joints[b])],fill="white",width=1)
                k=3 if side=="far" else 9
                d.line([at(parts[k]["a"]),at(parts[k]["b"])],fill="#fa71cf",width=1)
                for key in ["hips","chest","shoulder_"+side,"elbow_"+side,"hand_"+side]:
                    a,b=at(joints[key]);d.ellipse((a-2,b-2,a+2,b+2),outline="white")
                a,b=at(parts[k]["a"]);d.ellipse((a-2,b-2,a+2,b+2),fill="#fa71cf")
        d.text((12,250),f'{r["clip"]} / {r["tick"]} | cyan trunk/neck, gold shoulder, green arm, white FK, pink visual arm',fill="white")
        sheet2.paste(tile,(0,266*n))
    sheet2.save(out/"rig-overlay.png")
    labelled(out/"side-000.png").save(out/"side-review.png")
    raised=Image.new("RGB",(864,266*3))
    for i,turn in enumerate([0,45,90]):
        raised.paste(labelled(out/f"raised-{turn:03}.png"),(0,i*266))
    raised.save(out/"raised-review.png")
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
    print("BODY_SHOULDERS_064_REVIEW_OK",json.dumps(summary))
if __name__=="__main__":
    p=argparse.ArgumentParser();p.add_argument("--godot",required=True);p.add_argument("--out",type=Path,required=True);a=p.parse_args()
    out=a.out.resolve();out.mkdir(parents=True,exist_ok=True)
    clips=json.loads(FIXTURES.read_text())["clips"]
    for clip in clips:fetch(out,clip)
    r=subprocess.run(["xvfb-run","-a",a.godot,"--path",str(ROOT/"godot"),"--audio-driver","Dummy","--disable-vsync","--rendering-method","gl_compatibility","--script","res://tests/body_shoulders_064.gd","--",str(out)],stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=180)
    log=r.stdout.decode("utf8","replace");(out/"engine.log").write_text(log);print(log)
    if r.returncode or "BODY_064_OK" not in log or "SCRIPT ERROR" in log:raise RuntimeError(log[-4000:])
    review(out,clips)
