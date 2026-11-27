"""Mobile-first comparisons directly from actual Godot screenshots."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageChops
import sys,json
root=Path(sys.argv[1])
modes=["A Original","B Godot trail","C PixelFX trail","D Body smear","E Hybrid","F Impact accent"]
report={}
for attack in ("punch","heel"):
    lanes=[]
    for mode in range(6):
        paths=sorted((root/"frames"/f"{attack}_{mode}").glob("*.png"))
        assert len(paths)==78,(attack,mode,len(paths))
        frames=[Image.open(p).convert("RGB").crop((335,145,650,535)) for p in paths]
        times=[20 if i%3!=1 else 10 for i in range(len(frames))]
        frames[0].save(root/f"{attack}_{mode}.gif",save_all=True,append_images=frames[1:],duration=times,loop=0,optimize=False,disposal=2)
        lanes.append(frames)
    sheet=[]
    diffs=[]
    pixels=[]
    for i in range(78):
        im=Image.new("RGB",(630,3*414),(29,38,48))
        d=ImageDraw.Draw(im)
        for j in range(6):
            x=(j%2)*315;y=(j//2)*414
            d.text((x+8,y+5),modes[j],fill="white")
            im.paste(lanes[j][i],(x,y+24))
        sheet.append(im)
    for j in range(1,6):
        counts=[sum(1 for rgb in ImageChops.difference(a,b).getdata() if rgb!=(0,0,0)) for a,b in zip(lanes[0],lanes[j])]
        diffs.append(sum(n>0 for n in counts))
        pixels.append(max(counts))
    report[attack]={"changed_frames_vs_A":dict(zip(modes[1:],diffs)),"max_changed_pixels":dict(zip(modes[1:],pixels))}
    assert all(diffs), (attack,diffs)
    for suffix,mult in (("1x",1),("half",2)):
        sheet[0].save(root/f"{attack}_mobile_{suffix}.gif",save_all=True,append_images=sheet[1:],duration=[mult*(20 if i%3!=1 else 10) for i in range(78)],loop=0,optimize=False,disposal=2)
    best=max(range(78),key=lambda i:sum(lanes[0][i].tobytes()!=lanes[j][i].tobytes() for j in range(1,6)))
    sheet[best].save(root/f"{attack}_review.png")
(root/"metrics.json").write_text(json.dumps(report,indent=2))
print(report)
