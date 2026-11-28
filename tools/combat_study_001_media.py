from pathlib import Path
from PIL import Image,ImageDraw
import sys,json,subprocess
root=Path(sys.argv[1]);cases=["hit","block","miss","trade"]
lanes=[]
for name in cases:
    p=sorted(root.glob(name+"-*.png"));assert len(p)==72
    lanes.append([Image.open(x).convert("RGB") for x in p])
def sheet(i):
    im=Image.new("RGB",(960,444),(18,24,31));d=ImageDraw.Draw(im)
    for j,name in enumerate(cases):
        x=j%2*480;y=j//2*222
        d.text((x+8,y+4),name.upper()+"  |  tick "+str(i),fill="white")
        im.paste(lanes[j][i].resize((480,202),Image.Resampling.NEAREST),(x,y+20))
    return im
frames=[sheet(i) for i in range(72)]
ds=[round((i+1)*100/60)*10-round(i*100/60)*10 for i in range(72)]
frames[0].save(root/"comparison.gif",save_all=True,append_images=frames[1:],duration=ds,loop=0,disposal=2,optimize=False)
with Image.open(root/"comparison.gif") as im:
    assert sum((im.seek(i) or im.info.get("duration",0)) for i in range(im.n_frames))==1200
for fps,name in [(60,"normal"),(30,"half")]:
    p=subprocess.Popen(["ffmpeg","-y","-f","rawvideo","-pixel_format","rgb24","-video_size","960x444","-framerate",str(fps),"-i","-","-c:v","libx264","-pix_fmt","yuv420p","-movflags","+faststart",str(root/f"comparison_{name}.mp4")],stdin=subprocess.PIPE,stderr=subprocess.DEVNULL)
    for im in frames:p.stdin.write(im.tobytes())
    p.stdin.close();assert p.wait()==0
    s=json.loads(subprocess.check_output(["ffprobe","-v","error","-select_streams","v:0","-show_entries","stream=nb_frames,duration","-of","json",str(root/f"comparison_{name}.mp4")]))["streams"][0]
    assert int(s["nb_frames"])==72 and abs(float(s["duration"])-72/fps)<.04
sheet(28).save(root/"contact.png")
print("verified 288 native frames; 1200ms GIF; 72-frame MP4s")
