extends SceneTree
const FK=preload("res://lab/spatial_lab/spatial_fk.gd")
const Entry=preload("res://lab/spatial_lab/spatial_motion_entry.gd")
const Transition=preload("res://lab/spatial_lab/spatial_transition.gd")
const Support=preload("res://lab/spatial_lab/spatial_support.gd")
const Training=preload("res://lab/training_control.gd")
const SpatialBody=preload("res://lab/spatial_lab/spatial_body.gd")
const CFG={"width":480,"height":270,"origin":[240,219],"density":3,"ink":0xff000000,"outline":3,"light":[-.48,-.64,.6],"seams":false,"materials":[[0xffe6ded7,0xffbdb3a8,0xff9e9081,0xff746759],[0xffa09d74,0xff827d50,0xff656139,0xff4a4628],[0xff655a4c,0xff50473b,0xff3c342c,0xff29231e],[0xff7278e2,0xff4c53bb,0xff35398b,0xff27265c]]}
var failures:Array[String]=[]
var max_length:float=0.
var max_entry:float=0.
var max_endpoint:float=0.
var max_step:float=0.
var max_yaw_step:int=0
var max_velocity_error:float=0.
var max_anchor:float=0.
var max_entry_basis:float=0.
var max_raw_jump:float=0.
var switches:int=0
var frames:int=0
var rejected:int=0
var trace:Array=[]
var raster
var body=SpatialBody.new()
var out:String
func _initialize()->void:call_deferred("run")
func check(ok:bool,msg:String)->void:
    if not ok and not failures.has(msg):failures.append(msg)
func sample(pose:Dictionary,yaw:int,z:float=0.,twist:int=0)->Dictionary:
    var r=FK.new()
    r.evaluate_spatial(pose,yaw,z,twist,0,{},true)
    return Entry.sample(r,pose)
func distance(a:Dictionary,b:Dictionary)->float:
    var e:float=0.
    for id in a.xyz:e=maxf(e,Vector3(a.xyz[id]).distance_to(b.xyz[id]))
    return e
func basis_diff(a:Dictionary,b:Dictionary)->float:
    var e:float=0.
    for id in a.basis:
        var x:Basis=a.basis[id]
        var y:Basis=b.basis[id]
        e=maxf(e,maxf(x.x.distance_to(y.x),maxf(x.y.distance_to(y.y),x.z.distance_to(y.z))))
    return e
func geometry(r)->void:
    for id in r.ids_in_order():
        var parent:String=r.parent_id(id)
        if not parent.is_empty():
            var e:float=absf(r.point3(parent).distance_to(r.point3(id))-r.rest_offset_xyz(id).length())
            max_length=maxf(max_length,e)
            check(e<.0001,"bone lengths")
        var p:Vector3=r.point3(id)
        check(p.is_finite() and r.point(id)==Vector2(p.x,p.y),"projection finite")
        var b:Basis=r.joint_basis[id]
        check(b.is_finite() and absf(b.determinant()-1.)<.0001,"basis proper")
func capture(r,pose:Dictionary,name:String)->void:
    var q:Dictionary=raster.render(CFG,body.make(r,pose))
    check(q.get("ok",false),"native render "+str(q.get("error","")))
    if not q.get("ok",false):return
    var im:=Image.create_from_data(q.width,q.height,false,Image.FORMAT_RGBA8,q.rgba)
    var b:Rect2i=im.get_used_rect()
    check(b.position.x>0 and b.position.y>0 and b.end.x<480 and b.end.y<270,"unclipped")
    check(im.save_png(out.path_join(name))==OK,"capture")
