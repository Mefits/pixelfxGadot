"""Encode the actual native body images read from the Godot workshop."""
import argparse
import json
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

parser = argparse.ArgumentParser()
parser.add_argument("frames", type=Path)
parser.add_argument("out", type=Path)
args = parser.parse_args()
args.out.mkdir(parents=True, exist_ok=True)
rows = json.loads((args.frames / "rows.json").read_text())
font = ImageFont.truetype("DejaVuSans.ttf", 14)
labels = {"DRAG": "ПЕРЕТАСКИВАНИЕ КИСТИ", "sprint": "БЕГ · ЦЕЛЬ В ФАЗЕ ПЕРЕНОСА",
          "jab": "ДЖЕБ · ПРАВКА В КОНТАКТЕ", "feint": "ФИНТ · 4 АВТОРСКИЕ ПОЗЫ"}
frames = []
for i, row in enumerate(rows):
    canvas = Image.new("RGB", (560, 264), "#263440")
    draw = ImageDraw.Draw(canvas)
    for lane, name in enumerate(["a", "b"]):
        x = 280 * lane
        with Image.open(args.frames / f"{name}{i:04}.png") as img:
            actor = img.crop((100, 20, 380, 250))
            canvas.paste(actor, (x, 12), actor)
        draw.line((x, 212, x+279, 212), fill="#6c8290")
        for j in range(11):
            mark = x + int((j*26-row["travel"][lane]*3) % 280)
            draw.line((mark, 213, mark, 217), fill="#73878c")
    draw.line((280, 0, 280, 230), fill="#536974")
    draw.text((10, 6), "Исходное движение", font=font, fill="#dce5eb")
    draw.text((291, 6), "Мастерская", font=font, fill="#e9ca86")
    if row["stage"] == "DRAG":
        tx, ty = row["target"]
        x, y = 420+3*tx, 211+3*ty
        draw.line((x-5,y,x+5,y),fill="#fb936c",width=2)
        draw.line((x,y-5,x,y+5),fill="#fb936c",width=2)
    draw.text((10, 237), labels[row["stage"]], font=font, fill="#f2dbaa")
    draw.text((491,237), f"{row['tick']:03d}", font=font, fill="#d8e4eb")
    frames.append(canvas)
for speed, stride, label in [(1,2,"1x"), (.5,1,"half")]:
    sequence=frames[::stride]
    edges=[round(min(i*stride,len(frames))*100/(60*speed)) for i in range(len(sequence)+1)]
    sequence[0].save(args.out / f"motion-workshop-{label}.gif", save_all=True,
                     append_images=sequence[1:],loop=0,
                     duration=[10*(b-a) for a,b in zip(edges,edges[1:])])
