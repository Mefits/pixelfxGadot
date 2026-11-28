from pathlib import Path
from PIL import Image,ImageDraw
import sys,json,subprocess
root=Path(sys.argv[1]);labels=["A  Linear","B  Branching","C  Situational"]
lanes=[];hud=[]
for m in range(3):
    p=sorted(root.glob(f"{m}-*.png"));assert len(p)==126
    lanes.append([Image.open(x).convert("RGB").crop((160,0,480,250)) for x in p])
    hud.append(json.loads((root/f"hud_{m}.json").read_text()))
def sheet(i):
    im=Image.new("RGB",(960,300),(18,24,31));d=ImageDraw.Draw(im)
    for j in range(3):
        x=j*320;v=hud[j][i]
        d.text((x+7,5),labels[j]+f"   HP {v['hp'][0]}:{v['hp'][1]}",fill="white")
        im.paste(lanes[j][i],(x,20))
        d.text((x+7,272),f"{v['action'] or 'idle'} | lock {v['remaining']} | stun {v['stun']} | cancels {v['links']}",fill="white")
        d.text((x+7,286),f"tick {i} | freeze {v['freeze']} | buffer {v['buffer'] or '-'}",fill="white")
    return im
frames=[sheet(i) for i in range(126)]
ds=[round((i+1)*100/60)*10-round(i*100/60)*10 for i in range(126)]
frames[0].save(root/"comparison.gif",save_all=True,append_images=frames[1:],duration=ds,loop=0,disposal=2,optimize=False)
with Image.open(root/"comparison.gif") as im:
    assert sum((im.seek(i) or im.info.get("duration",0)) for i in range(im.n_frames))==2100
for fps,name in [(60,"normal"),(30,"half")]:
    p=subprocess.Popen(["ffmpeg","-y","-f","rawvideo","-pixel_format","rgb24","-video_size","960x300","-framerate",str(fps),"-i","-","-c:v","libx264","-pix_fmt","yuv420p","-movflags","+faststart",str(root/f"comparison_{name}.mp4")],stdin=subprocess.PIPE,stderr=subprocess.DEVNULL)
    for im in frames:p.stdin.write(im.tobytes())
    p.stdin.close();assert p.wait()==0
    s=json.loads(subprocess.check_output(["ffprobe","-v","error","-select_streams","v:0","-show_entries","stream=nb_frames,duration","-of","json",str(root/f"comparison_{name}.mp4")]))["streams"][0]
    assert int(s["nb_frames"])==126 and abs(float(s["duration"])-126/fps)<.04
for t in [28,32,47,53,66,90]:sheet(t).save(root/f"phase_{t:03}.png")
print("verified 378 native PNGs; 2100ms GIF; 126-frame MP4s")
