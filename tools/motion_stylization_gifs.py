"""Encode actual Godot captures; GIF centisecond timing alternates 20/10/20 ms."""
from pathlib import Path
from PIL import Image, ImageDraw
import sys, json, hashlib
root=Path(sys.argv[1])
modes=["A Original","B Godot","C PixelFX","D Body Smear","E Hybrid"]
report={}
for attack in ("punch","heel"):
    lanes=[]
    for mode in range(5):
        paths=sorted((root/"frames"/f"{attack}_{mode}").glob("*.png"))
        assert len(paths)==78,(attack,mode,len(paths))
        # Keep the body, target and fixed camera; remove tool panels.
        frames=[Image.open(p).convert("RGB").crop((335,145,650,535)) for p in paths]
        times=[20 if i%3!=1 else 10 for i in range(len(frames))]
        frames[0].save(root/f"{attack}_{mode}.gif",save_all=True,append_images=frames[1:],duration=times,loop=0,optimize=False,disposal=2)
        lanes.append(frames)
    sheet=[]
    diffs=[]
    for i in range(78):
        im=Image.new("RGB",(315*5,414),(29,38,48))
        d=ImageDraw.Draw(im)
        for j in range(5):
            d.text((j*315+8,5),modes[j],fill="white")
            im.paste(lanes[j][i],(j*315,24))
        sheet.append(im)
    for j in range(1,5):
        diffs.append(sum(a.tobytes()!=b.tobytes() for a,b in zip(lanes[0],lanes[j])))
    report[attack]={"changed_frames_vs_A":dict(zip(modes[1:],diffs))}
    assert all(diffs), (attack,diffs)
    sheet[0].save(root/f"{attack}_comparison.gif",save_all=True,append_images=sheet[1:],duration=[20 if i%3!=1 else 10 for i in range(78)],loop=0,optimize=False,disposal=2)
    best=max(range(78),key=lambda i:sum(lanes[0][i].tobytes()!=lanes[j][i].tobytes() for j in range(1,5)))
    sheet[best].save(root/f"{attack}_review.png")
(root/"metrics.json").write_text(json.dumps(report,indent=2))
print(report)
