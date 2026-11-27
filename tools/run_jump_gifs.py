"""Compose two unmodified sequences rendered by Godot (60 ticks/s)."""
from pathlib import Path
import sys
from PIL import Image, ImageDraw

before, after, out = map(Path, sys.argv[1:])
out.mkdir(exist_ok=True, parents=True)
frames = []
for tick in range(72):
    canvas = Image.new("RGB", (620, 2 * 432), "#263542")
    draw = ImageDraw.Draw(canvas)
    for lane, (folder, label) in enumerate([(before, "v14"), (after, "Motion entry")]):
        top = 432 * lane
        draw.text((12, top + 5), f"{label}     tick {tick-16:+03d}", fill="white")
        if 16 <= tick < 22:
            draw.text((160, top + 5), "PUSH", fill="#ffcb76")
        draw.line((0, top + 415, 620, top + 415), fill="#738898")
        with Image.open(folder / f"{tick:03d}.png") as actor:
            canvas.paste(actor, (0, top + 25), actor)
    frames.append(canvas)
for name, stride in [("1x",2), ("half",1)]:
    selected = frames[::stride]
    durations = [10*(round((i+1)*10/3)-round(i*10/3)) for i in range(len(selected))]
    selected[0].save(out / f"run-jump-{name}.gif", save_all=True, append_images=selected[1:],
                     duration=durations, loop=0, disposal=1)
