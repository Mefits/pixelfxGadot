from pathlib import Path
import subprocess,sys,json
from PIL import Image
p=Path(sys.argv[1])
m=json.loads((p/"metrics.json").read_text())
for name in ("sharp","balanced","heavy"):
    for outcome in ("hit","miss"):
        stem=f"{name}_{outcome}"
        frames=sorted(p.glob(stem+"-???.png"))
        assert len(frames)==115,(stem,len(frames))
        for speed,rate in (("1x",60),("half",30)):
            subprocess.run(["ffmpeg","-hide_banner","-loglevel","error","-y","-framerate",str(rate),"-i",str(p/(stem+"-%03d.png")),"-vf","fps=60","-c:v","libx264","-pix_fmt","yuv420p",str(p/(stem+"-"+speed+".mp4"))],check=True)
        subprocess.run(["ffmpeg","-hide_banner","-loglevel","error","-y","-framerate","60","-i",str(p/(stem+"-%03d.png")),"-vf","fps=30,split[a][b];[a]palettegen[p];[b][p]paletteuse=dither=none",str(p/(stem+".gif"))],check=True)
        hit=m[name][outcome]["hit_tick"]
        t=hit if hit>=0 else 12+int({"sharp":6,"balanced":10,"heavy":15}[name])
        sheet=Image.new("RGB",(792*3,360*2))
        for j,k in enumerate((12,max(0,t-2),t,t+8,t+20,t+38)):
            with Image.open(frames[min(k,114)]) as im:sheet.paste(im,(j%3*792,j//3*360))
        sheet.save(p/(stem+"-keys.png"))
