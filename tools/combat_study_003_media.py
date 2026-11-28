from pathlib import Path
from PIL import Image,ImageDraw
import sys,json,subprocess
root=Path(sys.argv[1]);cases=["pulse","dash","launch","route"]
labels=["Pulse | mid range","Dash | close distance","Launch | lift","Mixed route | C"]
lanes=[];hud=[]
for name in cases:
    p=sorted(root.glob(f"{name}-*.png"));assert len(p)==120
    lanes.append([Image.open(x).convert("RGB").crop((125,0,515,250)) for x in p])
    hud.append(json.loads((root/f"hud_{name}.json").read_text()))
def sheet(i):
    im=Image.new("RGB",(780,584),(18,24,31));d=ImageDraw.Draw(im)
    for j,name in enumerate(cases):
        x=j%2*390;y=j//2*292;v=hud[j][i]
        d.text((x+6,y+5),labels[j]+f"   HP {v['hp'][0]}:{v['hp'][1]}",fill="white")
        im.paste(lanes[j][i],(x,y+20))
        d.text((x+6,y+273),f"{v['action'] or 'idle'} | gap {v['gap']:.1f} | lift {v['height']:.1f} | stun {v['stun']}",fill="white")
    return im
frames=[sheet(i) for i in range(120)]
ds=[round((i+1)*100/60)*10-round(i*100/60)*10 for i in range(120)]
frames[0].save(root/"comparison.gif",save_all=True,append_images=frames[1:],duration=ds,loop=0,disposal=2,optimize=False)
with Image.open(root/"comparison.gif") as im:
    assert sum((im.seek(i) or im.info.get("duration",0)) for i in range(im.n_frames))==2000
for fps,name in [(60,"normal"),(30,"half")]:
    p=subprocess.Popen(["ffmpeg","-y","-f","rawvideo","-pixel_format","rgb24","-video_size","780x584","-framerate",str(fps),"-i","-","-c:v","libx264","-pix_fmt","yuv420p","-movflags","+faststart",str(root/f"comparison_{name}.mp4")],stdin=subprocess.PIPE,stderr=subprocess.DEVNULL)
    for im in frames:p.stdin.write(im.tobytes())
    p.stdin.close();assert p.wait()==0
    s=json.loads(subprocess.check_output(["ffprobe","-v","error","-select_streams","v:0","-show_entries","stream=nb_frames,duration","-of","json",str(root/f"comparison_{name}.mp4")]))["streams"][0]
    assert int(s["nb_frames"])==120 and abs(float(s["duration"])-120/fps)<.04
for t in [17,22,30,38,56,78]:sheet(t).save(root/f"phase_{t:03}.png")
print("verified 480 native PNGs; 2000ms GIF; 120-frame MP4s")
