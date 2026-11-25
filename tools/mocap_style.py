"""Lab 0.45: real recorded jab, four controlled variants. No synthetic source fallback."""
import argparse,copy,hashlib,io,json,math,subprocess,urllib.request,zipfile,re
from pathlib import Path
import numpy as np
from PIL import Image,ImageDraw
ROOT=Path(__file__).resolve().parents[1]
URL="https://accad.ohio-state.edu/sites/accad.osu.edu/files/Male2_bvh.zip"
def decode(raw):
    h,m=raw.decode("utf-8-sig").split("MOTION",1)
    tokens=iter(h.split());assert next(tokens)=="HIERARCHY" and next(tokens)=="ROOT"
    bones=[];channels=[]
    def bone(name,parent):
        i=len(bones);assert next(tokens)=="{"
        b=dict(name=name,parent=parent,channels=[]);bones.append(b)
        for t in tokens:
            if t=="OFFSET":b["offset"]=[float(next(tokens)) for _ in range(3)]
            elif t=="CHANNELS":
                for _ in range(int(next(tokens))):
                    b["channels"].append((next(tokens),len(channels)));channels.append(i)
            elif t=="JOINT":bone(next(tokens),i)
            elif t=="End":assert next(tokens)=="Site";bone(name+"_end",i)
            elif t=="}":return
            else:raise ValueError(t)
    bone(next(tokens),-1)
    lines=m.strip().splitlines();n=int(lines[0].split(":")[1]);dt=float(lines[1].split(":")[1])
    vals=np.loadtxt(lines[2:],ndmin=2);assert vals.shape==(n,len(channels))
    mats=[];pts={}
    for b in bones:
        local=np.tile(np.eye(4),(n,1,1));local[:,:3,3]=b["offset"]
        for channel,col in b["channels"]:
            axis="XYZ".index(channel[0]);tr=np.tile(np.eye(4),(n,1,1))
            if channel.endswith("position"):tr[:,axis,3]=vals[:,col]
            else:
                rad=np.radians(vals[:,col]);i,j=(axis+1)%3,(axis+2)%3
                tr[:,i,i]=tr[:,j,j]=np.cos(rad);tr[:,i,j]=-np.sin(rad);tr[:,j,i]=np.sin(rad)
            local=local@tr
        world=local if b["parent"]<0 else mats[b["parent"]]@local
        mats.append(world);pts[b["name"].lower().split(":")[-1]]=world[:,:3,3]
    return pts,dt
def source(out,local):
    if local: raw=local.read_bytes();name=local.name
    else:
        with urllib.request.urlopen(URL,timeout=50) as r: z=zipfile.ZipFile(io.BytesIO(r.read()))
        files=[n for n in z.namelist() if n.lower().endswith(".bvh") and "__MACOSX" not in n]
        norm=lambda n:re.sub(r"[^a-z]","",Path(n).stem.lower())
        options=[n for n in files if "jabright" in norm(n) and "body" not in norm(n)]
        if not options:raise ValueError("Right jab missing: "+str(files))
        name=sorted(options)[0];raw=z.read(name)
    (out/"source.bvh").write_bytes(raw)
    return raw,name
