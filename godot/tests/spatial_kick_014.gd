extends SceneTree
const Mocap=preload("res://lab/spatial_lab/spatial_mocap_010.gd")
const Style=preload("res://lab/spatial_lab/spatial_mocap_style_011.gd")
const Idle=preload("res://lab/spatial_lab/spatial_idle_013.gd")
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
const Seq=preload("res://lab/spatial_lab/spatial_kick_014.gd")
const Profile=preload("res://lab/spatial_lab/spatial_kick_profile_014.gd")
func exercise(mode:int,phase:int)->void:
    var seq=Seq.new()
    var art:Dictionary=Training.new().walker.pose.duplicate(true)
    seq.setup(art,mode,phase)
    var baseline=Style.new()
    baseline.mode=2
    baseline.setup(art)
    var stats:Dictionary={"max_step":0.,"max_velocity_delta":0.,"entry_max_step":0.,"exit_max_step":0.,"max_yaw_step_deg":0.,"max_basis_step_deg":0.,"max_knee_plane_step_deg":0.,"impact_height":0.,"impact_forward":0.,"impact_reach":0.,"max_floor_penetration":0.}
    var samples:Array=[]
    var knee_planes:Dictionary={}
    for t in Seq.TOTAL:
        var q:Dictionary=seq.step(t)
        check(q.accepted,"sequence accepted "+str(mode)+" "+str(phase)+" "+str(t))
        if not q.accepted:return
        var r=seq.rig
        var s:Dictionary=seq.current
        var local:int=t-Seq.PRE
        var at_end:bool=local>=seq.attack_end+Seq.RECOVERY
        if mode==1 and local>=0 and local<=seq.attack_end:
            check(baseline.evaluate_style(local).accepted,"011 baseline")
            check(baseline.rig.joint_xyz==seq.attack.rig.joint_xyz and baseline.rig.joint_basis==seq.attack.rig.joint_basis,"A exact source 011 C")
        if local==0:
            check(s.xyz==seq.entry.current.xyz,"entry exact D")
        if at_end:
            var goal:Dictionary=seq.idle_sample(phase+local,seq.return_offset,seq.return_winding)
            check(s.xyz==goal.xyz and s.basis==goal.basis and s.yaw==goal.yaw,"recovery exact D")
        max_anchor=maxf(max_anchor,float(q.anchor_error))
        for id in r.ids_in_order():
            var p:Vector3=r.point3(id)
            var b:Basis=r.joint_basis[id]
            check(p.is_finite() and absf(b.determinant()-1.)<.001,"finite basis")
            var par:String=r.parent_id(id)
            if not par.is_empty():
                var e:float=absf(p.distance_to(r.point3(par))-r.rest_offset_xyz(id).length())
                max_bone=maxf(max_bone,e)
                check(e<.0001,"canonical length")
            if t>0:
                var prior:Dictionary=samples[-1]
                var v:Vector3=p-Vector3(prior.xyz[id])
                stats.max_step=maxf(stats.max_step,v.length())
                if local>=0 and local<=Seq.ENTRY:stats.entry_max_step=maxf(stats.entry_max_step,v.length())
                if local>seq.attack_end and not at_end:stats.exit_max_step=maxf(stats.exit_max_step,v.length())
                var rot:float=rad_to_deg(b.get_rotation_quaternion().angle_to(Basis(prior.basis[id]).get_rotation_quaternion()))
                stats.max_basis_step_deg=maxf(stats.max_basis_step_deg,rot)
                if t>1:
                    var v0:Vector3=Vector3(prior.xyz[id])-Vector3(samples[-2].xyz[id])
                    stats.max_velocity_delta=maxf(stats.max_velocity_delta,(v-v0).length())
        if t>0:
            stats.max_yaw_step_deg=maxf(stats.max_yaw_step_deg,absf(float(int(s.yaw)-int(samples[-1].yaw)))*360./65536.)
        for side in Support.SIDES:
            var a:Vector3=r.point3("knee_"+side)-r.point3("thigh_"+side)
            var b:Vector3=r.point3("foot_"+side)-r.point3("knee_"+side)
            var n:Vector3=a.normalized().cross(b.normalized())
            if n.length()>.08:
                if knee_planes.has(side):stats.max_knee_plane_step_deg=maxf(stats.max_knee_plane_step_deg,rad_to_deg(n.normalized().angle_to(knee_planes[side])))
                knee_planes[side]=n.normalized()
            else:knee_planes.erase(side)
            stats.max_floor_penetration=maxf(stats.max_floor_penetration,Support.toe(r,art,side).y)
        if local==Profile.HIT_TICKS[mode]:
            var ray:Vector3=r.point3("foot_near")-r.point3("thigh_near")
            stats.impact_height=-ray.y
            stats.impact_forward=ray.x
            stats.impact_reach=ray.length()/(r.rest_offset_xyz("knee_near").length()+r.rest_offset_xyz("foot_near").length())
            check(ray.x>0. and ray.y<0.,"forward high strike")
        if phase==17:capture(body.make(r,art),str(mode)+"-near-%03d.png"%t,0.)
        samples.append(s)
        frames+=1
    var winding:float=float(int(samples[Seq.PRE+seq.attack_end].yaw)-int(samples[Seq.PRE].yaw))*360./65536.
    stats.attack_winding_deg=winding
    check(winding< -320. and winding> -410.,"single signed turn")
    check(stats.max_yaw_step_deg<90.,"no yaw wrap jump")
    stats.merge(seq.metrics,true)
    stats.hit_tick=Profile.HIT_TICKS[mode]
    stats.attack_ticks=seq.attack_end
    stats.return_offset=xyz(seq.return_offset)
    profile_metrics[str(mode)+"-"+str(phase)]=stats
    count+=1

func run()->void:
    var args:=OS.get_cmdline_user_args()
    if args.size()!=1 or not ClassDB.class_exists("PixelFXBodyRaster"):
        push_error("native raster required")
        quit(2)
        return
    out=args[0]
    DirAccess.make_dir_recursive_absolute(out)
    raster=ClassDB.instantiate("PixelFXBodyRaster")
    for mode in [1,2,3]:
        for phase in [0,17,33]:exercise(mode,phase)
    check(count==9 and frames==972,"all sequences")
    var report:Dictionary={"cases":count,"samples":frames,"rendered_frames":324,"max_bone_error":max_bone,"max_anchor_error":max_anchor,"profiles":profile_metrics,"failures":failures}
    var file:=FileAccess.open(out.path_join("metrics.json"),FileAccess.WRITE)
    file.store_string(JSON.stringify(report))
    file.close()
    print("SPATIAL_KICK_014 ",JSON.stringify(report))
    quit(0 if failures.is_empty() else 1)