func xyz(v:Vector3)->Array:return [v.x,v.y,v.z]
func measure(t,before:Dictionary,prior:Dictionary,was_entry:bool,target:Dictionary,label:String,tick:int)->void:
    var after:Dictionary=t.current
    geometry(t.rig)
    if was_entry:
        var gap:float=distance(before,after)
        max_entry=maxf(max_entry,gap)
        max_entry_basis=maxf(max_entry_basis,basis_diff(before,after))
        max_raw_jump=maxf(max_raw_jump,distance(before,target))
        check(gap==0. and basis_diff(before,after)==0. and before.yaw==after.yaw,"exact interrupted entry")
        switches+=1
    else:
        max_step=maxf(max_step,distance(before,after))
        max_yaw_step=maxi(max_yaw_step,absi(int(after.yaw)-int(before.yaw)))
        for id in after.xyz:
            var step:Vector3=Vector3(after.xyz[id])-Vector3(before.xyz[id])
            var v:Vector3=Vector3(before.xyz[id])-Vector3(prior.xyz[id])
            max_velocity_error=maxf(max_velocity_error,step.distance_to(v))
    frames+=1
    trace.append({"case":label,"tick":tick,"entry":was_entry,"yaw":after.yaw,"hips":xyz(after.root),"near_toe":xyz(after.toes.near),"far_toe":xyz(after.toes.far)})
func free_probe(pose:Dictionary,start:int,direction:int,visual:bool)->void:
    var r=FK.new()
    var p:Dictionary=pose.duplicate(true)
    p.angles["shoulder_near"]+=8.
    r.evaluate_spatial(p,start,1.,0,0,{},true)
    var t=Transition.new()
    t.seed(r,p,sample(pose,start-direction*900,.5))
    var label:String="%d-%d"%[start,direction]
    var target_pose:Dictionary=pose.duplicate(true)
    target_pose.angles["shoulder_near"]-=25.
    target_pose.angles["thigh_far"]-=12.
    target_pose.root[0]+=2.
    t.command(8)
    for i in 5:
        var goal:Dictionary=sample(target_pose,start+direction*(8000+i*700),2.,1200)
        var before:Dictionary=t.current.duplicate(true)
        var prior:Dictionary=t.previous.duplicate(true)
        var result:Dictionary=t.step(goal)
        check(result.accepted,"free transition")
        if not result.accepted:return
        measure(t,before,prior,i==0,goal,label,i)
        if visual:capture(t.rig,result.pose,"transition-%02d.png"%i)
    # Cancel to a reversed trajectory mid-transition, never reset to guard.
    t.command(8)
    for i in 9:
        var goal:Dictionary=sample(pose,start-direction*(4000+i*500),-.5)
        var before:Dictionary=t.current.duplicate(true)
        var prior:Dictionary=t.previous.duplicate(true)
        var result:Dictionary=t.step(goal)
        check(result.accepted,"cancel transition")
        if not result.accepted:return
        measure(t,before,prior,i==0,goal,label,5+i)
        if i==8:
            max_endpoint=maxf(max_endpoint,distance(t.current,goal))
            check(distance(t.current,goal)==0. and t.current.yaw==goal.yaw,"exact free destination")
        if visual:capture(t.rig,result.pose,"transition-%02d.png"%(5+i))
func support_probe(pose:Dictionary,side:String)->void:
    var r=FK.new()
    var p:Dictionary=pose.duplicate(true)
    p.root[1]+=1.5
    var free:String="far" if side=="near" else "near"
    p.angles["thigh_"+free]=-65.
    p.angles["knee_"+free]=95.
    r.lift_legacy(p,32768)
    var s=Support.new()
    s.capture(r,p,side,Support.PIVOT)
    check(s.resolve(r,p,32768).accepted,"seed support")
    var t=Transition.new()
    t.seed(r,p,{},s)
    var anchor:Vector3=t.support.contacts[side].anchor
    t.command(8)
    for i in 16:
        if i==5:t.command(8)
        var local:int=i if i<5 else i-5
        var yaw:int=32768+i*1100 if i<5 else 38000-(i-5)*800
        var goal:Dictionary=sample(p,yaw)
        var before:Dictionary=t.current.duplicate(true)
        var prior:Dictionary=t.previous.duplicate(true)
        var result:Dictionary=t.step(goal)
        check(result.accepted,"supported transition")
        if not result.accepted:return
        measure(t,before,prior,local==0,goal,side,i)
        var err:float=Support.toe(t.rig,result.pose,side).distance_to(anchor)
        max_anchor=maxf(max_anchor,err)
        check(err<Support.TOL,"carried contact anchor")
        capture(t.rig,result.pose,side+"-support-%02d.png"%i)
    var before:Dictionary=t.current.duplicate(true)
    var age:int=t.age
    var bad:Dictionary=p.duplicate(true)
    bad.root[0]+=100.
    var result:Dictionary=t.step(sample(bad,32768),0.)
    check(not result.accepted and t.age==age and t.current==before,"rejected target transactional")
    if not result.accepted:rejected+=1
    t.contact(side,Support.FREE)
    t.command(8)
    check(t.step(sample(p,32768)).accepted,"release transition entry")
    check(t.support.contacts.is_empty(),"explicit release")
