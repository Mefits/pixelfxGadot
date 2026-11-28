extends SceneTree
const Mocap=preload("res://lab/spatial_lab/spatial_mocap_010.gd")
const Style=preload("res://lab/spatial_lab/spatial_mocap_style_011.gd")
const IK=preload("res://lab/spatial_lab/spatial_ik.gd")
const Entry=preload("res://lab/spatial_lab/spatial_motion_entry.gd")
const Transition=preload("res://lab/spatial_lab/spatial_transition.gd")

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
var reference_peak:Dictionary={}
var peak_reach:float=0.
func exercise(mode:int)->void:
    var m=Mocap.new() if mode==0 else Style.new()
    var independent=Mocap.new()
    var art:Dictionary=Training.new().walker.pose.duplicate(true)
    if mode>0:m.mode=mode
    m.setup(art)
    if mode==0:independent.setup(art)
    var duration:int=Style.DURATIONS[mode]
    var hit:int=Style.HIT_TICKS[mode]
    var prior:Dictionary={}
    var prior_yaw:int=0
    var first_yaw:int=0
    var prior_source:float=-1.
    var prior_step:Dictionary={}
    var prior_rot_step:Dictionary={}
    var prior_plane:Dictionary={}
    var metrics:Dictionary={"max_joint_step":0.,"max_joint_second_difference":0.,"max_basis_step_deg":0.,"max_basis_velocity_delta_deg":0.,"max_knee_plane_step_deg":0.,"max_toe_penetration":0.,"max_contact_switch_joint_step":0.,"max_yaw_step_deg":0.}
    var switches:Array=[]
    var last_contact:String=""
    var first_dirs:Dictionary={}
    for i in range(duration+1):
        var q:Dictionary=m.evaluate(i,true) if mode==0 else m.evaluate_style(i)
        check(q.accepted,"accepted "+str(mode)+" "+str(i))
        if not q.accepted:return
        var src:float=float(i) if mode==0 else float(m.source_time)
        check(src>=prior_source and src>=0. and src<=170.,"monotone source clock")
        if i==0:check(src==0.,"source start")
        if i==duration:check(is_equal_approx(src,170.),"source end")
        if i==hit:check(is_equal_approx(src,56.),"source impact sample")
        prior_source=src
        var r=m.rig
        var snap:Dictionary=Entry.sample(r,art,m.support)
        if i==0:first_yaw=r.yaw_units
        if mode==0:
            check(independent.evaluate(i,true).accepted,"010 independent control")
            check(snap==Entry.sample(independent.rig,art,independent.support),"A exact 010 C")
        var switched:bool=m.active_side!=last_contact
        if switched:switches.append([i,m.active_side])
        var toe:Vector3=Support.toe(r,art,m.active_side)
        var e:float=toe.distance_to(Vector3(m.support.contacts[m.active_side].anchor))
        max_anchor=maxf(max_anchor,e)
        check(e<Support.TOL,"world toe anchor")
        check(m.support.contacts.size()==1,"single support contact")
        for id in r.ids_in_order():
            var par:String=r.parent_id(id)
            var p:Vector3=r.point3(id)
            var basis:Basis=r.joint_basis[id]
            check(p.is_finite() and absf(basis.determinant()-1.)<.001,"finite basis")
            if not par.is_empty():
                var err:float=absf(p.distance_to(r.point3(par))-r.rest_offset_xyz(id).length())
                max_bone=maxf(max_bone,err)
                check(err<.0001,"bone length")
            if i>0:
                var d:Vector3=p-Vector3(prior.xyz[id])
                metrics.max_joint_step=maxf(metrics.max_joint_step,d.length())
                if switched:metrics.max_contact_switch_joint_step=maxf(metrics.max_contact_switch_joint_step,d.length())
                if prior_step.has(id):metrics.max_joint_second_difference=maxf(metrics.max_joint_second_difference,(d-Vector3(prior_step[id])).length())
                prior_step[id]=d
                var old_basis:Basis=prior.basis[id]
                var rot:float=rad_to_deg(old_basis.get_rotation_quaternion().angle_to(basis.get_rotation_quaternion()))
                metrics.max_basis_step_deg=maxf(metrics.max_basis_step_deg,rot)
                if prior_rot_step.has(id):metrics.max_basis_velocity_delta_deg=maxf(metrics.max_basis_velocity_delta_deg,absf(rot-float(prior_rot_step[id])))
                prior_rot_step[id]=rot
        for s in Support.SIDES:
            var a:Vector3=r.point3("knee_"+s)-r.point3("thigh_"+s)
            var b:Vector3=r.point3("foot_"+s)-r.point3("knee_"+s)
            var plane:Vector3=a.normalized().cross(b.normalized())
            # Near-straight limb has no well-conditioned bending plane.
            if plane.length()>.08:
                if prior_plane.has(s):metrics.max_knee_plane_step_deg=maxf(metrics.max_knee_plane_step_deg,rad_to_deg(Vector3(prior_plane[s]).angle_to(plane)))
                prior_plane[s]=plane.normalized()
            else:prior_plane.erase(s)
        var low:float=maxf(Support.toe(r,art,"near").y,Support.toe(r,art,"far").y)
        metrics.max_toe_penetration=maxf(metrics.max_toe_penetration,low)
        if i>0:metrics.max_yaw_step_deg=maxf(metrics.max_yaw_step_deg,float(absi(r.yaw_units-prior_yaw))*360./65536.)
        if i==hit:
            var ray:Vector3=r.point3("foot_near")-r.point3("thigh_near")
            var reach:float=r.rest_offset_xyz("knee_near").length()+r.rest_offset_xyz("foot_near").length()
            var torso:Vector3=r.point3("chest")-r.point3("hips")
            metrics.impact_reach_fraction=ray.length()/reach
            metrics.impact_forward=ray.x
            metrics.impact_height=-ray.y
            metrics.impact_torso_lean_deg=rad_to_deg(atan2(-torso.x,-torso.y))
            check(ray.x>0. and ray.y<0.,"forward elevated impact")
            if mode==0:
                reference_peak=snap.duplicate(true)
            else:
                check(absf(float(metrics.impact_reach_fraction)-Style.REACH[mode])<.015,"authored impact reach")
                var delta:Vector3=(r.point3("chest")-r.point3("hips"))-(Vector3(reference_peak.xyz.chest)-Vector3(reference_peak.xyz.hips))
                check(delta.length()>.5,"upper-body edit visible")
        if i in [0,hit,duration]:
            var transition=Transition.new()
            transition.seed(r,art)
            var restored=Transition.new()
            restored.load_checkpoint(transition.checkpoint())
            check(restored.checkpoint()==transition.checkpoint(),"pose checkpoint")
        capture(body.make(r,art),str(mode)+"-near-%03d.png"%i,0.)
        trace.append({"mode":mode,"tick":i,"source_tick":src,"yaw":r.yaw_units,"hip":xyz(r.point3("hips")),"ankle":xyz(r.point3("foot_near")),"contact":m.active_side,"toe_y":low})
        prior=snap
        prior_yaw=r.yaw_units
        last_contact=m.active_side
        frames+=1
    var degrees:float=float(m.rig.yaw_units-first_yaw)*360./65536.
    check(absf(degrees+373.64501953125)<.01,"source winding retained")
    check(switches.size()==3 and switches[0][1]=="near" and switches[1][1]=="far" and switches[2][1]=="near","source contact order")
    metrics.duration_ticks=duration
    metrics.hit_tick=hit
    metrics.yaw_degrees=degrees
    metrics.contact_switches=switches
    metrics.max_ground_correction=m.shift_peak
    profile_metrics[str(mode)]=metrics
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
    for mode in 4:exercise(mode)
    check(count==4 and frames==342,"all 60Hz samples")
    var report:Dictionary={"cases":count,"frames":frames,"max_bone_error":max_bone,"max_anchor_error":max_anchor,"profiles":profile_metrics,"failures":failures}
    for item in [["metrics.json",report],["trace.json",trace]]:
        var file:=FileAccess.open(out.path_join(item[0]),FileAccess.WRITE)
        file.store_string(JSON.stringify(item[1]))
        file.close()
    print("SPATIAL_MOCAP_STYLE_011 ",JSON.stringify(report))
    quit(0 if failures.is_empty() else 1)
