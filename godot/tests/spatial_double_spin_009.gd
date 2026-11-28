extends SceneTree
const L=preload("res://lab/spatial_lab/spatial_double_spin_kick_009.gd")
const Keys=preload("res://lab/spatial_lab/double_spin_keys_009.gd")
const Old=preload("res://lab/spatial_lab/spatial_roundhouse_008.gd")
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
var profile_metrics:Dictionary={}
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
func control(side:int)->void:
    var f=Training.new()
    var l=Old.new()
    l.coordination=3
    l.configure({"leg":side})
    check(l.begin(f),"008 control starts")
    for i in range(Keys.END+1):
        if i>0 and l.active:check(l.step().accepted,"008 control step")
        capture(body.make(l.player.rig,l.pose),"0-"+Support.SIDES[side]+"-%02d.png"%i,l.origin_x)

func exercise(mode:int,side:int,moving:bool)->void:
    var source=Training.new()
    if moving:
        for i in 20:source.step(1,true)
    var l=L.new()
    check(l.begin(source,side,mode==2),"009 starts")
    var label:String=str(mode)+"-"+Support.SIDES[side]+("-moving" if moving else "")
    var last_tip:Vector3=l.strike_tip()
    var last_hip:Vector3=l.player.rig.point3("hips")
    var last_yaw:int=l.player.rig.yaw_units
    var min_air:float=100.
    var peak_air:float=0.
    var max_floor:float=0.
    var max_hip_step:float=0.
    var max_local_tip:float=0.
    var max_local_yaw:int=0
    var restores:int=0
    var events:int=0
    var contacts:Array=[]
    for i in range(Keys.END+1):
        if i>0:
            var q:Dictionary=l.step()
            check(q.accepted,"accepted "+label+" "+str(i))
            if not q.accepted:return
        var rig=l.player.rig
        check(l.age==i and l.active==(i<Keys.END),"exact clock")
        for id in rig.ids_in_order():
            var par:String=rig.parent_id(id)
            check(rig.point3(id).is_finite(),"finite")
            if not par.is_empty():
                var e:float=absf(rig.point3(id).distance_to(rig.point3(par))-rig.rest_offset_xyz(id).length())
                max_bone=maxf(max_bone,e)
                check(e<.0001,"bone length")
        if l.contact_side>=0:
            var s:String=Support.SIDES[l.contact_side]
            var toe:Vector3=Support.toe(rig,l.pose,s)
            var e:float=toe.distance_to(l.anchor)
            max_anchor=maxf(max_anchor,e)
            check(e<Support.TOL,"support anchor")
            check(l.player.support.contacts.size()==1 and l.player.support.contacts.has(s),"single contact")
        else:check(l.player.support.contacts.is_empty(),"no airborne contacts")
        var low:float=maxf(Support.toe(rig,l.pose,"near").y,Support.toe(rig,l.pose,"far").y)
        if i>=Keys.TAKEOFF and i<Keys.LAND:
            check(l.contact_side<0,"authored flight")
            min_air=minf(min_air,l.ground_y-low)
            peak_air=maxf(peak_air,l.ground_y-low)
            check(l.ground_y-low>.15,"both toe references airborne")
        if i>=6:max_floor=maxf(max_floor,low-l.ground_y)
        if i==Keys.LAND:check(l.contact_side==side,"land on first support")
        if i==Keys.TRANSFER:check(l.contact_side==1-side,"transfer support")
        if i in [5,18,23,24,33,43,45,56]:
            var restored=L.new()
            restored.load_checkpoint(l.checkpoint())
            check(restored.checkpoint()==l.checkpoint(),"checkpoint exact")
            var next_ref=L.new()
            next_ref.load_checkpoint(l.checkpoint())
            check(restored.step()==next_ref.step() and restored.checkpoint()==next_ref.checkpoint(),"replay next tick")
            restores+=1
        var tip:Vector3=l.strike_tip()
        if i>0:
            max_local_tip=maxf(max_local_tip,tip.distance_to(last_tip))
            max_hip_step=maxf(max_hip_step,rig.point3("hips").distance_to(last_hip))
            max_local_yaw=maxi(max_local_yaw,absi(rig.yaw_units-last_yaw))
        if i==Keys.HIT:
            check(rig.yaw_units==l.direction*2*65536,"second turn at hit")
            check(tip.x>rig.point3("thigh_"+Support.SIDES[side]).x+4.,"forward strike")
        if l.fired and int(l.diagnostic.tick)==i:events+=1
        if contacts.is_empty() or contacts[-1][1]!=l.contact_side:contacts.append([i,l.contact_side])
        trace.append({"case":label,"tick":i,"yaw":rig.yaw_units,"tip":xyz(tip),"hip":xyz(rig.point3("hips")),"contact":l.contact_side,"toe_clearance":l.ground_y-low})
        if not moving:capture(body.make(rig,l.pose),label+"-%02d.png"%i,l.origin_x)
        last_tip=tip
        last_hip=rig.point3("hips")
        last_yaw=rig.yaw_units
        frames+=1
    check(l.player.rig.yaw_units==l.direction*2*65536,"signed double turn")
    check(l.air_frames>=7 and l.switches>=3,"flight and change of support")
    check(events==1 and l.fired and int(l.diagnostic.tick)>=43 and int(l.diagnostic.tick)<=46,"one diagnostic event")
    check(source.strikes==0 and source.hits==0,"source actor unchanged")
    check(not l.step().accepted,"no extra tick")
    profile_metrics[label]={"contact_schedule":contacts,"min_flight_clearance":min_air,"peak_flight_clearance":peak_air,"max_toe_penetration":max_floor,"max_hip_step":max_hip_step,"max_tip_step":max_local_tip,"max_yaw_step":max_local_yaw,"restores":restores,"diagnostic":l.diagnostic}
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
        control(side)
        for mode in [1,2]:
            exercise(mode,side,false)
            exercise(mode,side,true)
    check(count==8 and frames==488,"all cases")
    var report:Dictionary={"cases":count,"frames":frames,"max_bone_error":max_bone,"max_anchor_error":max_anchor,"profiles":profile_metrics,"failures":failures}
    for item in [["metrics.json",report],["trace.json",trace]]:
        var file:=FileAccess.open(out.path_join(item[0]),FileAccess.WRITE)
        file.store_string(JSON.stringify(item[1]))
        file.close()
    print("SPATIAL_DOUBLE_SPIN_009 ",JSON.stringify(report))
    quit(0 if failures.is_empty() else 1)