def build(raw,name):
    p,dt=decode(raw)
    def get(side,part):
        aliases={"arm":["arm","upperarm","shoulder"],"forearm":["forearm","lowerarm","elbow"],"hand":["hand","wrist"],"upleg":["upleg","thigh","hip"],"leg":["leg","lowerleg","shin","knee"],"foot":["foot","ankle"]}
        for s in [side,side[0]]:
            for b in aliases[part]:
                k=s+b
                for n in p:
                    if re.sub("[^a-z]","",n)==k:return p[n]
        raise KeyError((side,part,list(p)))
    arms=[[get(s,b) for b in ["arm","forearm","hand"]] for s in ["right","left"]]
    legs=[[get(s,b) for b in ["upleg","leg","foot"]] for s in ["right","left"]]
    hip=(legs[0][0]+legs[1][0])/2;chest=(arms[0][0]+arms[1][0])/2
    n=len(hip);torso=np.median(np.linalg.norm(chest-hip,axis=1));assert n>20
    # Determine action peak from extension and preceding movement, excluding boundaries.
    rel=arms[0][2]-arms[0][0];horizontal=rel[:,[0,2]]
    speed=np.linalg.norm(np.diff(horizontal,axis=0,prepend=horizontal[:1]),axis=1)/dt
    span=max(2,round(.16/dt));peaks=np.array([speed[max(0,i-span):i+1].max() for i in range(n)])
    ext=np.linalg.norm(horizontal,axis=1)/torso
    merit=ext*np.minimum(1,peaks/(torso*4))
    edge=min(n//4,max(2,round(.35/dt)));merit[:edge]=0;merit[n-edge:]=0
    hit=int(np.argmax(merit));forward=horizontal[hit]/np.linalg.norm(horizontal[hit])
    project=lambda a:np.stack([a[:,[0,2]]@forward,-a[:,1]],axis=1)
    h=project(hip);c=project(chest)
    chains=[[project(a) for a in chain] for chain in arms+legs]
    lengths=[np.median(np.linalg.norm(chain[1]-chain[0],axis=1)+np.linalg.norm(chain[2]-chain[1],axis=1)) for chain in arms+legs]
    start=max(0,hit-round(.43/dt));end=min(n-1,hit+round(.48/dt))
    scale=16/torso;floor=max(np.percentile(chains[2][2][start:end+1,1],95),np.percentile(chains[3][2][start:end+1,1],95))
    # Select source anticipation from minimum wrist extension before contact.
    prep=start+int(np.argmin(horizontal[start:hit+1]@forward));prep=min(hit-1,max(start+1,prep))
    def vec(a,i):return a[i]
    frames=[]
    previous=[1,1,-1,-1]
    for i in range(start,end+1):
        targets={}
        for j,(tip,ch,L) in enumerate(zip(["hand_near","hand_far","foot_near","foot_far"],chains,lengths)):
            a,b,d=[x[i] for x in ch];ray=d-a;mid=b-a;cross=ray[0]*mid[1]-ray[1]*mid[0]
            # Use measured bend, retain sign through near-collinear ambiguity.
            if abs(cross)>L*L*.007:previous[j]=1 if cross>0 else -1
            targets[tip]=[float(ray[0]/L),float(ray[1]/L),previous[j]]
        tilt=math.degrees(math.atan2(c[i,0]-h[i,0],h[i,1]-c[i,1]))
        feet=[[float((ch[2][i,0]-h[start,0])*scale),float((ch[2][i,1]-floor)*scale)] for ch in chains[2:]]
        frames.append(dict(t=(i-start)*dt,root=[float((h[i,0]-h[start,0])*scale),float((h[i,1]-floor)*scale+22)],tilt=tilt,targets=targets,feet=feet))
    return frames,dict(source=name,source_url=URL,license="Open Motion Project by ACCAD / The Ohio State University, CC BY 3.0",sha256=hashlib.sha256(raw).hexdigest(),source_frames=n,source_dt=dt,trim_start=start,trim_end=end,contact_source_frame=hit,prep_source_frame=prep,prep=(prep-start)*dt,contact=(hit-start)*dt,duration=(end-start)*dt)
def interpolate(frames,t):
    times=np.array([f["t"] for f in frames]);j=int(np.clip(np.searchsorted(times,t),1,len(frames)-1))
    a,b=frames[j-1],frames[j];u=float(np.clip((t-a["t"])/(b["t"]-a["t"]),0,1))
    lerp=lambda x,y:(np.array(x)*(1-u)+np.array(y)*u).tolist()
    return dict(root=lerp(a["root"],b["root"]),tilt=a["tilt"]*(1-u)+b["tilt"]*u,feet=lerp(a["feet"],b["feet"]),targets={k:lerp(a["targets"][k][:2],b["targets"][k][:2])+[(a if u<.5 else b)["targets"][k][2]] for k in a["targets"]})
def variants(frames,meta):
    dur=meta["duration"];prep=meta["prep"];hit=meta["contact"];out=[]
    for label,retime,style in [("A RAW",False,False),("B RHYTHM",True,False),("C POSES",False,True),("D HYBRID",True,True)]:
        timeline=[0,prep,hit,dur] if not retime else [0,.23,.33,.63]
        duration=timeline[-1];n=math.ceil(duration*60);contact=round(timeline[2]*60)
        seq=[]
        for i in range(n+1):
            t=min(i/60,duration)
            if retime:
                # Explicit 3-frame contact hold followed by accelerated return.
                s=float(np.interp(t,[0,.23,.33,.38,.63],[0,prep,hit,hit,dur]))
            else:s=t
            f=interpolate(frames,s)
            if style:
                w=math.exp(-((s-hit)/.075)**2);load=math.exp(-((s-prep)/.10)**2)
                f["tilt"]+=9*w-8*load
                f["root"][0]+=2.8*w-1.5*load
                hand=f["targets"]["hand_near"]
                hand[0]+= .16*w-.11*load;hand[1]*=1-.35*w
                # Passive arm remains sourced, not forced into an arbitrary pose.
            seq.append(f)
        out.append(dict(label=label,frames=seq,contact=contact,style=style,retime=retime))
    return out
def variants046(frames,meta):
    # Preserve the actual 0.45 D controls, not a reconstruction of them.
    d=variants(frames,meta)[3]
    control=copy.deepcopy(d)
    control["label"]="D 0.45 / old skin"
    revised=copy.deepcopy(d)
    revised.update(label="D / new skin",skin46=True)
    out=[control,revised]
    for label,strength in [("E / moderate",0.55),("F / strong",1.0),("G / extreme",1.65)]:
        v=copy.deepcopy(revised)
        v["label"]=label
        v["strength"]=strength
        for i,f in enumerate(v["frames"]):
            t=i/60
            # Phase-local edits; all variants retain D's contact and total clock.
            load=math.exp(-((t-.23)/.065)**2)
            strike=math.exp(-((t-.35)/.060)**2)
            release=math.exp(-((t-.43)/.065)**2)
            f["tilt"]+=strength*(5*strike-4*load-2*release)
            f["root"][0]+=strength*(1.2*strike-.8*load)
            f["root"][1]+=strength*(.7*load-.25*strike)
            # Counter-rotation between hips and chest, net torso tilt unchanged.
            f["hip_extra"]=strength*(-4*load+5*strike)
            near=f["targets"]["hand_near"]
            near[0]+=strength*(.045*strike-.055*load)
            near[1]-=strength*.025*strike
            # Keep the passive arm in a compact, readable guard, preserving its bend sign.
            far=f["targets"]["hand_far"]
            blend=min(.62,strength*(.23*load+.34*strike+.12*release))
            far[0]=(1-blend)*far[0]+blend*.30
            far[1]=(1-blend)*far[1]+blend*(-.25)
        out.append(v)
    assert out[0]["frames"]==d["frames"] and out[1]["frames"]==d["frames"]
    return out

def cadence046(frames,meta):
    f=variants046(frames,meta)[3]
    out=[]
    for label,rate in [("F / full",0),("24 poses/s",24),("15 poses/s",15),("8 poses/s",8),("Authored holds",-1)]:
        v=copy.deepcopy(f)
        v.update(label=label,cadence=rate)
        out.append(v)
    return out

def gif(frames,path,fps):
    delay=[10*(round((i+1)*100/fps)-round(i*100/fps)) for i in range(len(frames))]
    frames[0].save(path,save_all=True,append_images=frames[1:],duration=delay,loop=0,disposal=2)
def main():
    ap=argparse.ArgumentParser();ap.add_argument("--godot",required=True);ap.add_argument("--out",type=Path,required=True);ap.add_argument("--bvh",type=Path);ap.add_argument("--xvfb",action="store_true");ap.add_argument("--stage",choices=["45","46","46b"],default="46b");a=ap.parse_args()
    out=a.out.resolve();out.mkdir(parents=True,exist_ok=False);raw,name=source(out,a.bvh);frames,meta=build(raw,name)
    if a.stage!="45" and meta["sha256"]!="8a56bfb4422138f061a0e36148354a43dd62a5b9645cbdf6cee8122e5c40fde8":raise ValueError("0.46 requires the exact 0.45 source")
    config=cadence046(frames,meta) if a.stage=="46b" else variants046(frames,meta) if a.stage=="46" else variants(frames,meta);(out/"source-report.json").write_text(json.dumps(meta,indent=2));(out/"config.json").write_text(json.dumps(config))
    print(meta,flush=True)
    cmd=(["xvfb-run","-a","-s","-screen 0 1280x768x24"] if a.xvfb else [])+[a.godot,"--path",str(ROOT/"godot"),"--audio-driver","Dummy","--disable-vsync","--script","res://tests/mocap_style.gd","--",str(out)]
    p=subprocess.run(cmd,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=100);log=p.stdout.decode("utf8","replace");(out/"engine.log").write_text(log);print(log)
    if p.returncode or "MOCAP_STYLE_OK" not in log or "SCRIPT ERROR" in log:raise RuntimeError(log[-4000:])
    files=sorted(out.glob("[0-9][0-9][0-9].png"));imgs=[]
    for i,f in enumerate(files):
        src=Image.open(f).convert("RGB");im=Image.new("RGB",(src.width,src.height+25),"#142332");im.paste(src,(0,25));d=ImageDraw.Draw(im)
        for j,v in enumerate(config):d.text((j*240+10,7),v["label"],fill="white")
        imgs.append(im)
    assert imgs
    seq=[imgs[0]]*12+imgs+[imgs[-1]]*12
    gif(seq,out/"comparison.gif",60);gif(seq,out/"comparison-half.gif",30)
    # Browser-safe 1.2x review: minimum 20ms delay, retain the contact sample.
    if a.stage=="46b":
        select=sorted(set(range(0,len(imgs),2))|{config[0]["contact"],len(imgs)-1})
        fast=[imgs[0]]*5+[imgs[i] for i in select]+[imgs[-1]]*5
        gif(fast,out/"comparison-1p2.gif",36)
    sheet=Image.new("RGB",(imgs[0].width,imgs[0].height*3),"#142332")
    for row,i in enumerate([0,config[0]["contact"],len(imgs)-1]):sheet.paste(imgs[min(i,len(imgs)-1)],(0,row*imgs[0].height))
    sheet.save(out/"review.png")
if __name__=="__main__":main()
