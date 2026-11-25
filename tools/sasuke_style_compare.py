import argparse,json,subprocess
from pathlib import Path
from PIL import Image,ImageDraw,ImageChops
from mocap_style import ROOT,run053a,gif
def main():
    p=argparse.ArgumentParser();p.add_argument("--godot",required=True);p.add_argument("--out",type=Path,required=True);a=p.parse_args()
    out=a.out.resolve();out.mkdir(parents=True,exist_ok=False)
    (out/"config.json").write_text(json.dumps(run053a()[2]["frames"]))
    cmd=["xvfb-run","-a",a.godot,"--path",str(ROOT/"godot"),"--audio-driver","Dummy","--disable-vsync","--script","res://tests/sasuke_style_compare.gd","--",str(out)]
    r=subprocess.run(cmd,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=100)
    log=r.stdout.decode("utf8","replace");(out/"engine.log").write_text(log);print(log)
    if r.returncode or "SASUKE055B_OK" not in log or "SCRIPT ERROR" in log:raise RuntimeError(log[-4000:])
    imgs=[Image.open(f).convert("RGB") for f in sorted(out.glob("[0-9][0-9][0-9].png"))]
    assert len(imgs)==37 and imgs[0].tobytes()==imgs[-1].tobytes()
    # Fixed crop across all frames, nearest enlargement of native capture.
    crop=(15,55,225,270)
    imgs=[im.crop(crop).resize((420,430),Image.Resampling.NEAREST) for im in imgs]
    gif(imgs[:-1:2],out/"comparison-1p1.gif",33);gif(imgs[:-1],out/"comparison-half.gif",30)
    sheet=Image.new("RGB",(840,456),"#142332");d=ImageDraw.Draw(sheet)
    for i,n in enumerate(["stand","guard","jab","kick"]):
        im=Image.open(out/(n+".png")).convert("RGB").crop(crop)
        sheet.paste(im,(i*210,25));d.text((i*210+8,8),n,fill="white")
        sheet.paste(im,(i*210,240))
    # Lower row gives six run exposures at 1x with no resampling.
    sheet=sheet.crop((0,0,840,240))
    sheet.resize((1680,480),Image.Resampling.NEAREST).save(out/"review.png")
    Image.open(out/"stand.png").convert("RGB").crop(crop).resize((420,430),Image.Resampling.NEAREST).save(out/"stand-review.png")
if __name__=="__main__":main()
