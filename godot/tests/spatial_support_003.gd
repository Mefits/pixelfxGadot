extends SceneTree
const FK=preload("res://lab/spatial_lab/spatial_fk.gd")
const IK=preload("res://lab/spatial_lab/spatial_ik.gd")
const Support=preload("res://lab/spatial_lab/spatial_support.gd")
const SpatialBody=preload("res://lab/spatial_lab/spatial_body.gd")
const Training=preload("res://lab/training_control.gd")
const CFG={"width":480,"height":270,"origin":[240,219],"density":3,"ink":0xff000000,"outline":3,"light":[-.48,-.64,.6],"seams":false,"debug":true,"materials":[[0xffe6ded7,0xffbdb3a8,0xff9e9081,0xff746759],[0xffa09d74,0xff827d50,0xff656139,0xff4a4628],[0xff655a4c,0xff50473b,0xff3c342c,0xff29231e],[0xff7278e2,0xff4c53bb,0xff35398b,0xff27265c]]}
var failures:Array[String]=[]
var max_length:float=0.
var max_anchor:float=0.
var max_basis:float=0.
var max_shift:float=0.
var max_free_delta:float=0.
var min_pole_dot:float=1.
var solved_count:int=0
var rejected:int=0
var trace:Array=[]
var raster
var out:String
func _initialize()->void:call_deferred("run")
func check(ok:bool,msg:String)->void:
    if not ok and not failures.has(msg):failures.append(msg)
func xyz(v:Vector3)->Array:return [v.x,v.y,v.z]
func length_check(a:Vector3,b:Vector3,wanted:float)->void:
    var e:float=absf(a.distance_to(b)-wanted)
    max_length=maxf(max_length,e)
    check(e<.0001,"bone length")
func analytic()->void:
    var axis:=Vector3.DOWN
    var pole:=Vector3.RIGHT
    for side in [-1.,1.]:
        for target in [Vector3(4*side,15,3),Vector3(0,50,0),Vector3.ZERO,Vector3(0,21.997,0),Vector3(0,-17,0)]:
            var q:Dictionary=IK.solve(Vector3.ZERO,target,11.,11.,axis,pole*side)
            length_check(Vector3.ZERO,q.knee,11.)
            length_check(q.knee,q.ankle,11.)
            check(Vector3(q.knee).is_finite() and Vector3(q.ankle).is_finite(),"finite analytic")
            check(float(q.bend)>=0. and float(q.bend)<=155.0001,"knee range")
            if target.length()>IK.max_reach(11.,11.) or target.length()<IK.min_reach(11.,11.):
                check(q.residual>.001,"unreachable residual")
            else:check(q.residual<.0001,"reachable target")
            check(absf(Vector3(q.axis).dot(Vector3(q.pole)))<.0001,"knee plane orthogonal")
        var prev:Dictionary=IK.solve(Vector3.ZERO,Vector3(0,21.997,0),11.,11.,axis,pole*side)
        for i in range(-10,11):
            var q:Dictionary=IK.solve(Vector3.ZERO,Vector3(float(i)*.0001,21.997,.0002),11.,11.,prev.axis,prev.pole)
            var dot:float=Vector3(prev.pole).dot(Vector3(q.pole))
            min_pole_dot=minf(min_pole_dot,dot)
            check(dot>.99,"near-straight knee plane continuity")
            prev=q
func geometry(r)->void:
    for id in r.ids_in_order():
        var par:String=r.parent_id(id)
        if not par.is_empty():length_check(r.point3(id),r.point3(par),r.rest_offset_xyz(id).length())
        var p:Vector3=r.point3(id)
        check(p.is_finite() and r.point(id)==Vector2(p.x,p.y),"projection/finite")
        var basis:Basis=r.joint_basis[id]
        check(basis.is_finite() and absf(basis.determinant()-1.)<.0001,"proper joint basis")
    for side in Support.SIDES:
        if not r.foot_basis_override.has(side):continue
        for pair in [["thigh_","knee_"],["knee_","foot_"]]:
            var parent:String=pair[0]+side
            var child:String=pair[1]+side
            var error:float=(r.point3(child)-r.point3(parent)-r.joint_basis[parent]*r.rest_offset_xyz(child)).length()
            max_basis=maxf(max_basis,error)
            check(error<.0001,"basis maps actual bone")
func capture(r,pose:Dictionary,body,name:String)->void:
    var parts:Array=body.make(r,pose)
    var result:Dictionary=raster.render(CFG,parts)
    check(result.get("ok",false),"native capture "+str(result.get("error","")))
    if not result.get("ok",false):return
    var im:=Image.create_from_data(result.width,result.height,false,Image.FORMAT_RGBA8,result.rgba)
    var bounds:Rect2i=im.get_used_rect()
    check(bounds.position.x>0 and bounds.position.y>0 and bounds.end.x<480 and bounds.end.y<270,"capture unclipped")
    check(im.save_png(out.path_join(name))==OK,"save "+name)
