"""Encode actual 60-tick Godot PNGs; no synthetic fallback."""
from pathlib import Path
import subprocess, sys
from PIL import Image
p=Path(sys.argv[1])
for id in ("energy_bolt", "energy_blade", "impact_dash"):
    for outcome in ("hit", "miss"):
        stem=f"{id}_{outcome}"
        frames=sorted(p.glob(stem+"-*.png"))
        assert len(frames)==120, (stem,len(frames))
        for speed, rate in (("1x",60),("half",30)):
            cmd=["ffmpeg","-hide_banner","-loglevel","error","-y","-framerate",str(rate),"-i",str(p/(stem+"-%03d.png"))]
            subprocess.run(cmd+["-vf","fps=60","-c:v","libx264","-pix_fmt","yuv420p",str(p/(stem+"-"+speed+".mp4"))],check=True)
        subprocess.run(["ffmpeg","-hide_banner","-loglevel","error","-y","-framerate","60","-i",str(p/(stem+"-%03d.png")),"-vf","fps=30,scale=640:-1:flags=neighbor,split[a][b];[a]palettegen[p];[b][p]paletteuse=dither=none",str(p/(stem+".gif"))],check=True)
        sheet=Image.new("RGB",(640*3,330*2))
        for j,t in enumerate((8,16,20,26,42,70)):
            with Image.open(frames[t]) as im:
                sheet.paste(im,(j%3*640,j//3*330))
        sheet.save(p/(stem+"-keys.png"))
