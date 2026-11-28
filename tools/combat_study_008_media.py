from pathlib import Path
from PIL import Image,ImageDraw
import sys,json,subprocess
root=Path(sys.argv[1])
groups=[("recovery",["recovery_0","recovery_1","recovery_2"],120),("approach",["approach_0","approach_1","approach_2"],120),("duels",["duel_0","duel_1","duel_2"],360)]
titles={c:f"{['A Control','B Faster recovery','C Recovery + mobility'][int(c[-1])]}" for _,cases,_ in groups for c in cases}
def encode(prefix,cases,n):
    hud={c:json.loads((root/f"hud_{c}.json").read_text()) for c in cases}
    paths={c:sorted(root.glob(f"{c}-*.png")) for c in cases}
    assert all(len(p)==n for p in paths.values())
    latest={c:[] for c in cases}
    frames=[]
    # Stack long duels vertically for mobile. No simulation in Python:
    # original Godot pixels plus labels from the exact same ticks.
    cols=2 if len(cases)==2 else 1
    rows=(len(cases)+cols-1)//cols
    for i in range(n):
        im=Image.new("RGB",(480*cols,332*rows),(18,24,31));d=ImageDraw.Draw(im)
        for j,c in enumerate(cases):
            x=j%cols*480;y=j//cols*332;v=hud[c][i]
            with Image.open(paths[c][i]) as p:im.paste(p.convert("RGB"),(x,y+22))
            d.text((x+8,y+4),f"{titles[c]} | tick {v['tick']} | gap {v['gap']:.1f}",fill="white")
            a,b=v["sides"]
            d.text((x+8,y+294),f"P1 {a['hp']}HP {a['action'] or '-'} {a['phase']} {a['left']}  /  P2 {b['hp']}HP {b['action'] or '-'} {b['phase']} {b['left']}",fill="white")
            if v["events"]:latest[c]=v["events"]
            event="  ".join(f"{e['attack']}:{e['result']} d={e['distance']:.1f} @{e['tick']}" for e in latest[c])
            d.text((x+8,y+310),f"freeze {v['freeze']} | last: {event}",fill="#f2d499")
        frames.append(im)
        if i in [28,40,50,100]:im.save(root/f"{prefix}_phase_{i:03}.png")
    ds=[round((i+1)*100/60)*10-round(i*100/60)*10 for i in range(n)]
    frames[0].save(root/f"{prefix}.gif",save_all=True,append_images=frames[1:],duration=ds,loop=0,disposal=2,optimize=False)
    with Image.open(root/f"{prefix}.gif") as im:assert sum((im.seek(i) or im.info.get("duration",0)) for i in range(im.n_frames))==round(n*1000/60)
    for fps,kind in [(60,"normal"),(30,"half")]:
        dst=root/f"{prefix}_{kind}.mp4"
        p=subprocess.Popen(["ffmpeg","-y","-f","rawvideo","-pixel_format","rgb24","-video_size",f"{frames[0].width}x{frames[0].height}","-framerate",str(fps),"-i","-","-c:v","libx264","-pix_fmt","yuv420p","-movflags","+faststart",str(dst)],stdin=subprocess.PIPE,stderr=subprocess.DEVNULL)
        for im in frames:p.stdin.write(im.tobytes())
        p.stdin.close();assert p.wait()==0
        s=json.loads(subprocess.check_output(["ffprobe","-v","error","-select_streams","v:0","-show_entries","stream=nb_frames,duration","-of","json",str(dst)]))["streams"][0]
        assert int(s["nb_frames"])==n and abs(float(s["duration"])-n/fps)<.04
    print(f"verified {prefix}: {n} ticks, {n/60:g}s, {n*len(cases)} Godot PNGs")
for args in groups:encode(*args)
