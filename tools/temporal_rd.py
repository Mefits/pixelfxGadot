"""Temporal RD: actual Godot frame atlas, independent ranking and trajectory intervention."""
import argparse,copy,json,subprocess
from pathlib import Path
import numpy as np
from PIL import Image,ImageDraw
ROOT=Path(__file__).resolve().parents[1]
TILE=192
HEIGHT=224
Z=2.4
ORIGIN=np.array([108.,204.])
ZERO=[0,0,0,0,0]
PROBES=[ZERO,[-7,-20,-8,5,1],[7,20,8,-5,1],[-8,12,7,7,0],[8,-12,-7,-7,0],[0,-18,10,4,1],[0,18,-10,-4,1]]
REVISIONS={"rise":[[3,10,10,-5,1],[11,30,6,-5,1],[7,14,13,-2,1],[7,26,3,-8,1]],"sweep":[[4,-22,-5,-7,0],[12,-2,-9,-7,0],[8,-18,-2,-4,0],[8,-6,-12,-10,0]],"brace":[[-11,-30,-6,5,1],[-3,-10,-10,5,1],[-7,-26,-3,8,1],[-7,-14,-13,2,1]]}
def candidates(m):
    cs=[]
    def add(name,kind,v,body):
        cs.append(dict(name=name,kind=kind,v=v,motif=copy.deepcopy(body)))
    add("seed","old",ZERO,m)
    if m["id"]!="evade":
        add("Astra","old",m["old"],m)
        for v in PROBES+REVISIONS[m["id"]]:
            if not any(c["v"]==v for c in cs):add("old "+str(len(cs)),"old",v,m)
    if m["id"]=="sweep":
        for low in [2,4]:
            for tilt in [-8,4]:
                for load in [-14,-18]:
                    b=copy.deepcopy(m); k=b["keys"]
                    k[1][6+1]=[load+4,-low]; k[2][7]=[load,-low]
                    k[1][2]=-15;k[2][2]=-13;k[3][2]=-10
                    k[3][7]=[14,-low]; k[3][1]=-1
                    k[4][1]=0;k[5][1]=0
                    k[4][3]=tilt;k[5][3]=tilt
                    k[6][7]=[17,-low];k[6][2]=-13
                    # Preserve strike event and desired anchor (26,-7), far foot stays fixed.
                    add("low%d tilt%d load%d"%(low,tilt,load),"trajectory",ZERO,b)
        for lean in [-26,-38]:
            for lift in [2,4]:
                b=copy.deepcopy(m);k=b["keys"]
                b["near_leg_pole"]=-1.0
                k[1][7]=[-14,-2];k[2][7]=[-18,-2]
                k[1][2]=-15;k[2][2]=-13
                k[3][1]=-1;k[3][2]=-10-lift;k[3][7]=[14,-2]
                k[4][1]=0;k[5][1]=0
                for i in [4,5]:
                    k[i][2]=-10-lift;k[i][3]=-8;k[i][4]=lean
                    k[i][5]=[10,-30];k[i][6]=[-12,-32]
                k[6][7]=[17,-2];k[6][2]=-13
                add("knee-forward lean%d lift%d"%(lean,lift),"trajectory",ZERO,b)
    elif m["id"]=="brace":
        for early in [1,2]:
            for tilt in [-24,-32]:
                b=copy.deepcopy(m);k=b["keys"]
                for x in k:x[7]=[10,0];x[8]=[-9,0]
                k[3][1]=-5;k[3][4]=-4;k[3][5]=[12,-36]
                k[4][4]=tilt;k[5][4]=tilt
                k[3][0]=13+early
                add("planted recoil %d/%d"%(early,tilt),"trajectory",ZERO,b)
    elif m["id"]=="evade":
        for lift in [4,8]:
            for delay in [0,2]:
                b=copy.deepcopy(m);k=b["keys"]
                k[3][2]-=lift;k[4][2]-=lift
                for i in [3,4]:
                    for j in range(5,9):k[i][j][1]-=lift
                k[2][7]=[9,0];k[2][8]=[-9,0]
                k[5][0]+=delay
                add("jump lift%d delay%d"%(lift,delay),"trajectory",ZERO,b)
    return cs
