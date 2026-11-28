extends SceneTree
const FK=preload("res://lab/spatial_lab/spatial_fk.gd")
const SpatialBody=preload("res://lab/spatial_lab/spatial_body.gd")
const Body=preload("res://lab/body_ankle_069.gd")
const Training=preload("res://lab/training_control.gd")
const Depth=preload("res://lab/arm_depth_090.gd")
const CFG={"width":480,"height":270,"origin":[240,219],"density":3,"ink":0xff000000,"outline":3,"light":[-.48,-.64,.6],"seams":false,"debug":true,"materials":[[0xffe6ded7,0xffbdb3a8,0xff9e9081,0xff746759],[0xffa09d74,0xff827d50,0xff656139,0xff4a4628],[0xff655a4c,0xff50473b,0xff3c342c,0xff29231e],[0xff7278e2,0xff4c53bb,0xff35398b,0xff27265c]]}
var failures:Array[String]=[]
var raster
var out:String
var min_pixels:int=2147483647
var max_primitives:int=0
var max_normal_error:float=0.
var min_iou:float=1.
var cases:int=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,msg:String)->void:
    if not ok and not failures.has(msg):failures.append(msg)
func render(parts:Array)->Dictionary:
    var q:Dictionary=raster.render(CFG,parts)
    check(q.get("ok",false),"native render "+str(q.get("error","")))
    return q
func image(q:Dictionary)->Image:
    return Image.create_from_data(q.width,q.height,false,Image.FORMAT_RGBA8,q.rgba)
func write(q:Dictionary,name:String)->void:
    if q.get("ok",false):check(image(q).save_png(out.path_join(name))==OK,"save "+name)
func inspect(parts:Array)->void:
    max_primitives=maxi(max_primitives,parts.size())
    check(parts.size()<=512,"native primitive budget")
    for p in parts:
        check(int(p.part_id)>=1 and int(p.part_id)<=19,"stable ownership")
        var expected:int=1 if int(p.part_id)-1 in [0,2,3,8,9] else (2 if int(p.part_id)-1 in [5,6,7,11,12,13,15,17] else 0)
        check(p.material_id==expected,"stable material")
        if p.type!="triangle":continue
        for key in ["na","nb","nc"]:
            var n:=Vector3(p[key][0],p[key][1],p[key][2])
            var error:float=absf(n.length()-1.)
            max_normal_error=maxf(max_normal_error,error)
            check(n.is_finite() and error<.00001,"unit normal")
func overlap_test()->void:
    var p:Dictionary={"part_id":3,"material_id":1,"profile":2.,"sections":[[0.,2.,2.,2.,0.],[1.,2.,2.,2.,0.]]}
    var near:Array=[]
    var far:Array=[]
    # Exactly camera-aligned tube: analytic loft rejects zero XY length,
    # but the spatial caps must cover the center with positive front Z.
    SpatialBody.loft(near,p,Vector3(0,-20,1),Vector3(0,-20,8),Basis.IDENTITY,2)
    p.part_id=9
    SpatialBody.loft(far,p,Vector3(0,-20,-8),Vector3(0,-20,-1),Basis.IDENTITY,2)
    var a:Dictionary=render(far+near)
    var b:Dictionary=render(near+far)
    if not a.get("ok",false) or not b.get("ok",false):return
    var center:int=(int(CFG.origin[1])-20*int(CFG.density))*int(CFG.width)+int(CFG.origin[0])
    check(a.part[center]==3 and b.part[center]==3,"front owns overlap regardless submission order")
    check(absf(a.depth[center]-8.)<.0001,"end-on cap front Z")
    check(a.part==b.part and a.depth==b.depth,"order-invariant non-tied surfaces")
    check(a.body_pixels>30,"end-on visible area")
    write(a,"end-on.png")
func compare_mask(a:Dictionary,b:Dictionary)->float:
    var union_count:int=0
    var intersection:int=0
    for i in a.part.size():
        if a.part[i]>0 or b.part[i]>0:union_count+=1
        if a.part[i]>0 and b.part[i]>0:intersection+=1
    return float(intersection)/maxi(1,union_count)
