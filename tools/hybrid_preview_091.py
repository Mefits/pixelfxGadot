"""Compose the two native Godot RGBA captures; preserve measured world scroll."""
import argparse
import json
from pathlib import Path
from PIL import Image, ImageDraw

parser = argparse.ArgumentParser()
parser.add_argument("frames", type=Path)
parser.add_argument("out", type=Path)
args = parser.parse_args()
args.out.mkdir(parents=True, exist_ok=True)
rows = json.loads((args.frames / "capture.json").read_text())
frames = []
for tick, (old_x, new_x, events, stopped) in enumerate(rows):
    canvas = Image.new("RGB", (576, 256), "#34424d")
    draw = ImageDraw.Draw(canvas)
    for i, (prefix, x) in enumerate([("old", old_x), ("", new_x)]):
        origin = i * 288
        draw.line((origin, 211, origin + 287, 211), fill="#798d99")
        for offset in range(11):
            mark = origin + int((offset * 28 - 3*x) % 288)
            draw.line((mark, 212, mark, 217), fill="#798d99")
        with Image.open(args.frames / f"{prefix}{tick:03}.png") as actor:
            canvas.paste(actor, (origin, 16), actor)
    draw.line((287, 0, 287, 255), fill="#647783")
    draw.text((12, 6), "CONTROL   /   0.90 C + 0.82", fill="#d5dde1")
    draw.text((300, 6), "HYBRID   /   0.91", fill="#f3d998")
    phase = ("FAST WALK" if tick < 30 else "ACCELERATE" if tick < 55 else
             "SPRINT" if tick < 112 else "JAB" if tick < 137 else
             "CROSS" if tick < 160 else "GUARD" if stopped else "RECOVER")
    draw.text((12, 233), f"{tick:03} / 244     {phase}", fill="white")
    if 132 <= tick < 137 or 146 <= tick < 153:
        draw.text((300, 233), "CONTACT" if tick < 137 else "MISS", fill="#f3d998")
    frames.append(canvas)
for stride, speed, label in [(2, 1, "1x"), (1, .5, "half")]:
    selected = frames[::stride]
    # GIF centiseconds. Accumulated rounding keeps total clip time correct.
    edges = [round(min(i*stride,len(frames))*100/(60*speed)) for i in range(len(selected)+1)]
    times = [10*(b-a) for a,b in zip(edges, edges[1:])]
    selected[0].save(args.out / f"hybrid-091-{label}.gif", save_all=True,
                     append_images=selected[1:], duration=times, loop=0, optimize=True)
