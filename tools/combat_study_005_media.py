from pathlib import Path
from PIL import Image,ImageDraw
import sys,json,subprocess
root=Path(sys.argv[1]);cases=["parry","whiff","air_control","air_escape","active"]
labels=["Timed parry + counter","Whiff punish","Air route | no escape","Air route | escape","Active opponents | C"]
lanes={};hud={}
for name in cases:
    p=sorted(root.glob(f"{name}-*.png"));assert len(p)==180
    lanes[name]=[Image.open(x).convert("RGB").crop((110,0,530,315)) for x in p]
    hud[name]=json.loads((root/f"hud_{name}.json").read_text())
def sheet(i,names):
    cols=2 if len(names)>1 else 1;rows=(len(names)+cols-1)//cols
    im=Image.new("RGB",(420*cols,360*rows),(18,24,31));d=ImageDraw.Draw(im)
    for j,name in enumerate(names):
        x=j%cols*420;y=j//cols*360;v=hud[name][i]
        d.text((x+6,y+5),labels[cases.index(name)]+f"  HP {v['hp'][0]}:{v['hp'][1]}",fill="white")
        im.paste(lanes[name][i],(x,y+20))
        d.text((x+6,y+338),f"{v['action'][0] or 'idle'} / {v['action'][1] or 'idle'} | stun {v['stun']} | escape {v['escapes']} | parry {v['parries']}",fill="white")
    return im
def encode(names,prefix):
    frames=[sheet(i,names) for i in range(180)]
    ds=[round((i+1)*100/60)*10-round(i*100/60)*10 for i in range(180)]
    frames[0].save(root/f"{prefix}.gif",save_all=True,append_images=frames[1:],duration=ds,loop=0,disposal=2,optimize=False)
    with Image.open(root/f"{prefix}.gif") as im:
        assert sum((im.seek(i) or im.info.get("duration",0)) for i in range(im.n_frames))==3000
    for fps,name in [(60,"normal"),(30,"half")]:
        p=subprocess.Popen(["ffmpeg","-y","-f","rawvideo","-pixel_format","rgb24","-video_size",f"{frames[0].width}x{frames[0].height}","-framerate",str(fps),"-i","-","-c:v","libx264","-pix_fmt","yuv420p","-movflags","+faststart",str(root/f"{prefix}_{name}.mp4")],stdin=subprocess.PIPE,stderr=subprocess.DEVNULL)
        for im in frames:p.stdin.write(im.tobytes())
        p.stdin.close();assert p.wait()==0
        s=json.loads(subprocess.check_output(["ffprobe","-v","error","-select_streams","v:0","-show_entries","stream=nb_frames,duration","-of","json",str(root/f"{prefix}_{name}.mp4")]))["streams"][0]
        assert int(s["nb_frames"])==180 and abs(float(s["duration"])-180/fps)<.04
encode(cases[:4],"comparison")
encode(["active"],"active")
for t in [28,31,35,40,50,60,100]:sheet(t,cases[:4]).save(root/f"phase_{t:03}.png")
print("verified 900 native PNGs; 3000ms GIFs; 180-frame MP4s")
