"""Project a Y-up CMU/MotionBuilder BVH into lab.landmarks15.v1 (NumPy only).
Channel order is honored. The projection is orthographic and the camera is fixed.
"""
import argparse
import hashlib
import json
import math
from pathlib import Path
import numpy as np


def decode(path):
    raw=path.read_bytes()
    hierarchy, motion=raw.decode("utf-8-sig").split("MOTION",1)
    tokens=iter(hierarchy.split())
    if next(tokens)!="HIERARCHY" or next(tokens)!="ROOT":
        raise ValueError("Expected HIERARCHY ROOT")
    bones=[]
    channels=[]
    def bone(name,parent):
        index=len(bones)
        if next(tokens)!="{": raise ValueError("Expected opening brace")
        record={"name":name,"parent":parent,"channels":[]}
        bones.append(record)
        for token in tokens:
            if token=="OFFSET":
                record["offset"]=[float(next(tokens)) for _ in range(3)]
            elif token=="CHANNELS":
                for _ in range(int(next(tokens))):
                    record["channels"].append((next(tokens),len(channels)))
                    channels.append(index)
            elif token=="JOINT":
                bone(next(tokens),index)
            elif token=="End":
                if next(tokens)!="Site": raise ValueError("Invalid end site")
                bone(name+"_end",index)
            elif token=="}":
                return
            else: raise ValueError(f"Unknown hierarchy token {token}")
        raise ValueError("Unclosed bone")
    bone(next(tokens),-1)
    lines=motion.strip().splitlines()
    count=int(lines[0].split(":")[1])
    step=float(lines[1].split(":")[1])
    values=np.loadtxt(lines[2:],ndmin=2)
    if values.shape!=(count,len(channels)) or not np.isfinite(values).all() or step<=0:
        raise ValueError("Invalid BVH motion matrix")
    n=len(values)
    arrays=[]
    names={}
    for j in bones:
        local=np.tile(np.eye(4),(n,1,1))
        local[:,:3,3]=j["offset"]
        for channel,column in j["channels"]:
            axis="XYZ".index(channel[0])
            transform=np.tile(np.eye(4),(n,1,1))
            if channel[1:]=="position":
                transform[:,axis,3]=values[:,column]
            elif channel[1:]=="rotation":
                rad=np.radians(values[:,column])
                a,b=(axis+1)%3,(axis+2)%3
                transform[:,a,a]=transform[:,b,b]=np.cos(rad)
                transform[:,a,b]=-np.sin(rad)
                transform[:,b,a]=np.sin(rad)
            else:
                raise ValueError("Unknown channel "+channel)
            local=local@transform
        world=local if j["parent"]<0 else arrays[j["parent"]]@local
        arrays.append(world)
        names[j["name"]]=world[:,:3,3]
    return names,step,hashlib.sha256(raw).hexdigest()


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("input",type=Path)
    parser.add_argument("--near",choices=["Left","Right"],required=True)
    parser.add_argument("--view",required=True,help="Horizontal screen direction: degrees X toward Z, or travel")
    parser.add_argument("--out",type=Path,required=True)
    args=parser.parse_args()
    bones,step,digest=decode(args.input)
    near=args.near
    far="Right" if near=="Left" else "Left"
    def pair(name):
        return (bones["Left"+name]+bones["Right"+name])/2
    mapped=[pair("UpLeg"),pair("Arm"),bones["Head"]]
    for side,chain in [(near,["Arm","ForeArm","Hand"]),(far,["Arm","ForeArm","Hand"]),
                       (near,["UpLeg","Leg","Foot"]),(far,["UpLeg","Leg","Foot"])]:
        mapped.extend(bones[side+name] for name in chain)
    if args.view=="travel":
        travel=mapped[0][-1]-mapped[0][0]
        if np.hypot(travel[0],travel[2])<.1*np.linalg.norm(mapped[1][0]-mapped[0][0]):
            raise ValueError("Ambiguous travel direction; specify view angle")
        angle=math.atan2(travel[2],travel[0])
    else:
        angle=math.radians(float(args.view))
    data=np.stack(mapped,axis=1)
    x=data[:,:,0]*math.cos(angle)+data[:,:,2]*math.sin(angle)
    y=-data[:,:,1]
    # Quantize timestamps to the Lab clock without duplicating ticks.
    by_tick={}
    for i in range(len(x)):
        by_tick[round(i*step*120)]={"tick":round(i*step*120),
            "points":[[round(float(px),6),round(float(py),6),1.0] for px,py in zip(x[i],y[i])]}
    out={"format":"lab.landmarks15.v1","timebase_hz":120,"source":args.input.name,
         "source_sha256":digest,"near":near,"view_degrees":math.degrees(angle),
         "floor_y":float(np.percentile(y[:,[11,14]],98)),"frames":list(by_tick.values())}
    args.out.write_text(json.dumps(out,separators=(",",":"),allow_nan=False),encoding="utf-8")

if __name__=="__main__":
    main()
