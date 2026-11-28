from pathlib import Path
import subprocess,sys,json
from PIL import Image
p=Path(sys.argv[1])
m=json.loads((p/"metrics.json").read_text())
for stem in ("legacy_cloak","native_cloak","fist","palm"):
    frames=sorted(p.glob(stem+"-???.png"))
    assert len(frames)==180,(stem,len(frames))
    for name,rate in (("1x",60),("half",30)):
        subprocess.run(["ffmpeg","-hide_banner","-loglevel","error","-y","-framerate",str(rate),"-i",str(p/(stem+"-%03d.png")),"-vf","fps=60","-c:v","libx264","-pix_fmt","yuv420p",str(p/(stem+"-"+name+".mp4"))],check=True)
    subprocess.run(["ffmpeg","-hide_banner","-loglevel","error","-y","-framerate","60","-i",str(p/(stem+"-%03d.png")),"-vf","fps=30,split[a][b];[a]palettegen[p];[b][p]paletteuse=dither=none",str(p/(stem+".gif"))],check=True)
    sheet=Image.new("RGB",(792*3,360*2))
    for j,t in enumerate((50,54,59,64,72,90)):
        with Image.open(frames[t]) as im:sheet.paste(im,(j%3*792,j//3*360))
    sheet.save(p/(stem+"-keys.png"))
