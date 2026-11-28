extends "res://lab/aura_study_001/view.gd"
const Hand=preload("hand.gd")
var hand_fx=Hand.new()
var native_aura
var last_root_x:float=0.
var vx:float=0.
var primed:bool=false
var active_pixels:int=0
var floor_clean:bool=true

func _init():
    super()
    if ClassDB.class_exists("PixelFXAuraRaster"):native_aura=ClassDB.instantiate("PixelFXAuraRaster")

func reset()->void:
    super.reset()
    primed=false
    vx=0.
    hand_fx.build(Vector2.ZERO,Vector2.ZERO,1.,-1,0)
    active_pixels=0
    floor_clean=true

func render(w)->Image:
    var started:int=Time.get_ticks_usec()
    var out:=Image.create(Aura.WIDTH*SCALE,Aura.HEIGHT*SCALE,false,Image.FORMAT_RGBA8)
    out.fill(Color("#24313d"))
    out.fill_rect(Rect2i(0,FLOOR,out.get_width(),2),Color("#83949c"))
    var source:Image
    var source_pos:=Vector2i.ZERO
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
        if i==owner:
            source=im
            source_pos=pos
    body_us=Time.get_ticks_usec()-started
    started=Time.get_ticks_usec()
    if mode>0:
        if native_aura==null or source==null:return null
        var offset:=Vector2(float(ORIGIN_X)/SCALE,float(FLOOR)/SCALE)
        var hip:Vector2=w.point(owner,"hips")+offset
        if not primed:
            last_root_x=hip.x
            primed=true
        vx=lerpf(vx,hip.x-last_root_x,.28)
        last_root_x=hip.x
        var action:String=w.actors[owner].action
        var side:String="far" if action=="cross" else "near"
        var age:int=w.players[owner].age if action in ["cross","jab"] else -1
        var wrist:Vector2=w.tip(owner,"hand_"+side)+offset
        var elbow:Vector2=w.point(owner,"elbow_"+side)+offset
        hand_fx.build(elbow,wrist,w.facing(owner),age,mode)
        var cfg:=PackedFloat64Array([Aura.WIDTH,Aura.HEIGHT,SCALE,source.get_width(),source.get_height(),source_pos.x,source_pos.y,float(FLOOR)/SCALE,hip.x,w.facing(owner),w.tick,vx,2.3,.085 if mode==1 else .17])
        var result:Array=native_aura.render(out.get_data(),source.get_data(),hand_fx.seed.color,hand_fx.detail.color,cfg)
        if result.size()!=3:return null
        out=Image.create_from_data(out.get_width(),out.get_height(),false,Image.FORMAT_RGBA8,result[0])
        # Diagnostic counts intentionally outside timed path.
        aura_us=Time.get_ticks_usec()-started
        var ink:PackedInt32Array=result[1]
        var light:PackedInt32Array=result[2]
        active_pixels=0
        for y in range(int(FLOOR/SCALE),Aura.HEIGHT):
            for x in Aura.WIDTH:
                var at:int=y*Aura.WIDTH+x
                if ink[at]!=0 or light[at]!=0:floor_clean=false
        if hand_fx.growth>0.:
            for x in hand_fx.seed.color:
                if x!=0:active_pixels+=1
    else:
        aura_us=Time.get_ticks_usec()-started
    return out
