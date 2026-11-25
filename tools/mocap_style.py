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

def combo047(frames,meta):
    # First strike is F from the exact ACCAD source; remaining strikes are
    # authored extensions, not claimed as additional recorded mocap.
    f=variants046(frames,meta)[3]
    seq=copy.deepcopy(f["frames"][:23])
    start=seq[-1]
    def pose(x,y,tilt,hip,near,far):
        p=copy.deepcopy(start)
        p.update(root=[x,y],tilt=tilt,hip_extra=hip)
        p["targets"]["hand_near"]=[*near,1]
        p["targets"]["hand_far"]=[*far,1]
        # The two recorded planted ankles remain locked in the retargeter.
        p["feet"]=[[a[0],0] for a in start["feet"]]
        return p
    # Cross: retract right while loading the left, no return to idle.
    # Uppercut: sink during left recovery, then drive right fist upward.
    # Positions are normalized target rays, never changes to bone length.
    authored=[
        (22,start),
        (26,pose(3.5,-2.4,-7,-6,(.38,.18),(.27,.02))),
        (28,pose(3.0,-2.1,-10,-7,(.22,.10),(.24,.06))),
        (32,pose(7.2,-3.9,28,7,(.26,.21),(1.05,-.10))),
        (34,pose(7.0,-3.8,26,6,(.25,.18),(1.03,-.10))),
        (40,pose(2.6,.0,-14,-6,(.08,.62),(.47,-.09))),
        (42,pose(3.0,-.3,-10,-4,(.22,.55),(.42,-.12))),
        (46,pose(7.5,-4.5,12,5,(.66,-.73),(.34,.12))),
        (48,pose(7.2,-4.3,10,4,(.64,-.72),(.34,.12))),
        (54,pose(5.5,-2.8,2,0,(.36,-.12),(.48,.05))),
        (64,pose(5.0,-3.0,-3,0,(.50,.02),(.55,.03))),
    ]
    for (a,lo),(b,hi) in zip(authored,authored[1:]):
        for k in range(a+1,b+1):
            u=(k-a)/(b-a)
            # Near-linear attack travel, eased load/recovery. Identical across lanes.
            if b not in (32,46):u=u*u*(3-2*u)
            blend=lambda x,y:(np.array(x)*(1-u)+np.array(y)*u).tolist()
            p=copy.deepcopy(lo)
            p.update(root=blend(lo["root"],hi["root"]),tilt=lo["tilt"]*(1-u)+hi["tilt"]*u,
                     hip_extra=lo.get("hip_extra",0)*(1-u)+hi.get("hip_extra",0)*u,
                     feet=blend(lo["feet"],hi["feet"]))
            for tip in p["targets"]:
                p["targets"][tip]=blend(lo["targets"][tip][:2],hi["targets"][tip][:2])+[lo["targets"][tip][2]]
            seq.append(p)
    assert len(seq)==65 and seq[:23]==f["frames"][:23]
    events=[{"tick":20,"anchor":"hand_near"},{"tick":32,"anchor":"hand_far"},{"tick":46,"anchor":"hand_near"}]
    out=[]
    for label,rate in [("F / full",0),("24 poses/s",24),("15 poses/s",15),("Authored holds",-1)]:
        v=copy.deepcopy(f)
        v.update(label=label,frames=copy.deepcopy(seq),cadence=rate,combo=True,events=events,
                 holds=[0,3,6,9,12,14,17,20,23,26,28,32,35,38,40,42,46,49,53,57,61,64])
        out.append(v)
    return out

