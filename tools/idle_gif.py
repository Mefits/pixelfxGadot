from PIL import Image
from pathlib import Path
frames=[Image.open(p).convert("RGBA") for p in sorted(Path("frames").glob("*.png"))]
assert len(frames)==72,len(frames)
boxes=[f.getbbox() for f in frames]
assert all(boxes)
x0=min(b[0] for b in boxes)-12
y0=min(b[1] for b in boxes)-12
x1=max(b[2] for b in boxes)+12
y1=max(b[3] for b in boxes)+12
images=[]
for f in frames:
    cut=f.crop((x0,y0,x1,y1))
    bg=Image.new("RGBA",cut.size,(52,66,77,255))
    bg.alpha_composite(cut)
    images.append(bg.convert("RGB").resize((cut.width*2,cut.height*2),Image.Resampling.NEAREST))
print("UNIQUE_RASTER_FRAMES",len(set(f.tobytes() for f in images)))
out=Path("preview")
out.mkdir(exist_ok=True)
# GIF uses centisecond durations. Alternate 30/40 ms to preserve 2.4 s.
for name,ms in [("idle-1x.gif",[30,30,40]*24),("idle-half.gif",[70,70,60]*24)]:
    images[0].save(out/name,save_all=True,append_images=images[1:],duration=ms,loop=0,disposal=2,optimize=False)
print("IDLE_GIF_OK")