func legacy_probe(pose:Dictionary)->void:
    var r=FK.new()
    var s=Support.new()
    r.lift_legacy(pose,65536)
    var g:Dictionary=Entry.legacy_gate(r,pose,s)
    check(g.allowed,"aligned canonical fallback")
    r.lift_legacy(pose,32768)
    check(not Entry.legacy_gate(r,pose,s).allowed,"half turn fallback denied")
    r.evaluate_spatial(pose,65536,2.,0,0,{},true)
    check(not Entry.legacy_gate(r,pose,s).allowed,"root depth fallback denied")
    r.lift_legacy(pose,0)
    s.capture(r,pose,"near",Support.FIXED)
    check(not Entry.legacy_gate(r,pose,s).allowed,"contact fallback denied")
func tiny_rotation_probe()->void:
    for axis in [Vector3.RIGHT,Vector3.UP,Vector3.BACK,Vector3(1,2,3).normalized()]:
        for angle in [.000001,.00001,.0001,.001,.01,.1]:
            var now:=Quaternion(axis,angle)
            var result:Quaternion=Entry.extrapolate(Quaternion.IDENTITY,now,2.)
            var expected:=Quaternion(axis,3.*angle)
            check(result.is_finite() and absf(result.length()-1.)<.00001,"tiny delta unit quaternion")
            check((Basis(result).x-Basis(expected).x).length()<.00001 and (Basis(result).y-Basis(expected).y).length()<.00001,"tiny delta extrapolation")

func run()->void:
    var args:=OS.get_cmdline_user_args()
    if args.size()!=1 or not ClassDB.class_exists("PixelFXBodyRaster"):
        push_error("native PixelFX and output required")
        quit(2)
        return
    out=args[0]
    DirAccess.make_dir_recursive_absolute(out)
    raster=ClassDB.instantiate("PixelFXBodyRaster")
    tiny_rotation_probe()
    var f=Training.new()
    var pose:Dictionary=f.walker.pose.duplicate(true)
    for start in [0,16384,32768,49152,64000,-64000]:
        for direction in [-1,1]:free_probe(pose,start,direction,start==32768 and direction==1)
    for side in Support.SIDES:support_probe(pose,side)
    legacy_probe(pose)
    check(switches==28 and frames==200 and rejected==2,"all cases completed")
    var report:Dictionary={"frames":frames,"switches":switches,"rejected":rejected,"max_entry_gap":max_entry,"max_entry_basis_gap":max_entry_basis,"max_endpoint_gap":max_endpoint,"max_raw_entry_jump":max_raw_jump,"max_bone_error":max_length,"max_joint_step":max_step,"max_yaw_step_units":max_yaw_step,"max_velocity_delta":max_velocity_error,"max_anchor_error":max_anchor,"failures":failures}
    for item in [["metrics.json",report],["trace.json",trace]]:
        var file:=FileAccess.open(out.path_join(item[0]),FileAccess.WRITE)
        file.store_string(JSON.stringify(item[1]))
        file.close()
    print("SPATIAL_ENTRY_004 ",JSON.stringify(report))
    quit(0 if failures.is_empty() else 1)
