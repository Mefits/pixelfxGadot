extends SceneTree
const Mocap=preload("res://lab/spatial_lab/spatial_mocap_010.gd")
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
func control()->void:
    var l=Old.new()
    l.coordination=3
    l.configure({"leg":0})
    check(l.begin(Training.new()),"008 control starts")
    for i in range(Mocap.END+1):
        if i>0 and l.active:check(l.step().accepted,"008 control step")
        capture(body.make(l.player.rig,l.pose),"0-near-%03d.png"%i,l.origin_x)

func exercise(mode:int)->void:
    var m=Mocap.new()
    var art:Dictionary=Training.new().walker.pose.duplicate(true)
    m.setup(art)
    var initial_yaw:int=m.yaw_at(0)
    var prior:Dictionary={}
    var max_joint:float=0.
    var max_accel:float=0.
    var max_floor:float=0.
    var peak_foot:float=100.
    var max_angle:float=0.
    var last_steps:Dictionary={}
    var start:Dictionary={}
    var contact_switches:Array=[]
    var last_contact:String=""
    for i in range(Mocap.END+1):
        var q:Dictionary=m.evaluate(i,mode==2)
        check(q.accepted,"retarget accepted "+str(mode)+" "+str(i))
        if not q.accepted:return
        var r=m.rig
        var sample:Dictionary=Entry.sample(r,art,m.support if mode==2 else null)
        if i==0:start=sample.duplicate(true)
        for id in r.ids_in_order():
            var par:String=r.parent_id(id)
            check(r.point3(id).is_finite(),"finite")
            var b:Basis=r.joint_basis[id]
            check(absf(b.determinant()-1.)<.001,"valid joint basis")
            if not par.is_empty():
                var e:float=absf(r.point3(id).distance_to(r.point3(par))-r.rest_offset_xyz(id).length())
                max_bone=maxf(max_bone,e)
                check(e<.0001,"bone length")
            if i>0:
                var d:Vector3=r.point3(id)-Vector3(prior.xyz[id])
                max_joint=maxf(max_joint,d.length())
                if last_steps.has(id):max_accel=maxf(max_accel,(d-Vector3(last_steps[id])).length())
                last_steps[id]=d
        if i%2==0 and mode==1:
            var pairs:Array=[["hips","chest",2],["chest","head",4]]
            for k in 2:
                var side:String=Support.SIDES[k]
                var j:int=5+k*5
                pairs.append_array([["shoulder_"+side,"elbow_"+side,j],["elbow_"+side,"hand_"+side,j+1],["thigh_"+side,"knee_"+side,j+2],["knee_"+side,"foot_"+side,j+3]])
            for pair in pairs:
                var d:Vector3=(r.point3(pair[1])-r.point3(pair[0])).normalized()
                var a:float=rad_to_deg(d.angle_to(m.sample(i,int(pair[2]))))
                max_angle=maxf(max_angle,a)
                check(a<.05,"direct direction preserved")
        if mode==2:
            var toe:Vector3=Support.toe(r,art,m.active_side)
            var e:float=toe.distance_to(Vector3(m.support.contacts[m.active_side].anchor))
            max_anchor=maxf(max_anchor,e)
            check(e<Support.TOL,"world toe anchor")
            if m.active_side!=last_contact:contact_switches.append([i,m.active_side])
            last_contact=m.active_side
        var low:float=maxf(Support.toe(r,art,"near").y,Support.toe(r,art,"far").y)
        max_floor=maxf(max_floor,low)
        peak_foot=minf(peak_foot,r.point3("foot_near").y-r.point3("thigh_near").y)
        capture(body.make(r,art),str(mode)+"-near-%03d.png"%i,0.)
        trace.append({"mode":mode,"tick":i,"yaw":r.yaw_units,"hips":xyz(r.point3("hips")),"kick_ankle":xyz(r.point3("foot_near")),"contact":m.active_side,"low_toe":low})
        prior=sample
        frames+=1
    var degrees:float=float(m.rig.yaw_units-initial_yaw)*360./65536.
    check(absf(degrees)>340. and absf(degrees)<410.,"single measured winding")
    check(peak_foot<0.,"high kick preserved")
    if mode==2:check(contact_switches==[[0,"near"],[34,"far"],[80,"near"]],"annotated contact schedule")
    # Isolated MotionEntry guard -> imported spatial target. No contacts
    # acquired here, so this checks the existing transition contract only.
    var guard=FK.new()
    guard.lift_legacy(art)
    var t=Transition.new()
    t.seed(guard,art)
    t.command(6)
    for i in range(7):
        var q:Dictionary=t.step(start)
        check(q.accepted,"imported entry")
        if i==0:check(t.rig.joint_xyz==guard.joint_xyz,"exact entry boundary")
    check(t.rig.joint_xyz==start.xyz,"entry exact target")
    var restore=Transition.new()
    restore.load_checkpoint(t.checkpoint())
    check(restore.checkpoint()==t.checkpoint(),"entry checkpoint")
    profile_metrics[str(mode)]={"yaw_degrees":degrees,"max_joint_step":max_joint,"max_joint_second_difference":max_accel,"max_low_toe_y":max_floor,"peak_kick_relative_y":peak_foot,"max_direct_direction_error_deg":max_angle,"contact_switches":contact_switches,"max_ground_correction":m.shift_peak}
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
    control()
    exercise(1)
    exercise(2)
    check(count==2 and frames==342,"all 60Hz samples")
    var report:Dictionary={"source_frames":86,"samples_per_variant":171,"cases":count,"frames":frames,"max_bone_error":max_bone,"max_anchor_error":max_anchor,"profiles":profile_metrics,"failures":failures}
    for item in [["metrics.json",report],["trace.json",trace]]:
        var file:=FileAccess.open(out.path_join(item[0]),FileAccess.WRITE)
        file.store_string(JSON.stringify(item[1]))
        file.close()
    print("SPATIAL_MOCAP_010 ",JSON.stringify(report))
    quit(0 if failures.is_empty() else 1)
