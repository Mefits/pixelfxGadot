extends SceneTree
const L=preload("res://lab/spatial_lab/spatial_roundhouse.gd")
const FK=preload("res://lab/spatial_lab/spatial_fk.gd")
const Support=preload("res://lab/spatial_lab/spatial_support.gd")
const Training=preload("res://lab/training_control.gd")
const SpatialBody=preload("res://lab/spatial_lab/spatial_body.gd")
const Body=preload("res://lab/body_ankle_069.gd")
const Depth=preload("res://lab/arm_depth_090.gd")
const CFG={"width":480,"height":270,"origin":[240,219],"density":3,"ink":0xff000000,"outline":3,"light":[-.48,-.64,.6],"seams":false,"materials":[[0xffe6ded7,0xffbdb3a8,0xff9e9081,0xff746759],[0xffa09d74,0xff827d50,0xff656139,0xff4a4628],[0xff655a4c,0xff50473b,0xff3c342c,0xff29231e],[0xff7278e2,0xff4c53bb,0xff35398b,0xff27265c]]}
var failures:Array[String]=[]
var max_bone:float=0.
var max_anchor:float=0.
var max_yaw_step:int=0
var max_tip_step:float=0.
var max_hit_xy_delta:float=0.
var max_orbit:float=0.
var count:int=0
var frames:int=0
var trace:Array=[]
var outcomes:Array=[]
var raster
var body=SpatialBody.new()
var legacy_body=Body.new(2)
var out:String
func _initialize()->void:call_deferred("run")
func check(ok:bool,msg:String)->void:
    if not ok and not failures.has(msg):failures.append(msg)
func xyz(v:Vector3)->Array:return [v.x,v.y,v.z]
func capture(parts:Array,name:String,origin_x:float)->void:
    var cfg:Dictionary=CFG.duplicate(true)
    cfg.origin[0]-=origin_x*float(cfg.density)
    var q:Dictionary=raster.render(cfg,parts)
    check(q.get("ok",false),"native render "+str(q.get("error","")))
    if not q.get("ok",false):return
    var im:=Image.create_from_data(q.width,q.height,false,Image.FORMAT_RGBA8,q.rgba)
    var b:Rect2i=im.get_used_rect()
    check(b.position.x>0 and b.position.y>0 and b.end.x<480 and b.end.y<270,"unclipped "+name)
    check(im.save_png(out.path_join(name))==OK,"save")
