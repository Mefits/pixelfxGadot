"""Native Godot preview: current Lab and original PixelFX pose raster."""
import argparse, json, subprocess
from pathlib import Path
from PIL import Image, ImageDraw
from mocap_style import run053a, gif, ROOT
def main():
    p=argparse.ArgumentParser();p.add_argument("--godot",required=True);p.add_argument("--out",type=Path,required=True);a=p.parse_args()
    out=a.out.resolve();out.mkdir(parents=True,exist_ok=False)
    # C cadence of 0.53a, unchanged. Both lanes see the exact same sample clock.
    (out/"config.json").write_text(json.dumps(run053a()[2]["frames"]))
    cmd=["xvfb-run","-a","-s","-screen 0 1280x768x24",a.godot,"--path",str(ROOT/"godot"),"--audio-driver","Dummy","--disable-vsync","--script","res://tests/pixelfx_body_compare.gd","--",str(out)]
    r=subprocess.run(cmd,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=100)
    log=r.stdout.decode("utf8","replace");(out/"engine.log").write_text(log);print(log)
    if r.returncode or "PIXELFX_BODY_COMPARE_OK" not in log or "SCRIPT ERROR" in log:raise RuntimeError(log[-4000:])
    imgs=[]
    for f in sorted(out.glob("[0-9][0-9][0-9].png")):
        src=Image.open(f).convert("RGB");im=Image.new("RGB",(520,255),"#142332");im.paste(src,(0,25))
        d=ImageDraw.Draw(im);d.text((10,7),"A / Lab 0.53a C",fill="white");d.text((270,7),"B / original PixelFX",fill="white")
        imgs.append(im)
    assert len(imgs)==37 and imgs[0].tobytes()==imgs[-1].tobytes()
    gif(imgs[:-1:2],out/"comparison-1p1.gif",33);gif(imgs[:-1],out/"comparison-half.gif",30)
    sheet=Image.new("RGB",(520,255*6),"#142332")
    for i,t in enumerate(range(0,36,6)):sheet.paste(imgs[t],(0,255*i))
    sheet.save(out/"review.png")
if __name__=="__main__":main()