def bag048(frames,meta):
    base=combo047(frames,meta)[0]
    out=[]
    for label,body,cadence in [("A / original",False,0),("B / aim only",False,0),("C / aim + shoulder",True,0)]:
        v=copy.deepcopy(base)
        v.update(label=label,bag=True,cadence=cadence,aim=(label[0]!="A"))
        # Fixed bag front at x=36 rig px; target wrist slightly in front.
        # Aim envelopes are sampled after support IK. No motion of bag.
        for i,f in enumerate(v["frames"]):
            if not v["aim"]:continue
            if body:
                w=float(np.interp(i,[0,22,26,28,32,34,38,42,64],[0,0,0,0,1,0.9,0.3,0,0]))
                # Shoulder travel primarily from pelvis rotation: hip angle
                # moves chest base, not just the angle of the arm.
                f["hip_extra"]=f.get("hip_extra",0)+18*w
                f["tilt"]+=12*w
                f["root"][0]+=3.5*w
                f["root"][1]+=1.0*w
            # Do not aim the wrist during windup or the recovery into the next blow.
            windows=[(20,17,22,"hand_near",[33.5,-32.5],.35),
                     (32,28,35,"hand_far",[33.5,-33.0],1.0),
                     (46,42,49,"hand_near",[32.0,-47.0],.40)]
            for hit,lo,hi,tip,target,weight in windows:
                if lo<i<hi:
                    u=(i-lo)/(hit-lo) if i<=hit else (hi-i)/(hi-hit)
                    f["aim_tip"]=tip
                    f["aim_point"]=target
                    f["aim_weight"]=weight*u*u*(3-2*u)
        out.append(v)
    return out

def shoulder049(frames,meta):
    # Compare equal clocks and target goals; only shoulder geometry changes.
    base=bag048(frames,meta)[1]
    out=[]
    for label,mode in [("A / fixed shoulders","fixed"),("B / centered","center"),("C / turning shoulders","turn")]:
        v=copy.deepcopy(base)
        v.update(label=label,shoulder_mode=mode)
        for i,f in enumerate(v["frames"]):
            if mode=="center":
                f["shoulder_turn"]=45.0
            elif mode=="turn":
                # Projection swaps which shoulder leads. Keep the original
                # first jab and last rising punch, turn during their transition.
                f["shoulder_turn"]=float(np.interp(i,[0,22,26,32,34,40,44,64],[0,0,28,90,90,30,0,0]))
                # A slight shoulder-turn envelope smoothing is applied at
                # authoring knots by the normal pose interpolation.
        out.append(v)
    return out

