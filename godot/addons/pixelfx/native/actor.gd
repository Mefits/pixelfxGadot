extends RefCounted
## Stock actor masks and palettes from PixelFX core/actor.js, MIT Patch/Hugo Duprez.
const PAL=preload("res://addons/pixelfx/native/palette.gd")
const HERO=["....kkkkk...","..kkhhhhhk..",".khhhhhhhhk.",".khhhhhhhhhk",".khhssssshhk",".khsessesshk",".khsessesshk","..ksssssssk.","...kkSSSkk..","..kttttttk..",".kttTttTttk.",".ksttTTttsk.",".kstttttttk.","..kbbbbbbk..","..kppkkppk..","..kppk.kppk.","..kppk.kppk.","..koook.kook","..kkkkk.kkkk"]
const HERO2=["...........kkk..........","..........kAABk.........",".........kAAABJk........",".........kABBJJk........",".........kBBBJCDk.......",".........kBCJDDDk.......",".........kkJJJDk........",".......kkkkABBJCkk......","......kAABCJBCCCkDk.....","......kABBCJCCCmDkDk....","......kBBCDDJCDDDkDk....","......kABCDJDDDDDkk.....",".....kAABDkDDDDJkk......",".....kABCDkDDJJGkk......",".....kABCkJJJGGGkk......","....kJJCDkFFFGGGk.......","....kAJJDkJJJGGGk.......","....kJCJJkABBJGGk.......",".....kJCCkBBCDJJJk......",".....kCCCJBBCDJJDk......",".....kCCCDJCCDkJDDk.....","......kCDDJBCDkDDDk.....",".......kDJJJCDkDDDkk....",".......kJBCJCDkDDDkk....",".......kBDJBCDkCDDkk....","........kJJBCDkCDDk.....","........kBBBCDkCCDDk....","........kBBBCDkCCDDk....",".........kBBCDkJDDDk....","........kBJJJJkCJJJk....","........kBBCCDkCCDDk....","........kBBCDDkCDDk.....","........kBBCDkCCDDk.....","........kBCCDkCCDDk.....","........kBCDDkCDDDk.....",".......kJBCJkkkDJkkkk...",".......kAJJAAAAkCCCCCk..","........kkkkkkkkkkkkk..."]
const HERO_PAL={"k":"#17121f","h":"#7a4128","s":"#f3c49d","S":"#c98b6c","e":"#17121f","t":"#5f6f94","T":"#46536f","b":"#8a5a32","p":"#38334a","o":"#6a4030","H":"#a35d34","w":"#ffffff","m":"#a3564a","g":"#e8c060","L":"#7f90b6","O":"#8f5a3f","P":"#4b4560","c":"#f53cd1","C":"#ff8fe6","D":"#a31f8a"}
const DUMMY_PAL={"k":"#0e0c14","A":"#e4e6ec","B":"#b6b9c3","C":"#868995","D":"#5c5e6a","E":"#6e707c","F":"#4b4d58","G":"#34353f","J":"#2a2b33","m":"#f53cd1"}

static func from_rows(rows: Array,palette: Dictionary,anchor: Vector2i,k: int=1) -> Dictionary:
    if rows.is_empty():
        return {}
    var w: int=rows[0].length()
    var h: int=rows.size()
    var data:=PackedByteArray()
    var pixels:=PackedInt64Array()
    data.resize(w*h)
    pixels.resize(w*h)
    for y in range(h):
        for x in range(mini(w,rows[y].length())):
            var ch: String=rows[y][x]
            if ch==".":
                continue
            data[y*w+x]=1
            var c: Variant=palette.get(ch,0)
            pixels[y*w+x]=PAL.from_hex(c) if c is String else int(c)
    return {"mask":{"w":w,"h":h,"data":data},"pixels":pixels,"x":anchor.x,"y":anchor.y,"w":w,"h":h,"k":k,"head":[0,anchor.y],"chest":[0,-26 if k==2 else anchor.y+11]}

static func stock(k: int=1) -> Dictionary:
    var a: Dictionary=from_rows(HERO2 if k==2 else HERO,DUMMY_PAL if k==2 else HERO_PAL,Vector2i(-12,-38) if k==2 else Vector2i(-6,-19),2 if k==2 else 1)
    if k==2:
        a["eyes"]=[[13,3],[15,3]]
    return a

static func draw_stock(p,actor: Dictionary,a: float=1) -> void:
    if a>0:
        var k: int=actor.get("k",1)
        p.sprite(HERO2 if k==2 else HERO,DUMMY_PAL if k==2 else HERO_PAL,actor["x"],actor["y"],{"a":a})

static func from_image(img: Image,anchor: Vector2i,threshold: float=.5) -> Dictionary:
    # Godot-specific adapter for custom character silhouettes. Not the upstream rig.
    var w: int=img.get_width()
    var h: int=img.get_height()
    var data:=PackedByteArray()
    var pixels:=PackedInt64Array()
    data.resize(w*h)
    pixels.resize(w*h)
    for y in range(h):
        for x in range(w):
            var c: Color=img.get_pixel(x,y)
            if c.a<threshold:
                continue
            data[y*w+x]=1
            pixels[y*w+x]=PAL.rgb(c.r8,c.g8,c.b8)
    return {"mask":{"w":w,"h":h,"data":data},"pixels":pixels,"x":anchor.x,"y":anchor.y,"w":w,"h":h,"k":1,"head":[0,anchor.y],"chest":[0,anchor.y+h*.35]}