func exercise(side:int,settings:Dictionary,visual:bool,moving:bool=false)->void:
    var f=Training.new()
    var reference=Training.new()
    if moving:
        for i in 20:
            f.step(1,true)
            reference.step(1,true)
    var l=L.new()
    settings=settings.duplicate(true)
    settings.leg=side
    l.configure(settings)
    reference.round_kick.configure(settings)
    check(reference.press_round_kick(),"legacy starts")
    check(l.begin(f),"spatial starts")
    check(l.striking==side and l.support_leg==1-side,"anatomical side")
    check(l.end_tick==reference.round_kick.end_tick and l.hit_tick==reference.round_kick.hit_tick and l.contact_start==reference.round_kick.contact_start() and l.contact_end==reference.round_kick.contact_end(),"timing exact")
    check(l.player.current.yaw==0 and l.age==0,"entry clock")
    var frozen:Dictionary=l.tuning.duplicate(true)
    var last_tip:Vector3=l.strike_tip()
    var last_yaw:int=l.player.rig.yaw_units
    var events:int=0
    var label:String=Support.SIDES[side]+("-moving" if moving else ("-default" if visual else "-tuned"))
    for i in range(l.end_tick+1):
        if i>0:
            if i==3:l.configure({"leg":1-side,"prep_ticks":20,"strike_ticks":8})
            reference.step(0)
            var q:Dictionary=l.step()
            check(q.accepted,"accepted "+label+" tick "+str(i))
            if not q.accepted:return
            check(l.age==i and l.active==(i<l.end_tick),"exact tick and release")
            check(l.tuning==frozen,"frozen tuning")
        var rig=l.player.rig
        var tip:Vector3=l.strike_tip()
        var old_tip:Vector2=reference.round_kick.strike_tip(reference.walker)
        check(Vector2(l.frames[i].legacy_tip).distance_to(old_tip)<.00001,"independent legacy source exact")
        var s:String=Support.SIDES[side]
        check(tip.distance_to(rig.point3("knee_"+s).lerp(rig.point3("foot_"+s),.9))<.000001,"distal shin actual")
        for id in rig.ids_in_order():
            var par:String=rig.parent_id(id)
            if not par.is_empty():
                var e:float=absf(rig.point3(id).distance_to(rig.point3(par))-rig.rest_offset_xyz(id).length())
                max_bone=maxf(max_bone,e)
                check(e<.0001,"bone length")
            check(rig.point3(id).is_finite(),"finite joints")
        if l.planted:
            var toe:Vector3=Support.toe(rig,l.pose,Support.SIDES[l.support_leg])
            var e:float=toe.distance_to(l.anchor_xyz)
            max_anchor=maxf(max_anchor,e)
            check(e<Support.TOL,"support anchored")
        if i>0:
            max_yaw_step=maxi(max_yaw_step,absi(rig.yaw_units-last_yaw))
            max_tip_step=maxf(max_tip_step,tip.distance_to(last_tip))
        if i==l.hit_tick:
            max_hit_xy_delta=maxf(max_hit_xy_delta,Vector2(tip.x,tip.y).distance_to(old_tip))
            check(rig.yaw_units==0,"impact aligned yaw")
        if l.fired and int(l.diagnostic.tick)==i:events+=1
        trace.append({"case":label,"tick":i,"yaw":rig.yaw_units,"tip":xyz(tip),"legacy_tip":[old_tip.x,old_tip.y],"anchor":xyz(l.anchor_xyz),"support_toe":xyz(Support.toe(rig,l.pose,Support.SIDES[l.support_leg])),"planted":l.planted})
        if visual:
            capture(body.make(rig,l.pose),label+"-spatial-%02d.png"%i,l.origin_x)
            var old=Body.make_rig()
            var p:Dictionary=l.frames[i].pose
            old.evaluate(p)
            var parts:Array=legacy_body.make(old.points,p.angles,old.rotations.head)
            Depth.apply(parts,0.)
            SpatialBody.materials(parts)
            capture(parts,label+"-legacy-%02d.png"%i,l.origin_x)
        last_tip=tip
        last_yaw=rig.yaw_units
        frames+=1
    check(l.player.rig.yaw_units==l.direction*65536,"signed full turn")
    check(events==1 and l.fired and int(l.diagnostic.tick)>=l.contact_start and int(l.diagnostic.tick)<=l.contact_end,"one diagnostic contact within window")
    check(reference.strikes==1 and f.strikes==reference.strikes and f.hits==reference.hits,"legacy authority unchanged")
    check(not l.step().accepted,"no extra tick")
    outcomes.append({"case":label,"end":l.end_tick,"hit_tick":l.hit_tick,"window":[l.contact_start,l.contact_end],"diagnostic_tick":l.diagnostic.get("tick",-1),"diagnostic_hit":l.diagnostic.get("hit",false),"legacy_hit":reference.hits==1,"plant_tick":l.plant_tick})
    max_orbit=maxf(max_orbit,l.max_root_orbit)
    count+=1
func run()->void:
    var args:=OS.get_cmdline_user_args()
    if args.size()!=1 or not ClassDB.class_exists("PixelFXBodyRaster"):
        push_error("native PixelFX and output required")
        quit(2)
        return
    out=args[0]
    DirAccess.make_dir_recursive_absolute(out)
    raster=ClassDB.instantiate("PixelFXBodyRaster")
    for side in 2:
        exercise(side,{},true)
        exercise(side,{"prep_ticks":8,"strike_ticks":4,"return_ticks":15,"recovery_ticks":12,"reach_scale":.9},false)
        exercise(side,{},false,true)
    check(count==6 and frames==228,"all default and tuned cases")
    var report:Dictionary={"cases":count,"frames":frames,"max_bone_error":max_bone,"max_anchor_error":max_anchor,"max_yaw_step_units":max_yaw_step,"max_tip_step":max_tip_step,"max_hit_xy_delta":max_hit_xy_delta,"max_root_orbit":max_orbit,"outcomes":outcomes,"failures":failures}
    for item in [["metrics.json",report],["trace.json",trace]]:
        var file:=FileAccess.open(out.path_join(item[0]),FileAccess.WRITE)
        file.store_string(JSON.stringify(item[1]))
        file.close()
    print("SPATIAL_L_005 ",JSON.stringify(report))
    quit(0 if failures.is_empty() else 1)