func run()->void:
    var args:=OS.get_cmdline_user_args()
    if args.size()!=1 or not ClassDB.class_exists("PixelFXBodyRaster"):
        push_error("native PixelFXBodyRaster and output directory required")
        quit(2)
        return
    out=args[0]
    DirAccess.make_dir_recursive_absolute(out)
    raster=ClassDB.instantiate("PixelFXBodyRaster")
    overlap_test()
    var f=Training.new()
    var rig=FK.new()
    var skin=SpatialBody.new()
    var legacy_body=Body.new(2)
    var poses:Array=[f.walker.pose.duplicate(true)]
    for i in 20:f.step(1,true)
    poses.append(f.walker.pose.duplicate(true))
    for i in 50:f.step(0)
    check(f.press_round_kick(),"legacy L capture starts")
    for i in 13:f.step(0)
    poses.append(f.walker.pose.duplicate(true))
    for i in poses.size():
        var pose:Dictionary=poses[i]
        var old=Body.make_rig()
        old.evaluate(pose)
        var legacy:Array=legacy_body.make(old.points,pose.angles,old.rotations.head)
        Depth.apply(legacy,0.)
        SpatialBody.materials(legacy)
        var control:Dictionary=render(legacy)
        if not control.get("ok",false):continue
        var old_bounds:Rect2i=image(control).get_used_rect()
        check(old_bounds.position.x>0 and old_bounds.end.x<int(CFG.width) and old_bounds.position.y>0 and old_bounds.end.y<int(CFG.height),"legacy control unclipped")
        write(control,"legacy-%d.png"%i)
        var zero:Dictionary={}
        var pose_before:Dictionary=pose.duplicate(true)
        for step in 17:
            var yaw:int=step*4096
            rig.lift_legacy(pose,yaw)
            var before:Dictionary=rig.joint_xyz.duplicate()
            var parts:Array=skin.make(rig,pose)
            inspect(parts)
            check(rig.joint_xyz==before and pose==pose_before,"render does not mutate pose")
            var result:Dictionary=render(parts)
            if not result.get("ok",false):continue
            cases+=1
            min_pixels=mini(min_pixels,int(result.body_pixels))
            var bounds:Rect2i=image(result).get_used_rect()
            check(result.body_pixels>100 and bounds.position.x>0 and bounds.end.x<int(CFG.width) and bounds.position.y>0 and bounds.end.y<int(CFG.height),"visible unclipped body")
            if step==0:
                zero=result
                min_iou=minf(min_iou,compare_mask(control,result))
            if step==16:check(result.rgba==zero.rgba and result.part==zero.part,"360 closure exact")
            write(result,"pose-%d-yaw-%03d.png"%[i,roundi(step*22.5)])
        var legacy_after:Dictionary=render(legacy)
        check(legacy_after.get("rgba")==control.rgba and legacy_after.get("part")==control.part,"legacy renderer unchanged by spatial draws")
    # Independent azimuth and chest/shoulder twist, not just rigid yaw.
    rig.evaluate_spatial(poses[0],12345,0.,4096,-2048,{"shoulder_near":16384})
    var twisted:Array=skin.make(rig,poses[0])
    inspect(twisted)
    write(render(twisted),"twist.png")
    var report:Dictionary={"cases":cases,"min_body_pixels":min_pixels,"max_primitives":max_primitives,"max_normal_error":max_normal_error,"min_legacy_silhouette_iou":min_iou,"failures":failures}
    check(cases==51,"all 3 x 17 samples rendered")
    var file:=FileAccess.open(out.path_join("metrics.json"),FileAccess.WRITE)
    file.store_string(JSON.stringify(report))
    file.close()
    print("SPATIAL_RASTER_002 ",JSON.stringify(report))
    quit(0 if failures.is_empty() else 1)
