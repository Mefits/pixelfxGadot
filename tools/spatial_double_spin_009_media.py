"""Build mobile comparisons from native Godot PNGs. No synthetic pose frames."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageChops
import json, subprocess, sys
root=Path(sys.argv[1])
labels=["A L 0.08 D (hold after 36)","B Double spin","C Anime double spin"]
report={}
for side in ("near","far"):
    lanes=[]
    bbox=None
    for mode in range(3):
        paths=sorted(root.glob(f"{mode}-{side}-*.png"))
        assert len(paths)==61, (side,mode,len(paths))
        frames=[Image.open(p).convert("RGBA") for p in paths]
        for im in frames:
            b=im.getchannel("A").getbbox()
            assert b and b[0]>0 and b[1]>0 and b[2]<im.width and b[3]<im.height
            bbox=b if bbox is None else (min(bbox[0],b[0]),min(bbox[1],b[1]),max(bbox[2],b[2]),max(bbox[3],b[3]))
        lanes.append(frames)
    x0,y0,x1,y1=bbox
    bbox=(max(0,x0-9),max(0,y0-9),min(480,x1+9),min(270,y1+9))
    w,h=bbox[2]-bbox[0],bbox[3]-bbox[1]
    # Full common bounding box, no pose-dependent camera motion.
    w+=w%2;h+=h%2
    def tile(im):
        fg=im.crop(bbox)
        bg=Image.new("RGB",(w,h),(34,41,49))
        bg.paste(fg,(0,0),fg)
        return bg
    def sheet(i,modes=(0,1,2)):
        im=Image.new("RGB",(2*w,((len(modes)+1)//2)*(h+24)),(25,31,38))
        d=ImageDraw.Draw(im)
        for k,j in enumerate(modes):
            x=k%2*w;y=k//2*(h+24)
            d.text((x+6,y+5),labels[j],fill="white")
            im.paste(tile(lanes[j][i]),(x,y+24))
        d.text((w+6,h+29),f"Tick {i:02} / 60",fill="white")
        d.text((w+6,h+44),"60 Hz source",fill="white")
        return im
    frames=[sheet(i) for i in range(61)]
    # 60 Hz source; final still held for readability in looping GIF only.
    durations=[20 if i%3!=1 else 10 for i in range(61)]
    durations[-1]+=300
    frames[0].save(root/f"{side}_comparison.gif",save_all=True,append_images=frames[1:],duration=durations,loop=0,disposal=2,optimize=False)
    path=root/f"{side}_quarter.mp4"
    W,H=frames[0].size
    p=subprocess.Popen(["ffmpeg","-y","-f","rawvideo","-pixel_format","rgb24","-video_size",f"{W}x{H}","-framerate","15","-i","-","-c:v","libx264","-pix_fmt","yuv420p","-movflags","+faststart",str(path)],stdin=subprocess.PIPE,stderr=subprocess.DEVNULL)
    for im in frames:p.stdin.write(im.tobytes())
    p.stdin.close();assert p.wait()==0
    stream=json.loads(subprocess.check_output(["ffprobe","-v","error","-select_streams","v:0","-show_entries","stream=nb_frames,duration","-of","json",str(path)]))["streams"][0]
    assert int(stream["nb_frames"])==61 and abs(float(stream["duration"])-61/15)<.04
    # Actual key samples, separately inspect wind-up, impact, follow-through, landing.
    for i in (8,16,20,24,33,38,44,47,52,60):sheet(i).save(root/f"{side}_tick_{i:02}.png")
    differences={}
    for j in range(1,3):
        changed=[sum(p!=(0,0,0) for p in ImageChops.difference(tile(a),tile(b)).getdata()) for a,b in zip(lanes[0],lanes[j])]
        assert max(changed)>0,(side,j)
        differences[labels[j]]={"changed_frames":sum(n>0 for n in changed),"peak_pixels":max(changed)}
    report[side]=differences
(root/"visual_metrics.json").write_text(json.dumps(report,indent=2))
print(report)
