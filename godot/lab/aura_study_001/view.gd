extends RefCounted
const Studio=preload("res://lab/hybrid_studio.gd")
const Body=preload("res://lab/body_ankle_069.gd")
const Depth=preload("res://lab/arm_depth_090.gd")
const Aura=preload("aura.gd")
var raster
var body=Body.new(2)
var aura=Aura.new()
var mode:int=2
var owner:int=0
var aura_us:int=0
var body_us:int=0
const SCALE:int=3
const ORIGIN_X:int=396
const FLOOR:int=300

func _init():
    if ClassDB.class_exists("PixelFXBodyRaster"):raster=ClassDB.instantiate("PixelFXBodyRaster")

func reset()->void:aura.reset()

func render(w)->Image:
    var started:int=Time.get_ticks_usec()
    var out:=Image.create(Aura.WIDTH*SCALE,Aura.HEIGHT*SCALE,false,Image.FORMAT_RGBA8)
    out.fill(Color("#24313d"))
    out.fill_rect(Rect2i(0,FLOOR,out.get_width(),2),Color("#83949c"))
    # Fixed camera, unchanged scale; start gap 84 art px instead of 26–32.
    var mask:=PackedByteArray()
    mask.resize(Aura.COUNT)
    for i in 2:
        var p=w.players[i]
        var parts:Array=body.make(p.rig.points,p.final_pose.angles,p.rig.rotations.head)
        Depth.apply(parts,p.style)
        for k in [0,2,3,8,9]:parts[k].material_id=1 if i==0 else 3
        for k in [5,6,7,11,12,13,15,17]:parts[k].material_id=2
        var q:Dictionary=raster.render(Studio.CFG,parts)
        if not q.get("ok",false):return null
        var im:=Image.create_from_data(q.width,q.height,false,Image.FORMAT_RGBA8,q.rgba)
        var ox:int=240
        if i==1:
            im.flip_x()
            ox=239
        var pos:=Vector2i(ORIGIN_X+roundi(w.root_x(i)*SCALE)-ox,FLOOR-219+roundi(float(w.actors[i].y)*SCALE))
        out.blend_rect(im,Rect2i(0,0,im.get_width(),im.get_height()),pos)
        if i==owner and mode>0:
            # Sample exact alpha mask of the native rendered body on the art grid.
            var x0:int=maxi(0,floori(float(pos.x)/SCALE))
            var y0:int=maxi(0,floori(float(pos.y)/SCALE))
            var x1:int=mini(Aura.WIDTH,ceili(float(pos.x+im.get_width())/SCALE))
            var y1:int=mini(Aura.HEIGHT,ceili(float(pos.y+im.get_height())/SCALE))
            for y in range(y0,y1):
                for x in range(x0,x1):
                    var sx:int=x*SCALE+1-pos.x
                    var sy:int=y*SCALE+1-pos.y
                    if sx>=0 and sy>=0 and sx<im.get_width() and sy<im.get_height() and im.get_pixel(sx,sy).a>.25:mask[y*Aura.WIDTH+x]=1
    body_us=Time.get_ticks_usec()-started
    started=Time.get_ticks_usec()
    if mode>0:
        var hip:Vector2=w.point(owner,"hips")+Vector2(float(ORIGIN_X)/SCALE,float(FLOOR)/SCALE)
        aura.field(mask,hip,w.facing(owner),w.tick,mode)
        var rgb:=Image.create_from_data(Aura.WIDTH,Aura.HEIGHT,false,Image.FORMAT_RGBA8,aura.ink.rgba_bytes())
        rgb.resize(out.get_width(),out.get_height(),Image.INTERPOLATE_NEAREST)
        out.blend_rect(rgb,Rect2i(0,0,out.get_width(),out.get_height()),Vector2i.ZERO)
        for y in Aura.HEIGHT:
            for x in Aura.WIDTH:
                var value:int=aura.ink.light[y*Aura.WIDTH+x]
                if value==0:continue
                var light:=Color(float(value&255)/255.,float((value>>8)&255)/255.,float((value>>16)&255)/255.)
                for dy in SCALE:
                    for dx in SCALE:
                        var px:int=x*SCALE+dx
                        var py:int=y*SCALE+dy
                        var c:Color=out.get_pixel(px,py)
                        out.set_pixel(px,py,Color(minf(1.,c.r+light.r),minf(1.,c.g+light.g),minf(1.,c.b+light.b),1.))
    aura_us=Time.get_ticks_usec()-started
    return out
