"""Find silhouette changes in PNGs; build a Lab score from annotated screen poses.
PNG scanning needs Pillow. A 15-point track can come from a sprite annotation or
the optional MediaPipe video adapter. No clock, palette, pose or side is guessed.
"""
import argparse
import json
import math
import subprocess
import tempfile
from pathlib import Path
from statistics import median

JOINTS = ["hips","chest","head","shoulder_near","elbow_near","hand_near",
          "shoulder_far","elbow_far","hand_far","thigh_near","knee_near",
          "foot_near","thigh_far","knee_far","foot_far"]


def canonical_mask(path, box, background):
    from PIL import Image, ImageChops
    with Image.open(path) as src:
        image = src.convert("RGBA")
        if box:
            image = image.crop(box)
        if background:
            rgb = image.convert("RGB")
            delta = ImageChops.difference(rgb,Image.new("RGB",rgb.size,background))
            r,g,b = delta.split()
            mask=ImageChops.lighter(ImageChops.lighter(r,g),b).point(lambda v: 255 if v>12 else 0)
        else:
            mask=image.getchannel("A").point(lambda v: 255 if v>96 else 0)
            if mask.getextrema()==(255,255):
                raise ValueError(f"{path.name} is opaque. Select a plain background or provide alpha.")
        bounds=mask.getbbox()
        if not bounds:
            raise ValueError("Empty foreground in "+path.name)
        sprite=mask.crop(bounds)
        return sprite, [bounds[0],bounds[1],bounds[2],bounds[3]]


