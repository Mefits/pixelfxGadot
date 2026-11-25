"""Native frame capture and comparison packaging. No Python rendering of characters."""
import argparse,subprocess
from pathlib import Path
from PIL import Image,ImageDraw
ROOT=Path(__file__).resolve().parents[1]
def label(im,labels):
    result=Image.new("RGB",(im.width,im.height+27),"#142332")
    result.paste(im,(0,27))
    d=ImageDraw.Draw(result)
    for i,s in enumerate(labels):d.text((int(i*im.width/len(labels))+9,7),s,fill="white")
    return result
def gif(frames,path,rate):
    delays=[10*(round((i+1)*100/rate)-round(i*100/rate)) for i in range(len(frames))]
    frames[0].save(path,save_all=True,append_images=frames[1:],duration=delays,loop=0,disposal=2)
def main():
    p=argparse.ArgumentParser();p.add_argument("--godot",required=True);p.add_argument("--out",type=Path,required=True);p.add_argument("--xvfb",action="store_true");a=p.parse_args()
    out=a.out.resolve();out.mkdir(parents=True,exist_ok=False)
    cmd=(["xvfb-run","-a"] if a.xvfb else [])+[a.godot,"--path",str(ROOT/"godot"),"--audio-driver","Dummy","--disable-vsync","--script","res://tests/anatomy_rd.gd","--",str(out)]
    proc=subprocess.run(cmd,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=120);log=proc.stdout.decode("utf8","replace");(out/"engine.log").write_text(log)
    if proc.returncode or "ANATOMY_OK" not in log or "SCRIPT ERROR" in log:raise RuntimeError(log[-5000:])
    files=sorted(out.glob("[0-9][0-9][0-9].png"))
    assert len(files)==43
    imgs=[label(Image.open(f).convert("RGB"),["A - opposite IK bends","B - anatomical bends"]) for f in files]
    frames=[imgs[0]]*12+imgs+[imgs[-1]]*12
    gif(frames,out/"punch.gif",60);gif(frames,out/"punch-half.gif",30)
    label(Image.open(out/"stance.png").convert("RGB"),["Lab 0.43","A - old bend rules","B - new bend rules"]).save(out/"stance-review.png")
    skin_files=sorted(out.glob("skin_*.png"))
    assert len(skin_files)==43
    skins=[label(Image.open(f).convert("RGB"),["B - original skin","C - connected neck and hands"]) for f in skin_files]
    skin_frames=[skins[0]]*12+skins+[skins[-1]]*12
    gif(skin_frames,out/"skin.gif",60);gif(skin_frames,out/"skin-half.gif",30)
    single=[im.crop((im.width//2,27,im.width,im.height)) for im in skins]
    gif([single[0]]*12+single+[single[-1]]*12,out/"punch-clean.gif",60)
    gif([single[0]]*12+single+[single[-1]]*12,out/"punch-clean-half.gif",30)
    label(Image.open(out/"stance_skin.png").convert("RGB"),["Lab 0.43","B - corrected pose","C - same pose, new skin"]).save(out/"stance-skin-review.png")
    print(log)
if __name__=="__main__":main()
