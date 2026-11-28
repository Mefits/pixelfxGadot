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
var traces_by_mode:Dictionary={}
func exercise(mode:int)->void:
    var m=Idle.new()
    var art:Dictionary=Training.new().walker.pose.duplicate(true)
    m.mode=mode
    m.setup(art)
    if mode==0:
        var g20=Mocap.new()
        g20.setup(art)
        check(g20.evaluate(0,true).accepted,"control source")
        check(m.idle(0).accepted and Entry.sample(m.rig,art)==Entry.sample(g20.rig,art),"A exact G20")
    var samples:Array=[]
    var stats:Dictionary={"max_step":0.,"max_velocity_delta":0.,"max_seam_step":0.,"max_seam_velocity_delta":0.,"max_toe_y":-100.,"max_toe_drift":0.,"hip_y_range":0.,"pose_excursion":0.}
    var hip_lo:float=INF
    var hip_hi:float=-INF
    var initial:Dictionary={}
    for tick in range(97):
        var q:Dictionary=m.idle(tick)
        check(q.accepted,"idle accepted "+str(mode)+" "+str(tick))
        if not q.accepted:return
        var r=m.rig
        var s:Dictionary=Entry.sample(r,art)
        if tick==0:initial=s.duplicate(true)
        if tick>=48:check(s==samples[tick%48],"exact periodic pose")
        samples.append(s)
        hip_lo=minf(hip_lo,r.point3("hips").y)
        hip_hi=maxf(hip_hi,r.point3("hips").y)
        for id in r.ids_in_order():
            var p:Vector3=r.point3(id)
            var b:Basis=r.joint_basis[id]
            check(p.is_finite() and absf(b.determinant()-1.)<.001,"finite proper basis")
            var par:String=r.parent_id(id)
            if not par.is_empty():
                var e:float=absf(p.distance_to(r.point3(par))-r.rest_offset_xyz(id).length())
                max_bone=maxf(max_bone,e)
                check(e<.0001,"canonical length")
            stats.pose_excursion=maxf(stats.pose_excursion,(p-Vector3(initial.xyz[id])).length())
            if tick>0:
                var step:Vector3=p-Vector3(samples[tick-1].xyz[id])
                stats.max_step=maxf(stats.max_step,step.length())
                if tick%48==0:stats.max_seam_step=maxf(stats.max_seam_step,step.length())
                if tick>1:
                    var old:Vector3=Vector3(samples[tick-1].xyz[id])-Vector3(samples[tick-2].xyz[id])
                    var delta:float=(step-old).length()
                    stats.max_velocity_delta=maxf(stats.max_velocity_delta,delta)
                    if tick%48 in [0,1]:stats.max_seam_velocity_delta=maxf(stats.max_seam_velocity_delta,delta)
        for side in Support.SIDES:
            var toe:Vector3=Support.toe(r,art,side)
            stats.max_toe_y=maxf(stats.max_toe_y,toe.y)
            var drift:Vector3=toe-Vector3(initial.toes[side])
            stats.max_toe_drift=maxf(stats.max_toe_drift,Vector2(drift.x,drift.z).length())
            if mode>0:
                var e:float=toe.distance_to(Vector3(traces_by_mode[0][tick].toes[side]))
                max_anchor=maxf(max_anchor,e)
                check(e<Support.TOL,"fixed G20 toe")
        if mode>=1:check(float(stats.max_toe_y)<.001,"toe-reference floor")
        if tick<48:capture(body.make(r,art),str(mode)+"-near-%03d.png"%tick,0.)
        frames+=1
    stats.hip_y_range=hip_hi-hip_lo
    if mode>0:check(float(stats.pose_excursion)>.01,"non-static cycle")
    if mode==2:check(float(stats.pose_excursion)<float(profile_metrics["1"].pose_excursion),"damped movement")
    if mode>0:
        stats.max_root_shift=m.max_shift
        stats.max_fixed_toe_error=m.max_toe_error
    if mode==3:
        check(samples[0].yaw==int(traces_by_mode[2][0].yaw)-roundi(15.*65536./360.),"D signed turn")
    # Use actual two consecutive idle samples as entry, blend into existing
    # G20 C target sequence without changing attack or contact rules.
    if mode>0:
        for phase in [0,17,33]:
            var attack=Style.new()
            attack.mode=2
            attack.setup(art)
            var entry=Entry.new(samples[phase+48],samples[phase+47])
            var dest=FK.new()
            for i in range(Style.DURATIONS[2]+1):
                check(attack.evaluate_style(i).accepted,"attack sample")
                var target:Dictionary=Entry.sample(attack.rig,art)
                entry.blend(dest,target,i,6)
                if i==0:check(dest.joint_xyz==samples[phase].xyz,"idle entry exact")
                if i>=6:check(dest.joint_xyz==target.xyz,"attack target exact")
                for id in dest.ids_in_order():
                    var par:String=dest.parent_id(id)
                    if not par.is_empty():check(absf(dest.point3(id).distance_to(dest.point3(par))-dest.rest_offset_xyz(id).length())<.0001,"transition length")
                if phase==17:capture(body.make(dest,art),str(mode)+"-attack-%03d.png"%i,0.)
    traces_by_mode[mode]=samples
    profile_metrics[str(mode)]=stats
    count+=1

func run()->void:
    var args:=OS.get_cmdline_user_args()
    if args.size()!=1 or not ClassDB.class_exists("PixelFXBodyRaster"):
        push_error("native raster and output required")
        quit(2)
        return
    out=args[0]
    DirAccess.make_dir_recursive_absolute(out)
    raster=ClassDB.instantiate("PixelFXBodyRaster")
    for mode in 4:exercise(mode)
    check(count==4 and frames==388,"two complete cycles per mode")
    var report:Dictionary={"cases":count,"samples":frames,"rendered_frames":357,"period_ticks":48,"max_bone_error":max_bone,"max_fixed_toe_error":max_anchor,"profiles":profile_metrics,"failures":failures}
    var file:=FileAccess.open(out.path_join("metrics.json"),FileAccess.WRITE)
    file.store_string(JSON.stringify(report))
    file.close()
    print("SPATIAL_IDLE_013 ",JSON.stringify(report))
    quit(0 if failures.is_empty() else 1)
