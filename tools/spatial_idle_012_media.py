"""Native Godot 60Hz idle capture; periodic preview has no end hold."""
from pathlib import Path
from PIL import Image,ImageDraw,ImageChops
import sys,json,subprocess
root=Path(sys.argv[1])
labels=["A G20 guard","B E8 loop","C E8 45%","D C + 15 deg"]
lanes=[];bounds=[]
for mode in range(4):
    paths=sorted(root.glob(f"{mode}-near-*.png"));assert len(paths)==48
    ims=[Image.open(p).convert("RGBA") for p in paths]
    for im in ims:
        b=im.getchannel("A").getbbox();assert b and b[0]>0 and b[1]>0 and b[2]<im.width and b[3]<im.height
        bounds.append(b)
    lanes.append(ims)
bbox=(min(b[0] for b in bounds)-8,min(b[1] for b in bounds)-8,max(b[2] for b in bounds)+8,max(b[3] for b in bounds)+8)
w=max(140,bbox[2]-bbox[0]);h=bbox[3]-bbox[1];w+=w%2;h+=h%2
def sheet(i):
    im=Image.new("RGB",(2*w,2*(h+22)),(25,31,38));d=ImageDraw.Draw(im)
    for j in range(4):
        x=j%2*w;y=j//2*(h+22);d.text((x+5,y+5),labels[j],fill="white")
        fg=lanes[j][i].crop(bbox);bg=Image.new("RGB",(w,h),(34,41,49));bg.paste(fg,((w-fg.width)//2,0),fg);im.paste(bg,(x,y+22))
    return im
frames=[sheet(i) for i in range(48)]
ds=[round((i+1)*100/60)*10-round(i*100/60)*10 for i in range(48)]
frames[0].save(root/"idle_comparison.gif",save_all=True,append_images=frames[1:],duration=ds,loop=0,disposal=2,optimize=False)
with Image.open(root/"idle_comparison.gif") as im:
    total=sum((im.seek(i) or im.info.get("duration",0)) for i in range(im.n_frames));assert total==800,total
for fps,name in [(60,"normal"),(30,"half")]:
    path=root/f"idle_{name}.mp4";W,H=frames[0].size
    p=subprocess.Popen(["ffmpeg","-y","-f","rawvideo","-pixel_format","rgb24","-video_size",f"{W}x{H}","-framerate",str(fps),"-i","-","-c:v","libx264","-pix_fmt","yuv420p","-movflags","+faststart",str(path)],stdin=subprocess.PIPE,stderr=subprocess.DEVNULL)
    for im in frames*3:p.stdin.write(im.tobytes())
    p.stdin.close();assert p.wait()==0
    stream=json.loads(subprocess.check_output(["ffprobe","-v","error","-select_streams","v:0","-show_entries","stream=nb_frames,duration","-of","json",str(path)]))["streams"][0]
    assert int(stream["nb_frames"])==144 and abs(float(stream["duration"])-144/fps)<.04
for i in [0,12,24,36,47]:sheet(i).save(root/f"phase_{i:02}.png")
print("verified 192 native PNGs; 800ms GIF; 144-frame MP4s")