def pelvis050(frames,meta):
    # Owner accepted C. Keep its first jab through tick 22 exactly.
    base=shoulder049(frames,meta)[2]
    seq=copy.deepcopy(base["frames"][:23])
    start=seq[-1]
    def pose(x,y,tilt,hip,shoulder,near,far,leg,support):
        p=copy.deepcopy(start)
        for k in ("aim_tip","aim_point","aim_weight"):p.pop(k,None)
        p.update(root=[x,y],tilt=tilt,hip_extra=hip,shoulder_turn=shoulder)
        p["targets"]["hand_near"]=[*near,1]
        p["targets"]["hand_far"]=[*far,1]
        p["targets"]["foot_far"]=[*leg,-1]
        p["feet"]=[[start["feet"][0][0],0],[start["feet"][1][0],0 if support else -10]]
        return p
    # Authored kick, not mocap: retract jab, chamber far knee, extend,
    # re-chamber, plant, finish with rising near punch. Shared path/clocks.
    knots=[
        (22,start),
        (26,pose(2.5,-1.5,-8,-4,20,(.35,.05),(.45,-.08),(.12,.96),False)),
        (32,pose(3.5,-2.0,-19,-5,12,(.25,.12),(.54,-.15),(.42,.30),False)),
        (38,pose(7.0,-2.5,-18,3,8,(.35,.18),(.35,-.13),(.98,-.12),False)),
        (40,pose(7.0,-2.5,-18,3,8,(.35,.18),(.35,-.13),(.98,-.12),False)),
        (46,pose(4.0,-2.0,-12,-3,32,(.22,.40),(.48,-.08),(.42,.30),False)),
        (52,pose(4.0,-1.0,-10,-3,25,(.10,.60),(.47,-.09),(.05,.98),True)),
        (56,pose(4.0,-.3,-10,-4,12,(.22,.55),(.42,-.12),(.05,.98),True)),
        (60,pose(7.5,-4.5,12,5,0,(.66,-.73),(.34,.12),(.05,.98),True)),
        (62,pose(7.2,-4.3,10,4,0,(.64,-.72),(.34,.12),(.05,.98),True)),
        (68,pose(5.5,-2.8,2,0,0,(.36,-.12),(.48,.05),(.05,.98),True)),
        (76,pose(5.0,-3.0,-3,0,0,(.50,.02),(.55,.03),(.05,.98),True)),
    ]
    for (a,lo),(b,hi) in zip(knots,knots[1:]):
        for k in range(a+1,b+1):
            u=(k-a)/(b-a)
            if b not in (38,60):u=u*u*(3-2*u)
            blend=lambda x,y:(np.array(x)*(1-u)+np.array(y)*u).tolist()
            p=copy.deepcopy(lo)
            for key in ("aim_tip","aim_point","aim_weight"):p.pop(key,None)
            p.update(root=blend(lo["root"],hi["root"]),tilt=lo["tilt"]*(1-u)+hi["tilt"]*u,
                hip_extra=lo.get("hip_extra",0)*(1-u)+hi.get("hip_extra",0)*u,
                shoulder_turn=lo.get("shoulder_turn",0)*(1-u)+hi.get("shoulder_turn",0)*u,
                feet=blend(lo["feet"],hi["feet"]))
            p["feet"][0][1]=0
            p["feet"][1][1]=-10 if 25<=k<52 else 0
            for tip in p["targets"]:
                p["targets"][tip]=blend(lo["targets"][tip][:2],hi["targets"][tip][:2])+[hi["targets"][tip][2] if tip=="foot_far" else lo["targets"][tip][2]]
            if 32<k<44:
                w=(k-32)/6 if k<=38 else (44-k)/6
                p.update(aim_tip="foot_far",aim_point=[32.0,-23.0],aim_weight=w*w*(3-2*w))
            if 56<k<64:
                w=(k-56)/4 if k<=60 else (64-k)/4
                p.update(aim_tip="hand_near",aim_point=[32.0,-47.0],aim_weight=.4*w*w*(3-2*w))
            seq.append(p)
    assert len(seq)==77 and seq[:23]==base["frames"][:23]
    events=[{"tick":20,"anchor":"hand_near"},{"tick":38,"anchor":"foot_far"},{"tick":60,"anchor":"hand_near"}]
    out=[]
    for label,mode in [("A / fixed pelvis","fixed"),("B / coupled","coupled"),("C / independent","independent")]:
        v=copy.deepcopy(base)
        v.update(label=label,frames=copy.deepcopy(seq),events=events,cadence=0,pelvis_mode=mode)
        for i,f in enumerate(v["frames"]):
            if mode=="coupled":f["pelvis_turn"]=f.get("shoulder_turn",0)
            elif mode=="independent":
                f["pelvis_turn"]=float(np.interp(i,[0,22,26,32,38,40,46,52,56,76],[0,0,12,40,90,90,45,0,0,0]))
        out.append(v)
    return out

def shell051a(frames,meta):
    base=pelvis050(frames,meta)[2]
    out=[]
    for label,style in [("A / old shell",0),("B / joined contours",1),("C / fitted anatomy",2)]:
        v=copy.deepcopy(base)
        v.update(label=label,skin51=style)
        out.append(v)
    assert all(v["frames"]==base["frames"] and v["events"]==base["events"] for v in out)
    return out

def foot051b(frames,meta):
    base=shell051a(frames,meta)[2]
    out=[]
    for label,mode in [("A / fixed feet",0),("B / kick ankle",1),("C / toe pivot",2)]:
        v=copy.deepcopy(base)
        v.update(label=label,foot51=mode)
        for i,f in enumerate(v["frames"]):
            if mode==0:continue
            # Chamber, dorsiflexed push/heel kick, re-chamber, plant.
            f["foot_pitch_far"]=float(np.interp(i,[0,24,28,32,38,40,46,51,52,76],
                [0,0,20,-22,-58,-58,-12,0,0,0]))
            f["foot_pitch_near"]=float(np.interp(i,[0,22,26,32,38,40,46,52,56,76],
                [0,0,6,18,32,32,17,0,0,0])) if mode==2 else 0.0
        out.append(v)
    return out

