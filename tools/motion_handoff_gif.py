"""Encode actual Godot H handoff frames at normal and half speed."""
from pathlib import Path
import sys,json
from PIL import Image
out=Path(sys.argv[1])
report=json.loads((out/"handoff-report.json").read_text())
paths=sorted(out.glob("frame-*.png"))
assert len(paths)==report["frames"] and len(paths)>60
frames=[Image.open(p).convert("RGB") for p in paths]
for stride,suffix in ((2,"1x"),(1,"half")):
    selected=frames[::stride]
    ends=[round((i+1)*100/30)*10 for i in range(len(selected))]
    durations=[b-a for a,b in zip([0]+ends[:-1],ends)]
    path=out/("handoff-"+suffix+".gif")
    selected[0].save(path,save_all=True,append_images=selected[1:],duration=durations,loop=0,disposal=1)
    with Image.open(path) as gif:
        total=0
        for i in range(gif.n_frames):
            gif.seek(i)
            total+=gif.info["duration"]
        assert total==ends[-1]
print("HANDOFF_GIF_OK",len(frames))