def trace(r,tip):return np.array([s["points"][tip] for s in r])
def masks(images,i,tip):
    visible=[]
    for t,im in enumerate(images):
        a=np.asarray(im.crop((i*TILE,HEIGHT,(i+1)*TILE,2*HEIGHT)).convert("RGB"))
        red=(a[:,:,0]>200)&(a[:,:,1]<60)&(a[:,:,2]<60)
        # Actual visible distal limb within 4 art pixels of the intended tip.
        x,y=tip[t]*Z+ORIGIN
        yy,xx=np.ogrid[:HEIGHT,:TILE]
        region=(xx-x)**2+(yy-y)**2<=(4*Z)**2
        visible.append(float((red&region).sum()/max(1,region.sum())))
    return np.array(visible)
def assess(m,r,images,i):
    k=m["keys"];a,b,c=int(k[2][0]),int(k[4][0]),int(k[5][0])
    tip=trace(r,m["tip"]);hip=trace(r,"hips");chest=trace(r,"chest")
    vis=masks(images,i,tip)
    plant=max(x["plant"] for x in r)
    anchor=max(x["anchor"] for x in r[b:c+1]) if m["id"] in ("rise","sweep") else 0.
    floor=max(0.,max(float(trace(r,j)[:,1].max()) for j in ["knee_near","knee_far","foot_near","foot_far"]))
    f={"plant_error":plant,"contact_error":anchor,"tip_render_visible":float(vis[a:b+1].mean()),"floor_joint_penetration":floor}
    if m["id"]=="sweep":
        thigh=trace(r,"thigh_near"); knee=trace(r,"knee_near")
        phase=tip[a:b+1]
        extension=np.linalg.norm(tip-thigh,axis=1)/np.sqrt(125)/2
        f.update(height_mean=float(-phase[:,1].mean()),horizontal_span=float(np.ptp(phase[:,0])),extension=float(extension[a:b+1].mean()),accent_extension=float(extension[b]),path_efficiency=float(abs(phase[-1,0]-phase[0,0])/max(.001,np.linalg.norm(np.diff(phase,axis=0),axis=1).sum())))
        score=.32*np.clip(1-f["height_mean"]/15,0,1)+.18*np.clip(f["horizontal_span"]/36,0,1)+.24*f["extension"]+.16*f["accent_extension"]+.06*f["path_efficiency"]+.04*f["tip_render_visible"]
    elif m["id"]=="brace":
        near=trace(r,"foot_near");far=trace(r,"foot_far")
        drift=float(np.linalg.norm(np.diff(near,axis=0),axis=1).sum()+np.linalg.norm(np.diff(far,axis=0),axis=1).sum())
        # Recoil starts in pelvis, then upper torso, rather than leading with hands.
        onset=lambda q: next((j for j in range(a,b+1) if q[j,0]<q[a,0]-2),b+1)
        delay=onset(chest)-onset(hip)
        f.update(plant_drift=drift,pelvis_recoil=float(hip[a,0]-hip[b,0]),chest_delay_ticks=delay)
        score=.45*np.clip(1-drift/40,0,1)+.3*np.clip(f["pelvis_recoil"]/12,0,1)+.2*np.clip(1-abs(delay-2)/5,0,1)+.05*f["tip_render_visible"]
    elif m["id"]=="evade":
        feet=np.stack([trace(r,"foot_near"),trace(r,"foot_far")])
        clearance=-feet[:,:,1].max(axis=0)
        f.update(air_ticks=int((clearance>2).sum()),peak_clearance=float(clearance.max()),retreat=float(hip[0,0]-hip[-1,0]),landing_error=float(abs(feet[:,-1,1]).max()))
        score=.35*np.clip(f["peak_clearance"]/22,0,1)+.2*np.clip(f["air_ticks"]/20,0,1)+.3*np.clip(f["retreat"]/32,0,1)+.15*np.clip(1-f["landing_error"],0,1)
    else:
        f.update(vertical_travel=float(tip[a,1]-tip[b,1]))
        score=.5*np.clip(f["vertical_travel"]/30,0,1)+.5*f["tip_render_visible"]
    # A floor joint below the support plane is a separate measurable defect. Keep original scores comparable.
    f.update(score=float(score),floor_adjusted_score=float(score-.12*np.clip(floor/4,0,1)),eligible=plant<=.6 and anchor<=.6)
    return f
