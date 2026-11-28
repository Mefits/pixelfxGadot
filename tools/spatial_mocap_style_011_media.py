"""Actual native Godot captures. Shared fixed crop; no retiming in export."""
from pathlib import Path
from PIL import Image, ImageDraw
import json, subprocess, sys
root=Path(sys.argv[1])
labels=["A G20 0.10 (2.83s)","B Mild (1.10s)","C Anime (0.90s)","D Extreme (0.80s)"]
ends=[170,66,54,48]
hits=[56,23,19,18]
lanes=[]
bbox=None
for mode,end in enumerate(ends):
    paths=sorted(root.glob(f"{mode}-near-*.png"))
    assert len(paths)==end+1,(mode,len(paths))
    frames=[Image.open(p).convert("RGBA") for p in paths]
    for im in frames:
        b=im.getchannel("A").getbbox()
        assert b and b[0]>0 and b[1]>0 and b[2]<im.width and b[3]<im.height
        bbox=b if bbox is None else (min(bbox[0],b[0]),min(bbox[1],b[1]),max(bbox[2],b[2]),max(bbox[3],b[3]))
    lanes.append(frames)
x0,y0,x1,y1=bbox
bbox=(max(0,x0-9),max(0,y0-9),min(480,x1+9),min(270,y1+9))
w=max(142,bbox[2]-bbox[0]);h=bbox[3]-bbox[1]
w+=w%2;h+=h%2
def tile(im):
    fg=im.crop(bbox)
    bg=Image.new("RGB",(w,h),(34,41,49))
    bg.paste(fg,((w-fg.width)//2,0),fg)
    return bg
def sheet(indices,modes):
    im=Image.new("RGB",(2*w,((len(modes)+1)//2)*(h+28)),(25,31,38))
    d=ImageDraw.Draw(im)
    for k,j in enumerate(modes):
        x=k%2*w;y=k//2*(h+28)
        i=min(indices[j],ends[j])
        d.text((x+4,y+3),labels[j],fill="white")
        d.text((x+4,y+15),f"tick {i}/{ends[j]}",fill=(180,190,200))
        im.paste(tile(lanes[j][i]),(x,y+28))
    return im
def clip(name,modes,end):
    frames=[sheet([i]*4,modes) for i in range(end+1)]
    # 60Hz source in GIF centisecond timing. End hold for visual comparison.
    ds=[round((i+1)*100/60)*10-round(i*100/60)*10 for i in range(len(frames))]
    ds[-1]+=300
    gif=root/f"{name}.gif"
    frames[0].save(gif,save_all=True,append_images=frames[1:],duration=ds,loop=0,disposal=2,optimize=False)
    with Image.open(gif) as im:
        total=sum((im.seek(i) or im.info.get("duration",0)) for i in range(im.n_frames))
        assert abs(total-sum(ds))<=10,(name,total,sum(ds))
    for speed,fps in (("normal",60),("half",30)):
        path=root/f"{name}_{speed}.mp4"
        W,H=frames[0].size
        p=subprocess.Popen(["ffmpeg","-y","-f","rawvideo","-pixel_format","rgb24","-video_size",f"{W}x{H}","-framerate",str(fps),"-i","-","-c:v","libx264","-pix_fmt","yuv420p","-movflags","+faststart",str(path)],stdin=subprocess.PIPE,stderr=subprocess.DEVNULL)
        for im in frames:p.stdin.write(im.tobytes())
        p.stdin.close();assert p.wait()==0
        stream=json.loads(subprocess.check_output(["ffprobe","-v","error","-select_streams","v:0","-show_entries","stream=nb_frames,duration","-of","json",str(path)]))["streams"][0]
        assert int(stream["nb_frames"])==len(frames) and abs(float(stream["duration"])-len(frames)/fps)<.04
clip("comparison",[0,1,2,3],170)
clip("stylized",[1,2,3],66)
for name,ticks in {"start":[0]*4,"chamber":[44,18,16,16],"impact":hits,"retract":[80,36,30,27],"end":ends}.items():
    sheet(ticks,[0,1,2,3]).save(root/f"phase_{name}.png")
print("verified native PNG count",sum(len(x) for x in lanes))
