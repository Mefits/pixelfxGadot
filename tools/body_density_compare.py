import argparse,json,subprocess
from pathlib import Path
from PIL import Image,ImageDraw
from mocap_style import ROOT,run053a,gif
def main():
    p=argparse.ArgumentParser();p.add_argument("--godot",required=True);p.add_argument("--out",type=Path,required=True);a=p.parse_args()
    out=a.out.resolve();out.mkdir(parents=True,exist_ok=False)
    (out/"config.json").write_text(json.dumps(run053a()[2]["frames"]))
    cmd=["xvfb-run","-a",a.godot,"--path",str(ROOT/"godot"),"--audio-driver","Dummy","--disable-vsync","--script","res://tests/body_density_compare.gd","--",str(out)]
    r=subprocess.run(cmd,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=100)
    log=r.stdout.decode("utf8","replace");(out/"engine.log").write_text(log);print(log)
    if r.returncode or "BODY_DENSITY054D_OK" not in log or "SCRIPT ERROR" in log:raise RuntimeError(log[-4000:])
    imgs=[]
    for f in sorted(out.glob("[0-9][0-9][0-9].png")):
        src=Image.open(f).convert("RGB");im=Image.new("RGB",(960,313),"#142332");im.paste(src,(0,25))
        d=ImageDraw.Draw(im)
        for j,label in enumerate(["A / 1x, ink 1px","B / 2x, ink 2px","C / 3x, ink 3px","D / 4x, ink 4px"]):d.text((j*240+10,7),label,fill="white")
        imgs.append(im)
    assert len(imgs)==37 and imgs[0].tobytes()==imgs[-1].tobytes()
    gif(imgs[:-1:2],out/"comparison-1p1.gif",33);gif(imgs[:-1],out/"comparison-half.gif",30)
    sheet=Image.new("RGB",(960,313*6),"#142332")
    for i,t in enumerate(range(0,36,6)):sheet.paste(imgs[t],(0,313*i))
    sheet.save(out/"review.png")
if __name__=="__main__":main()
