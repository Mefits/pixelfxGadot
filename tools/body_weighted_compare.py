import argparse,json,subprocess
from pathlib import Path
from PIL import Image,ImageDraw
from mocap_style import ROOT,run053a,gif
def main():
    p=argparse.ArgumentParser();p.add_argument("--godot",required=True);p.add_argument("--out",type=Path,required=True);a=p.parse_args()
    out=a.out.resolve();out.mkdir(parents=True,exist_ok=False)
    (out/"config.json").write_text(json.dumps(run053a()[2]["frames"]))
    r=subprocess.run(["xvfb-run","-a",a.godot,"--path",str(ROOT/"godot"),"--audio-driver","Dummy","--disable-vsync","--script","res://tests/body_weighted_compare.gd","--",str(out)],stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=100)
    log=r.stdout.decode("utf8","replace");(out/"engine.log").write_text(log);print(log)
    if r.returncode or "BODY_WEIGHTED057_OK" not in log or "SCRIPT ERROR" in log:raise RuntimeError(log[-4000:])
    def label(src):
        im=Image.new("RGB",(864,313),"#142332");im.paste(src,(0,25));d=ImageDraw.Draw(im)
        for j,n in enumerate(["A / 056 strips","B / weighted","C / joint correction"]):d.text((288*j+8,7),n,fill="white")
        return im
    imgs=[label(Image.open(f).convert("RGB")) for f in sorted(out.glob("[0-9][0-9][0-9].png"))]
    assert len(imgs)==37 and imgs[0].tobytes()==imgs[-1].tobytes()
    gif(imgs[:-1:2],out/"comparison-1p1.gif",33);gif(imgs[:-1],out/"comparison-half.gif",30)
    sheet=Image.new("RGB",(864,313*4),"#142332")
    for i,n in enumerate(["stand","guard","jab","kick"]):sheet.paste(label(Image.open(out/(n+".png")).convert("RGB")),(0,i*313))
    sheet.save(out/"review.png")
    stand=Image.open(out/"stand.png").convert("RGB")
    im=Image.new("RGB",(540,456),"#142332");d=ImageDraw.Draw(im)
    for i,n in enumerate(["A / 056","B / weighted","C / corrected"]):
        im.paste(stand.crop((i*288+99,75,i*288+189,288)).resize((180,426),Image.Resampling.NEAREST),(180*i,30))
        d.text((180*i+8,8),n,fill="white")
    im.save(out/"stand-review.png")
if __name__=="__main__":main()