def gif(frames,path,rate):
    # GIF's centisecond clock, with no drift.
    delay=[10*(round((i+1)*100/rate)-round(i*100/rate)) for i in range(len(frames))]
    frames[0].save(path,save_all=True,append_images=frames[1:],duration=delay,loop=0,disposal=2)
def main():
    p=argparse.ArgumentParser();p.add_argument("--godot",required=True);p.add_argument("--out",type=Path,required=True);p.add_argument("--xvfb",action="store_true");a=p.parse_args()
    out=a.out.resolve();out.mkdir(parents=True,exist_ok=False)
    config=json.loads((ROOT/"godot/lab/temporal_rd/briefs.json").read_text())
    for m in config:m["candidates"]=candidates(m)
    path=out/"config.json";path.write_text(json.dumps(config,indent=2))
    raw=out/"raw";raw.mkdir()
    cmd=(["xvfb-run","-a","-s","-screen 0 5120x768x24"] if a.xvfb else [])+[a.godot,"--path",str(ROOT/"godot"),"--audio-driver","Dummy","--disable-vsync","--script","res://tests/temporal_rd.gd","--",str(path),str(raw)]
    proc=subprocess.run(cmd,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=180);log=proc.stdout.decode("utf8","replace");(out/"engine.log").write_text(log)
    if proc.returncode or "TEMPORAL_OK" not in log or "SCRIPT ERROR" in log:raise RuntimeError(log[-5000:])
    summary={}
    for m in config:
        mid=m["id"];folder=raw/mid;tracks=json.loads((folder/"tracks.json").read_text())
        images=[Image.open(f).convert("RGB") for f in sorted(folder.glob("*.png"))]
        ranks=[]
        for i,c in enumerate(m["candidates"]):
            ranks.append(dict(index=i,name=c["name"],kind=c["kind"],**assess(c["motif"],tracks[i],images,i)))
        old=[r for r in ranks if r["kind"]=="old" and r["eligible"]];new=[r for r in ranks if r["kind"]=="trajectory" and r["eligible"]]
        old_best=max(old,key=lambda r:r["score"]) if old else ranks[0]
        new_best=max(new,key=lambda r:r["floor_adjusted_score"]) if new else old_best
        astra=1 if mid!="evade" else 0
        # Rise is deliberately frozen as positive control.
        selected=astra if mid=="rise" else new_best["index"]
        idx=[0,astra,old_best["index"],selected] if mid!="evade" else [0,selected]
        labels=["Seed","Astra","Old reranked","New path"] if mid!="evade" else ["New brief","Edited path"]
        if mid=="rise":labels[-1]="Control kept"
        frames=[]
        for t in [0]*5+list(range(len(images)))+[len(images)-1]*7:
            im=Image.new("RGB",(TILE*len(idx),HEIGHT+26),"#172635");draw=ImageDraw.Draw(im)
            for j,i in enumerate(idx):
                im.paste(images[t].crop((i*TILE,0,(i+1)*TILE,HEIGHT)),(j*TILE,26));draw.text((j*TILE+8,7),labels[j],fill="white")
            frames.append(im)
        gif(frames,out/(mid+".gif"),60);gif(frames,out/(mid+"-half.gif"),30)
        (out/(mid+"-sdk.json")).write_bytes((folder/("clip_%02d.json"%selected)).read_bytes())
        summary[mid]={"seed":ranks[0],"astra":ranks[astra],"old_reranked":old_best,"new_path":ranks[selected],"new_eligible":len(new),"ranks":ranks}
    (out/"report.json").write_text(json.dumps(summary,indent=2))
    print(json.dumps({k:{x:round(v[x]["score"],3) for x in ("seed","astra","old_reranked","new_path")} for k,v in summary.items()}))
if __name__=="__main__":main()