func pivot_probe(base_pose:Dictionary,side:String,mode:int,sign_dir:int)->void:
    var pose:Dictionary=base_pose.duplicate(true)
    var free_side:String="far" if side=="near" else "near"
    pose.angles["thigh_"+free_side]=-65.
    pose.angles["knee_"+free_side]=95.
    pose.root[1]+=1.5
    var r=FK.new()
    var raw=FK.new()
    var body=SpatialBody.new()
    var support=Support.new()
    r.lift_legacy(pose)
    support.capture(r,pose,side,mode)
    var anchor:Vector3=support.contacts[side].anchor
    var initial_frame:Basis=support.contacts[side].basis
    var label:String=side+"-"+("pivot" if mode==Support.PIVOT else "fixed")+"-"+("pos" if sign_dir>0 else "neg")
    var previous:Dictionary={}
    for i in 25:
        var yaw:int=roundi(float(i)*65536./24.)*sign_dir
        raw.lift_legacy(pose,yaw)
        var q:Dictionary=support.resolve(r,pose,yaw)
        check(q.accepted,"single support "+label)
        if not q.accepted:continue
        solved_count+=1
        geometry(r)
        var toe:Vector3=Support.toe(r,pose,side)
        var error:float=toe.distance_to(anchor)
        max_anchor=maxf(max_anchor,error)
        max_shift=maxf(max_shift,Vector3(q.root_shift).length())
        check(error<Support.TOL,"world contact")
        var expected:Basis=FK.yaw_basis(yaw)*initial_frame if mode==Support.PIVOT else initial_frame
        check(r.foot_basis_override[side].is_equal_approx(expected),"foot orientation policy")
        var delta:float=(r.point3("foot_"+free_side)-raw.point3("foot_"+free_side)-Vector3(q.root_shift)).length()
        max_free_delta=maxf(max_free_delta,delta)
        check(delta<.0001 and not r.foot_basis_override.has(free_side),"free leg unchanged except root")
        var solved:Dictionary=q.legs[side]
        if not previous.is_empty():
            var transported:Vector3=FK.yaw_basis(yaw-int(previous.yaw))*Vector3(previous.pole)
            var dot:float=transported.dot(Vector3(solved.pole))
            check(dot>0.,"no knee plane flip "+label)
        previous={"yaw":yaw,"pole":solved.pole}
        trace.append({"case":label,"frame":i,"yaw":yaw,"anchor":xyz(anchor),"toe":xyz(toe),"hip":xyz(r.point3("thigh_"+side)),"knee":xyz(r.point3("knee_"+side)),"ankle":xyz(r.point3("foot_"+side)),"fk_toe":xyz(Support.toe(raw,pose,side)),"shift":xyz(q.root_shift)})
        if (mode==Support.PIVOT and sign_dir>0) or i%6==0:
            capture(r,pose,body,label+"-%02d.png"%i)
        if mode==Support.PIVOT and sign_dir>0:capture(raw,pose,body,label+"-fk-%02d.png"%i)
    support.capture(r,pose,side,Support.FREE)
    check(support.resolve(r,pose,65536*sign_dir).accepted and r.foot_basis_override.is_empty(),"release clears foot override")
    r.evaluate_legacy(base_pose)
    check(r.foot_basis_override.is_empty() and not r.spatial_enabled,"legacy clear")
func dual_probe(pose:Dictionary)->void:
    var r=FK.new()
    var s=Support.new()
    r.lift_legacy(pose)
    for side in Support.SIDES:s.capture(r,pose,side,Support.FIXED)
    var q:Dictionary=s.resolve(r,pose,0)
    check(q.accepted,"compatible two contacts")
    if q.accepted:
        geometry(r)
        for side in Support.SIDES:check(Support.toe(r,pose,side).distance_to(s.contacts[side].anchor)<Support.TOL,"dual contact anchor")
    var before:Dictionary=r.joint_xyz.duplicate()
    var before_basis:Dictionary=r.joint_basis.duplicate()
    var contacts:Dictionary=s.contacts.duplicate(true)
    var bad:Dictionary=pose.duplicate(true)
    bad.root[0]+=100.
    q=s.resolve(r,bad,32768,0.,2.)
    check(not q.accepted and q.max_anchor_error>10.,"incompatible dual contact rejected")
    check(r.joint_xyz==before and r.joint_basis==before_basis and s.contacts==contacts,"failed transaction unchanged")
    if not q.accepted:rejected+=1
func run()->void:
    var args:=OS.get_cmdline_user_args()
    if args.size()!=1 or not ClassDB.class_exists("PixelFXBodyRaster"):
        push_error("native PixelFX and output required")
        quit(2)
        return
    out=args[0]
    DirAccess.make_dir_recursive_absolute(out)
    raster=ClassDB.instantiate("PixelFXBodyRaster")
    analytic()
    var f=Training.new()
    var pose:Dictionary=f.walker.pose.duplicate(true)
    var before:Dictionary=pose.duplicate(true)
    for side in Support.SIDES:
        for mode in [Support.PIVOT,Support.FIXED]:
            for direction in [-1,1]:pivot_probe(pose,side,mode,direction)
    dual_probe(pose)
    check(pose==before,"input pose unchanged")
    check(solved_count==200 and rejected==1,"all probes executed")
    var report:Dictionary={"solved":solved_count,"rejected":rejected,"max_anchor_error":max_anchor,"max_length_error":max_length,"max_basis_error":max_basis,"max_root_shift":max_shift,"max_free_delta":max_free_delta,"min_near_straight_pole_dot":min_pole_dot,"failures":failures}
    for entry in [["metrics.json",report],["trace.json",trace]]:
        var file:=FileAccess.open(out.path_join(entry[0]),FileAccess.WRITE)
        file.store_string(JSON.stringify(entry[1]))
        file.close()
    print("SPATIAL_SUPPORT_003 ",JSON.stringify(report))
    quit(0 if failures.is_empty() else 1)