def reference051c(frames,meta):
    base=foot051b(frames,meta)[2]
    out=[]
    # These are hand-authored side-view directions from the owner's still,
    # not motion capture. Opposite arm is outstretched, near arm folded.
    # hip/chest pitch -58 deg, kick axis -40 deg, leg extension .98.
    # Keep previous and following punches and all three event ticks.
    for label,mode in [("A / previous",0),("B / photo pose",1),("C / photo + support",2)]:
        v=copy.deepcopy(base)
        v.update(label=label,reference51=mode)
        if mode:
            # smooth phase envelope: load, chamber, high extension, retract, plant.
            knots=[(0,0),(22,0),(25,.12),(30,.58),(34,.84),(38,1),(40,1),(44,.65),(48,.24),(52,0),(76,0)]
            for i,f in enumerate(v["frames"]):
                w=0.
                for (a,x),(b,y) in zip(knots,knots[1:]):
                    if a<=i<=b:
                        u=(i-a)/(b-a);u=u*u*(3-2*u);w=x+(y-x)*u;break
                if w<=0:continue
                def mix(old,new):return (1-w)*old+w*new
                f["tilt"]=mix(f["tilt"],-58.)
                f["hip_extra"]=mix(f.get("hip_extra",0),-1.)
                # Keep hip leading toward the kick. The photo has shoulders
                # counter-turned; avoid dragging near hand across the face.
                f["shoulder_turn"]=mix(f.get("shoulder_turn",0),15.)
                f["pelvis_turn"]=mix(f.get("pelvis_turn",0),90.)
                goal=[.98*np.cos(np.deg2rad(-40)),.98*np.sin(np.deg2rad(-40))]
                # Retain the old chamber in early/late frames rather than
                # instantly straighten the leg.
                ext=float(np.interp(i,[22,30,34,38,40,46,52],[0,.12,.48,1,1,.08,0]))
                for j in range(2):
                    f["targets"]["foot_far"][j]=(1-ext)*f["targets"]["foot_far"][j]+ext*goal[j]
                for tip,target in [("hand_near",(.36,.40)),("hand_far",(.93,-.10))]:
                    for j in range(2):f["targets"][tip][j]=mix(f["targets"][tip][j],target[j])
                f["foot_pitch_far"]=mix(f["foot_pitch_far"],-76.)
                f["foot_pitch_near"]=mix(f["foot_pitch_near"],8.)
                # Explicitly replace the previous waist-height world aim.
                if f.get("aim_tip")=="foot_far":
                    f.pop("aim_tip");f.pop("aim_point");f.pop("aim_weight")
                if mode==2:
                    f["reference_support_weight"]=w
        out.append(v)
    return out

def gif(frames,path,fps):
    delay=[10*(round((i+1)*100/fps)-round(i*100/fps)) for i in range(len(frames))]
    frames[0].save(path,save_all=True,append_images=frames[1:],duration=delay,loop=0,disposal=2)
