extends RefCounted
const Studio=preload("res://lab/hybrid_studio.gd")
const Body=preload("res://lab/body_ankle_069.gd")
const Depth=preload("res://lab/arm_depth_090.gd")
var raster
var body=Body.new(2)

func _init():
    if ClassDB.class_exists("PixelFXBodyRaster"):raster=ClassDB.instantiate("PixelFXBodyRaster")

func render(w)->Image:
    var out:=Image.create(640,270,false,Image.FORMAT_RGBA8)
    out.fill(Color("#24313d"))
    out.fill_rect(Rect2i(0,219,640,2),Color("#83949c"))
    var mid:float=(w.root_x(0)+w.root_x(1))*.5
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
        var x:int=roundi(320.+(w.root_x(i)-mid)*3.)-ox
        out.blend_rect(im,Rect2i(0,0,im.get_width(),im.get_height()),Vector2i(x,0))
    return out
