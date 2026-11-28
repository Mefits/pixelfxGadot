"""Real Godot frame comparison, fixed crop, source timing and aligned phases."""
from pathlib import Path
from PIL import Image,ImageDraw
import sys,json,subprocess
root=Path(sys.argv[1])
labels=["A 011 C control","B stronger pose","C staged spin"]
lanes=[];bounds=[]
for mode in (1,2,3):
    paths=sorted(root.glob(f"{mode}-near-*.png"));assert len(paths)==108
    ims=[Image.open(p).convert("RGBA") for p in paths]
    for im in ims:
        b=im.getchannel("A").getbbox();assert b and b[0]>0 and b[1]>0 and b[2]<im.width and b[3]<im.height
        bounds.append(b)
    lanes.append(ims)
bbox=(min(b[0] for b in bounds)-8,min(b[1] for b in bounds)-8,max(b[2] for b in bounds)+8,max(b[3] for b in bounds)+8)
w=max(145,bbox[2]-bbox[0]);h=bbox[3]-bbox[1];w+=w%2;h+=h%2
def sheet(ticks,phase):
    im=Image.new("RGB",(3*w,h+40),(25,31,38));d=ImageDraw.Draw(im)
    for j,i in enumerate(ticks):
        x=j*w;d.text((x+4,5),labels[j],fill="white")
        fg=lanes[j][i].crop(bbox);bg=Image.new("RGB",(w,h),(34,41,49));bg.paste(fg,((w-fg.width)//2,0),fg);im.paste(bg,(x,22))
    d.text((4,h+25),phase,fill="white")
    return im
frames=[sheet([i]*3,f"60 Hz | tick {i}") for i in range(108)]
ds=[round((i+1)*100/60)*10-round(i*100/60)*10 for i in range(108)]
frames[0].save(root/"comparison.gif",save_all=True,append_images=frames[1:],duration=ds,loop=0,disposal=2,optimize=False)
with Image.open(root/"comparison.gif") as im:
    total=sum((im.seek(i) or im.info.get("duration",0)) for i in range(im.n_frames));assert total==1800,total
for fps,name in [(60,"normal"),(30,"half")]:
    path=root/f"comparison_{name}.mp4";W,H=frames[0].size
    p=subprocess.Popen(["ffmpeg","-y","-f","rawvideo","-pixel_format","rgb24","-video_size",f"{W}x{H}","-framerate",str(fps),"-i","-","-c:v","libx264","-pix_fmt","yuv420p","-movflags","+faststart",str(path)],stdin=subprocess.PIPE,stderr=subprocess.DEVNULL)
    for im in frames:p.stdin.write(im.tobytes())
    p.stdin.close();assert p.wait()==0
    st=json.loads(subprocess.check_output(["ffprobe","-v","error","-select_streams","v:0","-show_entries","stream=nb_frames,duration","-of","json",str(path)]))["streams"][0]
    assert int(st["nb_frames"])==108 and abs(float(st["duration"])-108/fps)<.04
for name,ticks in [("idle",[11]*3),("chamber",[28,28,30]),("impact",[31,31,34]),("retract",[35,35,39]),("recovery",[72,72,78]),("end",[107]*3)]:
    sheet(ticks,name).save(root/f"phase_{name}.png")
print("verified 324 native PNGs, 1800ms GIF and 108-frame MP4s")
