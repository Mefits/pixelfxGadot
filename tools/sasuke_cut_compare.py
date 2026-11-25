import argparse,subprocess
from pathlib import Path
from PIL import Image,ImageDraw
ROOT=Path(__file__).resolve().parent.parent
def main():
    p=argparse.ArgumentParser();p.add_argument("--godot",required=True);p.add_argument("--out",type=Path,required=True);a=p.parse_args()
    out=a.out.resolve();out.mkdir(parents=True,exist_ok=False)
    cmd=["xvfb-run","-a",a.godot,"--path",str(ROOT/"godot"),"--audio-driver","Dummy","--disable-vsync","--script","res://tests/sasuke_cut_compare.gd","--",str(out)]
    r=subprocess.run(cmd,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=100)
    log=r.stdout.decode("utf8","replace");(out/"engine.log").write_text(log);print(log)
    if r.returncode or "SASUKE_CUT055C_OK" not in log or "SCRIPT ERROR" in log:raise RuntimeError(log[-4000:])
    im=Image.open(out/"native.png").convert("RGB")
    assert im.size==(960,288)
    sheet=Image.new("RGB",(720,456),"#142332");d=ImageDraw.Draw(sheet)
    for i,n in enumerate(["OLD / 055b","A / straight legs","B / cut cloth","C / flat profile"]):
        crop=im.crop((i*240+75,75,i*240+165,288))
        sheet.paste(crop.resize((180,426),Image.Resampling.NEAREST),(180*i,30))
        d.text((180*i+8,10),n,fill="white")
    sheet.save(out/"review.png")
if __name__=="__main__":main()