def silhouette_iou(a,b):
    from PIL import Image, ImageChops
    width=max(a.width,b.width)+4
    height=max(a.height,b.height)+4
    first=Image.new("L",(width,height))
    first.paste(a,((width-a.width)//2+2,(height-a.height)//2+2))
    # Small sub-pixel ground/camera phase changes move raster edges by a pixel.
    best=0
    for dx,dy in [(0,0),(-1,0),(1,0),(0,-1),(0,1)]:
        second=Image.new("L",first.size)
        second.paste(b,((width-b.width)//2+2+dx,(height-b.height)//2+2+dy))
        intersection=ImageChops.darker(first,second).histogram()[255]
        union=ImageChops.lighter(first,second).histogram()[255]
        best=max(best,intersection/union)
    return best


def scan(args):
    if not (0 < args.threshold < 1 and args.fps > 0):
        raise ValueError("Invalid threshold or FPS")
    files=sorted(args.input.glob(args.pattern))
    if not files: raise ValueError("No reference frames")
    keys=[]
    samples=[]
    anchor=None
    for index,path in enumerate(files):
        mask,bounds=canonical_mask(path,args.crop,args.background)
        similarity=0 if anchor is None else silhouette_iou(mask,anchor)
        if anchor is None or similarity<args.threshold:
            keys.append(index)
            anchor=mask
        samples.append({"frame":index,"t":index/args.fps,"bbox":bounds,"iou_with_last_key":round(similarity,5)})
    return {"format":"lab.silhouette.v1","fps":args.fps,"frames":len(files),"keys":keys,"samples":samples}


def minus(a,b):
    return a[0]-b[0],a[1]-b[1]


def segment(points,i,j):
    return math.dist(points[i][:2],points[j][:2])


def to_edits(track,min_confidence):
    if not math.isfinite(min_confidence) or not 0<=min_confidence<=1:
        raise ValueError("Confidence must be inside [0, 1]")
    if track.get("format")!="lab.landmarks15.v1" or not track.get("frames"):
        raise ValueError("Invalid track format")
    edits={}
    last=-1
    skipped=[]
    for frame in track["frames"]:
        tick=frame["tick"]
        if type(tick) is not int or tick<=last:
            raise ValueError("Expected strictly increasing integer ticks")
        last=tick
        points=frame["points"]
        if len(points)!=15 or any(len(p)!=3 or not all(math.isfinite(v) for v in p) or not 0<=p[2]<=1 for p in points):
            raise ValueError("Expected 15 finite x,y,confidence triples")
        if min(p[2] for p in points[:3])<min_confidence:
            skipped.append([tick,"torso"])
            continue
        def tilt(lo,hi):
            x,y=minus(points[hi],points[lo])
            if math.hypot(x,y)<0.001: raise ValueError("Zero-length torso")
            return max(-90,min(90,math.degrees(math.atan2(x,-y))))
        targets={}
        for i in [3,6,9,12]:
            tip=JOINTS[i+2]
            a,b,c=points[i:i+3]
            length=segment(points,i,i+1)+segment(points,i+1,i+2)
            if min(a[2],b[2],c[2])<min_confidence or length<0.001:
                skipped.append([tick,tip])
                continue
            x,y=minus(c,a)
            if math.hypot(x,y)/length<0.001:
                skipped.append([tick,tip])
                continue
            dx,dy=minus(b,a)
            pole=1 if x*dy-y*dx>=0 else -1
            targets[tip]=[round(x/length,7),round(y/length,7),pole]
        edits[str(tick)]={"tilt":[tilt(0,1),tilt(1,2)],"targets":targets,"yaw":[0]*6}
    if not edits: raise ValueError("No sufficiently confident reference poses")
    return {"version":1,"source":track.get("source","external landmark track"),"keys":edits},skipped


def video(args):
    import cv2
    import mediapipe as mp
    cap=cv2.VideoCapture(str(args.input))
    fps=cap.get(cv2.CAP_PROP_FPS)
    if not cap.isOpened() or not (0<fps<=120): raise ValueError("Expected readable constant-rate video, 0 < fps <= 120")
    vision=mp.tasks.vision
    opts=vision.PoseLandmarkerOptions(base_options=mp.tasks.BaseOptions(model_asset_path=str(args.model)),
                                      running_mode=vision.RunningMode.VIDEO,num_poses=1)
    frames=[]
    missing=[]
    n=0
    left=[11,13,15,23,25,27]
    right=[12,14,16,24,26,28]
    near,far=(left,right) if args.near=="left" else (right,left)
    try:
        with vision.PoseLandmarker.create_from_options(opts) as detector:
            while True:
                ok,pixels=cap.read()
                if not ok: break
                h,w=pixels.shape[:2]
                rgb=cv2.cvtColor(pixels,cv2.COLOR_BGR2RGB)
                result=detector.detect_for_video(mp.Image(image_format=mp.ImageFormat.SRGB,data=rgb),round(n*1000/fps))
                tick=round(n*120/fps)
                if result.pose_landmarks:
                    pts=[[v.x*w,v.y*h,min(v.visibility,v.presence)] for v in result.pose_landmarks[0]]
                    def middle(i,j):
                        return [(pts[i][0]+pts[j][0])/2,(pts[i][1]+pts[j][1])/2,min(pts[i][2],pts[j][2])]
                    mapped=[middle(23,24),middle(11,12),middle(7,8)]
                    mapped.extend(pts[i] for i in near[:3]+far[:3]+near[3:]+far[3:])
                    frames.append({"tick":tick,"points":mapped})
                else:
                    missing.append(tick)
                n+=1
    finally:
        cap.release()
    if len(frames)<2: raise ValueError("Too few detected poses")
    return {"format":"lab.landmarks15.v1","source":args.input.name,"near":args.near,
            "timebase_hz":120,"missing_ticks":missing,"frames":frames}


def compile_clip(args):
    track=json.loads(args.input.read_text(encoding="utf-8"))
    frames=track["frames"]
    if (track.get("timebase_hz")!=120 or len(frames)<2 or frames[0]["tick"]!=0
            or frames[-1]["tick"]>1200 or args.tolerance<0 or not math.isfinite(args.tolerance)
            or args.pose_threshold<0 or not math.isfinite(args.pose_threshold)):
        raise ValueError("Use 2+ poses, 120 Hz ticks, first tick 0, duration <= 10 seconds")
    if track.get("missing_ticks"):
        raise ValueError("Track contains missing detections; trim the take or repair the named ticks first")
    score,skipped=to_edits(track,args.confidence)
    if skipped:
        raise ValueError(f"Low confidence or degenerate chains: {skipped[:10]}")
    # Normalize a fixed-camera take with a single scale. A new scale per frame
    # would erase vertical root motion and turn torso noise into foot skating.
    torso=median(segment(f["points"],0,1) for f in frames)
    if torso<0.001: raise ValueError("Unable to establish reference scale")
    scale=16/torso
    first=frames[0]["points"]
    floor=args.floor if args.floor is not None else track.get("floor_y",max(first[11][1],first[14][1]))
    origin=first[0][0]
    draft=[]
    # Contact classification uses source-space pixels scaled to target art pixels.
    # Each planted interval needs at least three samples; boundaries remain editable.
    support=[[] for _ in frames]
    if args.plant:
        for name,idx in [("foot_near",11),("foot_far",14)]:
            active=[]
            for i,f in enumerate(frames):
                a=max(0,i-1)
                b=min(len(frames)-1,i+1)
                speed=math.dist(frames[a]["points"][idx][:2],frames[b]["points"][idx][:2])*scale*120/(frames[b]["tick"]-frames[a]["tick"])
                height=abs(f["points"][idx][1]-floor)*scale
                if height<=2.0 and speed<=24: active.append(i)
                else: active.append(None)
            start=0
            while start<len(active):
                if active[start] is None:
                    start+=1
                    continue
                stop=start+1
                while stop<len(active) and active[stop] is not None: stop+=1
                if frames[stop-1]["tick"]-frames[start]["tick"]>=2:
                    for i in range(start,stop): support[i].append(name)
                start=stop
    for i,f in enumerate(frames):
        x,y,_=f["points"][0]
        draft.append({"tick":f["tick"],"edit":score["keys"][str(f["tick"])],
                      "root":[(x-origin)*scale,(y-floor)*scale+22],"support":support[i]})
    events=track.get("events",[])
    if args.events:
        events=json.loads(args.events.read_text(encoding="utf-8"))
    data={"format":"lab.compile.v1","tolerance":args.tolerance,"frames":draft,"events":events,"slot":args.slot,
          "pose_threshold":args.pose_threshold,"plant":args.plant}
    if args.out.exists(): raise FileExistsError(args.out)
    args.out.parent.mkdir(parents=True,exist_ok=True)
    with tempfile.TemporaryDirectory(dir=args.out.parent) as temp:
        source=Path(temp).resolve()/"draft.json"
        product=Path(temp).resolve()/"clip.json"
        source.write_text(json.dumps(data,allow_nan=False),encoding="utf-8")
        cmd=[args.godot,"--headless","--log-file",str(source.with_suffix(".log")),
             "--path",str(Path(__file__).resolve().parents[1]/"godot"),"--script",
             "res://lab/motion_rd/compile_landmarks.gd","--",str(source),str(product)]
        run=subprocess.run(cmd,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=90)
        log=run.stdout.decode("utf-8","replace")
        lines=[line[9:] for line in log.splitlines() if line.startswith("RETARGET ")]
        if run.returncode or len(lines)!=1 or "SCRIPT ERROR:" in log: raise RuntimeError(log[-4000:])
        report=json.loads(lines[0])
        product.replace(args.out)
    print(json.dumps(report))


def main():
    p=argparse.ArgumentParser(description=__doc__)
    subs=p.add_subparsers(dest="mode",required=True)
    s=subs.add_parser("scan")
    s.add_argument("input",type=Path)
    s.add_argument("--pattern",default="frame_*.png")
    s.add_argument("--crop",nargs=4,type=int)
    s.add_argument("--background",help="e.g. #213542; omit for RGBA sprites")
    s.add_argument("--fps",type=float,required=True)
    s.add_argument("--threshold",type=float,default=.84)
    s.add_argument("--out",type=Path,required=True)
    r=subs.add_parser("score")
    r.add_argument("input",type=Path)
    r.add_argument("--ticks",nargs="+",type=int,help="Use only the specified reference ticks")
    r.add_argument("--confidence",type=float,default=.65)
    r.add_argument("--out",type=Path,required=True)
    v=subs.add_parser("video")
    v.add_argument("input",type=Path)
    v.add_argument("--model",type=Path,required=True)
    v.add_argument("--near",choices=["left","right"],required=True)
    v.add_argument("--out",type=Path,required=True)
    c=subs.add_parser("compile")
    c.add_argument("input",type=Path)
    c.add_argument("--godot",required=True)
    c.add_argument("--tolerance",type=float,default=.6)
    c.add_argument("--confidence",type=float,default=.65)
    c.add_argument("--pose-threshold",type=float,default=0,help="Hold until a root-relative joint moves this many art pixels")
    c.add_argument("--plant",action="store_true",help="Detect stationary source ankles near the supplied floor, then lock them")
    c.add_argument("--floor",type=float,help="Floor y in source pixels; default uses track floor or first ankle pair")
    c.add_argument("--slot",default="air_strike")
    c.add_argument("--events",type=Path,help="Optional SDK marker array, time in seconds")
    c.add_argument("--out",type=Path,required=True)
    args=p.parse_args()
    if args.mode=="compile":
        compile_clip(args)
        return
    if args.mode=="scan": result=scan(args)
    elif args.mode=="video": result=video(args)
    else:
        track=json.loads(args.input.read_text(encoding="utf-8"))
        if args.ticks:
            selected=set(args.ticks)
            track["frames"]=[f for f in track["frames"] if f["tick"] in selected]
            if len(track["frames"])!=len(selected): raise ValueError("Requested ticks missing from track")
        result,skipped=to_edits(track,args.confidence)
        result["uncertain"]=skipped
    args.out.write_text(json.dumps(result,indent=2,allow_nan=False)+"\n",encoding="utf-8")

if __name__=="__main__":
    main()
