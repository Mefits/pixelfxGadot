"""Actual four-preset Godot comparison. Same source motion, separate rig dimensions."""
import argparse,json,subprocess
from pathlib import Path
import numpy as np
from PIL import Image,ImageDraw
from scipy.ndimage import label
from body_deformation_058 import ROOT,FIXTURES,LINKS,fetch,intervals,union_volume,stats
LABELS=("A / adult 069 C","B / slim youth","C / tall lean","D / compact broad")
W,H=288,270
def labelled(path):
    src=Image.open(path).convert("RGB")
    im=Image.new("RGB",(W*4,H+26),"#192632");im.paste(src,(0,26))
    d=ImageDraw.Draw(im)
    for i,title in enumerate(LABELS):d.text((W*i+12,7),title,fill="white")
    return im
def review(out,clips):
    data=json.loads((out/"records.json").read_text())
    rows=data["rows"];solids=json.loads((out/"solids.json").read_text())
    assert len(rows)==len(solids)==192
    golden={(c["clip"],s["tick"]) for c in clips for s in c["samples"]}
    yy,xx=np.mgrid[0:H,0:W];x=(xx-128)/3;y=(yy-225)/3
    summary=[]
    for i in range(4):
        gaps=[];maskdiff=0;overlap=[];vol=[];feet=[];stand_size=None
        for r,s in zip(rows,solids):
            clip,tick=r["clip"],r["tick"]
            assert (clip,tick)==(s["clip"],s["tick"])
            rgb=np.asarray(Image.open(out/f"{clip}-{tick:03}.png").convert("RGB"))[:,W*i:W*(i+1)]
            mask=np.any(rgb!=rgb[0,0],axis=-1)&np.any(rgb!=0,axis=-1)
            if label(mask)[1]!=1:gaps.append([clip,tick])
            parts=s["lanes"][i]
            if clip=="stand":
                ys,xs=np.where(mask)
                stand_size={"height_px":int(ys.max()-ys.min()+1),"width_px":int(xs.max()-xs.min()+1),"head_height_px":float(parts[18]["radii"][1]*6),"bottom_y_px":int(ys.max())}
            # Source ankle coordinates change with body dimensions. Report
            # trajectory difference, not a claim of contact-preserving retarget.
            j=r["lanes"][i]["joints"];a=r["lanes"][0]["joints"]
            feet.append(max(np.linalg.norm(np.array(j[k])-a[k]) for k in ("foot_near","foot_far")))
            if clip!="stand" and (clip,tick) not in golden:continue
            lo,hi=(np.array(v) for v in zip(*(intervals(p,x,y) for p in parts)))
            maskdiff=max(maskdiff,int(np.sum(np.any(hi>=lo,axis=0)!=mask)))
            links=[(0,1),(1,18),(0,2),(2,3),(3,4),(4,14),(0,5),(5,6),(6,7),(7,15),(0,8),(8,9),(9,10),(10,16),(0,11),(11,12),(12,13),(13,17)]
            overlap.append([float(np.maximum(0,np.minimum(hi[a],hi[b])-np.maximum(lo[a],lo[b])).sum()/9) for a,b in links])
            vol.append(float(union_volume(lo,hi,3)))
        ov=np.array(overlap)
        summary.append({"lane":LABELS[i],"disconnected_frames":len(gaps),"disconnected_examples":gaps[:8],"oracle_mask_diff_max":maskdiff,"sampled_poses":len(vol),"min_attachment_overlap":float(ov.min()),"weakest_pair":list(links[int(np.unravel_index(ov.argmin(),ov.shape)[1])]),"stand":stand_size,"volume_ratio_min":min(vol)/vol[0],"volume_ratio_max":max(vol)/vol[0],"ankle_path_difference":stats(feet),"timings_us":{k:stats([r["lanes"][i][k] for r in rows[8:]]) for k in ("prepare_us","raster_us","bridge_us")}})
    assert summary[0]["disconnected_frames"]==0
    assert all(s["oracle_mask_diff_max"]<=5 for s in summary)
    (out/"metrics.json").write_text(json.dumps({"poses":len(rows),"fk_max_error":data["max_xy"],"lanes":summary},indent=2))
    stand=Image.open(out/"stand-000.png").convert("RGB")
    preview=Image.new("RGB",(880,540),"#192632");d=ImageDraw.Draw(preview)
    for i,n in enumerate(LABELS):
        crop=stand.crop((W*i+73,0,W*i+183,270)).resize((220,540),Image.Resampling.NEAREST)
        preview.paste(crop,(220*i,0));d.text((220*i+8,5),n,fill="white")
    preview.save(out/"stand-review.png")
    sheet=Image.new("RGB",(W*4,(H+26)*5))
    for i,(name,tick) in enumerate([("stand",0),(clips[2]["clip"],0),(clips[0]["clip"],12),(clips[1]["clip"],38),(clips[2]["clip"],50)]):
        tile=labelled(out/f"{name}-{tick:03}.png");sheet.paste(tile,(0,(H+26)*i))
    sheet.save(out/"review.png")
    for speed,name in [(1.1,"comparison-1p1.gif"),(.5,"comparison-half.gif")]:
        frames=[];ends=[];elapsed=0.
        for c in clips:
            clip=c["clip"];duration=json.loads((out/(clip+".json")).read_text())["payload"]["clip"]["duration"];ticks=round(duration*60)
            for t in range(0,ticks,2):
                frames.append(labelled(out/f"{clip}-{t:03}.png"))
                elapsed+=min(2,ticks-t)/(60*speed);ends.append(round(elapsed*100)*10)
        frames[0].save(out/name,save_all=True,append_images=frames[1:],duration=np.diff([0,*ends]).tolist(),loop=0,disposal=1)
        with Image.open(out/name) as im:
            assert im.n_frames==len(frames)
            delays=[]
            for i in range(im.n_frames):im.seek(i);delays.append(im.info["duration"])
            assert sum(delays)==ends[-1]
    print("BODY_DIMENSIONS_070_REVIEW_OK",json.dumps(summary))
if __name__=="__main__":
    p=argparse.ArgumentParser();p.add_argument("--godot",required=True);p.add_argument("--out",type=Path,required=True);a=p.parse_args()
    out=a.out.resolve();out.mkdir(parents=True,exist_ok=True)
    clips=json.loads(FIXTURES.read_text())["clips"]
    for clip in clips:fetch(out,clip)
    r=subprocess.run(["xvfb-run","-a",a.godot,"--path",str(ROOT/"godot"),"--audio-driver","Dummy","--disable-vsync","--rendering-method","gl_compatibility","--script","res://tests/body_dimensions_070.gd","--",str(out)],stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=240)
    log=r.stdout.decode("utf8","replace");(out/"engine.log").write_text(log);print(log)
    if r.returncode or "BODY_070_OK" not in log or "SCRIPT ERROR" in log:raise RuntimeError(log[-4000:])
    review(out,clips)
