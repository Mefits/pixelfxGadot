from pathlib import Path
import sys
from PIL import Image
p=Path(sys.argv[1])
frames=[Image.open(f).convert("RGB") for f in sorted(p.glob("frame-*.png"))]
assert len(frames)>0, "no native frames"
for step,name in [(2,"comparison-1x.gif"),(1,"comparison-half.gif")]:
    selected=frames[::step]
    ends=[round((i+1)*100/30)*10 for i in range(len(selected))]
    delays=[b-a for a,b in zip([0]+ends,ends)]
    dest=p/name
    selected[0].save(dest,save_all=True,append_images=selected[1:],duration=delays,loop=0,disposal=1)
    with Image.open(dest) as im:
        total=0
        for i in range(im.n_frames):
            im.seek(i)
            total+=im.info["duration"]
        assert total==ends[-1], (name,total,ends[-1])
w,h=frames[0].size
samples=[0,15,25,35,45,60,90,120,150,len(frames)-1]
samples=sorted(set(min(len(frames)-1,k) for k in samples))
sheet=Image.new("RGB",(w,h*len(samples)))
for j,k in enumerate(samples):sheet.paste(frames[k],(0,j*h))
sheet.save(p/"review.png")
print("NATIVE_GIF_OK",len(frames))
