"""Actual Godot frames. Mobile comparisons + verified 30 fps slow-motion MP4."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageChops
import sys,json,subprocess,shutil
root=Path(sys.argv[1])
modes=["A Original","B Godot control","C Seamless","D Surface accent","E Offset trail","F Multiples"]
report={}
def encode(frames,filename,slow=False):
    # At 0.5x each source tick lasts 33.33 ms. Use video instead of relying
    # on chat clients to interpret GIF per-frame delays.
    path=root/(filename+".mp4")
    w,h=frames[0].size
    w-=w%2;h-=h%2
    rate=30 if slow else 60
    exe=shutil.which("ffmpeg")
    assert exe,"ffmpeg missing"
    proc=subprocess.Popen([exe,"-y","-f","rawvideo","-pixel_format","rgb24","-video_size",f"{w}x{h}","-framerate",str(rate),"-i","-","-c:v","libx264","-pix_fmt","yuv420p","-movflags","+faststart","-crf","20",str(path)],stdin=subprocess.PIPE,stderr=subprocess.DEVNULL)
    for f in frames:proc.stdin.write(f.crop((0,0,w,h)).tobytes())
    proc.stdin.close()
    assert proc.wait()==0
    data=json.loads(subprocess.check_output(["ffprobe","-v","error","-select_streams","v:0","-show_entries","stream=nb_frames,duration","-of","json",str(path)]))["streams"][0]
    assert int(data["nb_frames"])==len(frames)
    assert abs(float(data["duration"])-len(frames)/rate)<.04
for attack in ("punch","heel"):
    lanes=[]
    for mode in range(6):
        paths=sorted((root/"frames"/f"{attack}_{mode}").glob("*.png"))
        assert len(paths)==78,(attack,mode,len(paths))
        frames=[Image.open(p).convert("RGB").crop((335,145,650,535)) for p in paths]
        lanes.append(frames)
        frames[0].save(root/f"{attack}_{mode}.gif",save_all=True,append_images=frames[1:],duration=[20 if i%3!=1 else 10 for i in range(78)],loop=0,optimize=False,disposal=2)
    # Pair original with each candidate, native size and mobile-first layout.
    counts={}
    for j in range(1,6):
        pixels=[sum(1 for rgb in ImageChops.difference(a,b).getdata() if rgb!=(0,0,0)) for a,b in zip(lanes[0],lanes[j])]
        counts[modes[j]]={"frames":sum(n>0 for n in pixels),"peak_pixels":max(pixels)}
        assert max(pixels)>0,(attack,j)
        frames=[]
        for i in range(78):
            im=Image.new("RGB",(630,414),(29,38,48))
            d=ImageDraw.Draw(im)
            d.text((8,5),modes[0],fill="white");d.text((323,5),modes[j],fill="white")
            im.paste(lanes[0][i],(0,24));im.paste(lanes[j][i],(315,24))
            frames.append(im)
        # Static peak panel is useful even if client fails to play animation.
        peak=max(range(78),key=lambda i:pixels[i])
        frames[peak].save(root/f"{attack}_A{j}_peak.png")
        if j in (2,3,4,5):encode(frames,f"{attack}_A{j}_half",True)
    for j in (3,4):
        pixels=[sum(1 for rgb in ImageChops.difference(a,b).getdata() if rgb!=(0,0,0)) for a,b in zip(lanes[2],lanes[j])]
        assert max(pixels)>0,(attack,"accent not visible",j)
        frames=[]
        for i in range(78):
            im=Image.new("RGB",(630,414),(29,38,48))
            d=ImageDraw.Draw(im)
            d.text((8,5),modes[2],fill="white");d.text((323,5),modes[j],fill="white")
            im.paste(lanes[2][i],(0,24));im.paste(lanes[j][i],(315,24))
            frames.append(im)
        frames[max(range(78),key=lambda i:pixels[i])].save(root/f"{attack}_C{j}_peak.png")
        encode(frames,f"{attack}_C{j}_half",True)
        counts["C vs "+modes[j]]={"frames":sum(n>0 for n in pixels),"peak_pixels":max(pixels)}
    report[attack]=counts
    sheet=[]
    for i in range(78):
        im=Image.new("RGB",(630,3*414),(29,38,48))
        d=ImageDraw.Draw(im)
        for j in range(6):
            x=(j%2)*315;y=(j//2)*414
            d.text((x+8,y+5),modes[j],fill="white")
            im.paste(lanes[j][i],(x,y+24))
        sheet.append(im)
    sheet[0].save(root/f"{attack}_mobile_1x.gif",save_all=True,append_images=sheet[1:],duration=[20 if i%3!=1 else 10 for i in range(78)],loop=0,optimize=False,disposal=2)
    encode(sheet,f"{attack}_mobile_half",True)
(root/"metrics.json").write_text(json.dumps(report,indent=2))
print(report)