def main():
    ap=argparse.ArgumentParser();ap.add_argument("--godot",required=True);ap.add_argument("--out",type=Path,required=True);ap.add_argument("--bvh",type=Path);ap.add_argument("--xvfb",action="store_true");ap.add_argument("--stage",choices=["45","46","46b","47","48","49","50","51a","51b","51c"],default="51c");a=ap.parse_args()
    out=a.out.resolve();out.mkdir(parents=True,exist_ok=False);raw,name=source(out,a.bvh);frames,meta=build(raw,name)
    if a.stage!="45" and meta["sha256"]!="8a56bfb4422138f061a0e36148354a43dd62a5b9645cbdf6cee8122e5c40fde8":raise ValueError("0.46 requires the exact 0.45 source")
    config=reference051c(frames,meta) if a.stage=="51c" else foot051b(frames,meta) if a.stage=="51b" else shell051a(frames,meta) if a.stage=="51a" else pelvis050(frames,meta) if a.stage=="50" else shoulder049(frames,meta) if a.stage=="49" else bag048(frames,meta) if a.stage=="48" else combo047(frames,meta) if a.stage=="47" else cadence046(frames,meta) if a.stage=="46b" else variants046(frames,meta) if a.stage=="46" else variants(frames,meta);(out/"source-report.json").write_text(json.dumps(meta,indent=2));(out/"config.json").write_text(json.dumps(config))
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
    if a.stage in ("46b","47"):
        select=sorted(set(range(0,len(imgs),2))|{config[0]["contact"],len(imgs)-1}|{e["tick"] for e in config[0].get("events",[])})
        fast=[imgs[0]]*6+[imgs[i] for i in select]+[imgs[-1]]*6
        gif(fast,out/"comparison-1p2.gif",36)
    if a.stage in ("48","49","50","51a","51b","51c"):
        # Keep all strike frames, 20+ ms delays, exact rounded 1.1x cycle.
        select=sorted(set(range(0,len(imgs),2))|{len(imgs)-1}|{e["tick"] for e in config[0]["events"]})
        spans=[(imgs[0],12)]+[(imgs[k],(select[j+1]-k if j+1<len(select) else 1)) for j,k in enumerate(select)]+[(imgs[-1],12)]
        merged=[]
        for im,n in spans:
            if merged and merged[-1][0].tobytes()==im.tobytes():merged[-1]=(im,merged[-1][1]+n)
            else:merged.append((im,n))
        elapsed=0;delays=[]
        for _,n in merged:
            delays.append(10*(round((elapsed+n)*100/66)-round(elapsed*100/66)));elapsed+=n
        assert min(delays)>=20
        merged[0][0].save(out/"comparison-1p1.gif",save_all=True,append_images=[im for im,_ in merged[1:]],duration=delays,loop=0,disposal=2)
    review_ticks=[0,20,32,38,46,52,60,76] if a.stage in ("50","51a","51b","51c") else [0,20,28,32,40,46,64] if a.stage in ("47","48","49") else [0,config[0]["contact"],len(imgs)-1]
    sheet=Image.new("RGB",(imgs[0].width,imgs[0].height*len(review_ticks)),"#142332")
    for row,i in enumerate(review_ticks):sheet.paste(imgs[min(i,len(imgs)-1)],(0,row*imgs[0].height))
    sheet.save(out/"review.png")
    if a.stage=="51c":
        imgs[38].save(out/"contact-review.png")
    if a.stage=="51a":
        clips=[json.loads((out/f"clip_{i}.json").read_text())["payload"] for i in range(3)]
        assert clips[0]==clips[1]==clips[2], "Skin variants must not alter animation data"
        (out/"shell-report.json").write_text(json.dumps({"identical_payloads":True,"samples":len(imgs),"styles":["old","joined","fitted"],"fixed_depth_order":True},indent=2))
    if a.stage in ("49","50"):
        entry=json.loads((out/"clip_2.json").read_text())
        full=entry["payload"]["clip"]["keys"]
        # Editable artistic knots, NOT error-bounded compression. Includes every strike.
        ticks=[0,9,14,20,22,26,32,38,40,46,52,56,60,62,68,76] if a.stage=="50" else [0,9,14,17,20,22,26,28,32,34,40,42,46,48,54,64]
        entry["payload"]["clip"]["keys"]=[full[k] for k in ticks]
        entry.update(id="lab0"+a.stage+"_combo_min",name="Lab 0."+a.stage+" C - minimal")
        (out/("Lab0"+a.stage+"_Combo_Minimal.json")).write_text(json.dumps(entry,indent=2))
if __name__=="__main__":main()
