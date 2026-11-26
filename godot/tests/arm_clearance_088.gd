extends SceneTree
const Body=preload("res://lab/body_ankle_069.gd")
const Clips=preload("res://addons/creature/clips.gd")
const Run=preload("res://lab/arm_clearance_088.gd")
const Old=preload("res://lab/distance_gait_087.gd")
const IK=preload("res://lab/support_adaptation_077.gd")
const Leg=preload("res://lab/leg_constraints_082.gd")
const FIX="res://tests/fixtures/body_raster/full_058/"
const LABELS=["A / 087 ORIGINAL","B / STAGED ARM SWEEP"]
const DT:float=1.0/60.0
var cfg={"width":288,"height":240,"origin":[136,195],"density":3,"ink":0xff000000,"outline":3,
    "light":[-.48,-.64,.6],"seams":false,"materials":[
    [0xffe6ded7,0xffbdb3a8,0xff9e9081,0xff746759],
    [0xffa09d74,0xff827d50,0xff656139,0xff4a4628],
    [0xff655a4c,0xff50473b,0xff3c342c,0xff29231e]]}
var rigs=[]
var bodies=[]
var engines=[]
var sprites=[]
var old_joints=[]
var rows=[]
var players=[]
var phase_label:Label
var lane_labels=[]
var marks=[]
func _initialize():call_deferred("run")
func fail(reason:String)->void:
    push_error(reason)
    quit(1)
# Repeatable input-speed scenario; no clock dependency.
const FRAME_COUNT:int=366
static func speed_at(tick:int)->float:
    var w:float=smoothstep(48.,96.,float(tick))*(1.-smoothstep(222.,270.,float(tick)))
    return lerpf(Run.WALK_SPEED,Run.RUN_SPEED,w)

func run():
    var args=OS.get_cmdline_user_args()
    if args.size()!=1 or not ClassDB.class_exists("PixelFXBodyRaster"):
        quit(2)
        return
    var out:String=args[0]
    var fixtures=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/body_raster/poses.json"))
    var bank:Dictionary={}
    for f in fixtures.clips:
        if f.clip in ["run053a_C"]:
            var path:String=FIX+f.clip+".json"
            if FileAccess.get_sha256(path)!=f.sha256:
                fail("frozen clip SHA "+path)
                return
            bank[f.clip]=JSON.parse_string(FileAccess.get_file_as_string(path)).payload.clip
    if bank.size()!=1:
        fail("missing clips")
        return
    var run_clip:Dictionary=bank.run053a_C
    root.size=Vector2i(576,264)
    root.content_scale_size=root.size
    var bg=ColorRect.new()
    bg.color=Color("#34424d")
    bg.size=root.size
    root.add_child(bg)
    for lane in 2:
        rigs.append(Body.make_rig())
        bodies.append(Body.new(2))
        engines.append(ClassDB.instantiate("PixelFXBodyRaster"))
        var sp=Sprite2D.new()
        sp.centered=false
        sp.position=Vector2(lane*288,24)
        sp.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
        root.add_child(sp)
        sprites.append(sp)
        var label=Label.new()
        label.text=LABELS[lane]
        label.position=Vector2(lane*288+8,1)
        label.add_theme_font_size_override("font_size",12)
        root.add_child(label)
        lane_labels.append(label)
        old_joints.append({})
        players.append(Old.new(rigs[lane],run_clip) if lane==0 else Run.new(rigs[lane],run_clip))
    phase_label=Label.new()
    phase_label.position=Vector2(8,244)
    phase_label.add_theme_font_size_override("font_size",12)
    root.add_child(phase_label)
    if run_clip.keys.size()!=37 or absf(float(run_clip.duration)-.6)>.00001:
        fail("unexpected frozen run structure")
        return
    for k in range(0,36,3):
        for n in [1,2]:
            if run_clip.keys[k].pose!=run_clip.keys[k+n].pose:
                fail("expected held key group")
                return
    # Check replay from an arbitrary mid-ramp state with a fresh rig,
    # including future touchdown decisions and all pose fields.
    var probe=Run.new(Body.make_rig(),run_clip)
    for k in range(1,90):probe.advance(speed_at(k))
    var saved:Dictionary=probe.snapshot()
    var other=Run.new(Body.make_rig(),run_clip)
    other.restore(saved)
    for k in range(90,150):
        probe.advance(speed_at(k))
        other.advance(speed_at(k))
        if probe.snapshot()!=other.snapshot() or probe.sample()!=other.sample():
            fail("snapshot replay mismatch "+str(k))
            return
    if saved.travel>=probe.travel:
        fail("snapshot alias")
        return
    # Steady walk and long run plus ramp: dense input sweep at actual ticks.
    for speed in [Run.WALK_SPEED,Run.RUN_SPEED]:
        var steady=Run.new(Body.make_rig(),run_clip,speed)
        for k in 120:
            if k>0:steady.advance(speed)
            var trial:Dictionary=steady.sample()
            if trial.error>.01:
                fail("steady reach "+str([speed,k,trial.error]))
                return
            for name in Leg.SIDES:
                if not Leg.valid(trial.pose,name):
                    fail("steady joint limit "+str([speed,k,name]))
                    return
    for lane in 2:
        var line=Line2D.new()
        line.width=1.
        line.default_color=Color("#8ca1aa")
        line.points=PackedVector2Array([Vector2(lane*288+8,222.),Vector2(lane*288+280,222.)])
        line.z_index=-1
        root.add_child(line)
        var group:Array=[]
        for n in 13:
            var mark=Line2D.new()
            mark.width=1.
            mark.default_color=Color("#607480")
            mark.points=PackedVector2Array([Vector2(0.,222.),Vector2(0.,228.)])
            mark.z_index=-1
            root.add_child(mark)
            group.append(mark)
        marks.append(group)
    bg.z_index=-2
    var frame:int=0
    for tick in FRAME_COUNT:
            var input_speed:float=speed_at(tick)
            phase_label.text="60 Hz / TICK %03d / SPEED %.2f / %s"%[tick,input_speed,"FAST WALK" if input_speed<1.01 else ("FAST RUN" if input_speed>1.84 else "TRANSITION")]
            var record={"frame":frame,"tick":tick,"lanes":[]}
            for lane in 2:
                var rig=rigs[lane]
                var velocity:float=input_speed
                if tick>0:players[lane].advance(velocity)
                var travel:float=players[lane].travel
                for n in 13:
                    marks[lane][n].position.x=lane*288+8.+fposmod(n*25.-travel*3.,272.)
                var begin:int=Time.get_ticks_usec()
                var sample:Dictionary=players[lane].sample()
                var p:Dictionary=sample.pose
                var pose_us:int=Time.get_ticks_usec()-begin
                lane_labels[lane].text=LABELS[lane]+" / %.2f"%velocity
                if sample.error>.01:
                    fail("runtime target unreachable")
                    return
                rig.evaluate(p)
                var joints:Dictionary=rig.points.duplicate(true)
                var jump:float=0.
                for id in joints:
                    var v:Vector2=joints[id]
                    if not v.is_finite():
                        fail("non-finite FK")
                        return
                    if old_joints[lane].has(id):jump=maxf(jump,v.distance_to(old_joints[lane][id]))
                old_joints[lane]=joints
                var parts:Array=bodies[lane].make(joints,p.angles,rig.rotations.head)
                for i in [0,2,3,8,9]:parts[i].material_id=1
                for i in [5,6,7,11,12,13,15,17]:parts[i].material_id=2
                var result:Dictionary=engines[lane].render(cfg,parts)
                if not result.get("ok",false):
                    fail(str(result))
                    return
                var im=Image.create_from_data(result.width,result.height,false,Image.FORMAT_RGBA8,result.rgba)
                var bounds=im.get_used_rect()
                if bounds.size.x==0 or bounds.position.x<=0 or bounds.position.y<=0 or bounds.end.x>=288 or bounds.end.y>=240:
                    fail("empty/clipped "+str(bounds))
                    return
                if sprites[lane].texture==null:sprites[lane].texture=ImageTexture.create_from_image(im)
                else:sprites[lane].texture.update(im)
                var endpoints:Dictionary={}
                for id in ["hand_near","hand_far","foot_near","foot_far"]:
                    endpoints[id]=[joints[id].x,joints[id].y]
                for side in ["near","far"]:
                    var upper:float=Vector2(joints["thigh_"+side]).distance_to(joints["knee_"+side])
                    var lower:float=Vector2(joints["knee_"+side]).distance_to(joints["foot_"+side])
                    if absf(upper-sqrt(125.))>.0001 or absf(lower-sqrt(125.))>.0001:
                        fail("bone length changed")
                        return
                var knee:Dictionary={}
                var ankle:Dictionary={}
                var toes:Dictionary={}
                var stance:Dictionary={}
                var points:Dictionary={}
                for id in joints:points[id]=[joints[id].x,joints[id].y]
                for side in Leg.SIDES:
                    knee[side]=Leg.bend(p,side)
                    ankle[side]=Leg.ankle(p,side)
                    var toe:Vector2=Vector2(joints["foot_"+side])+IK.toe_vector(p,side)
                    toes[side]=[toe.x,toe.y]
                    stance[side]=bool(sample.goals[side].stance)
                    if not Leg.valid(p,side):
                        fail("leg constraint "+str([tick,lane,side,knee,ankle]))
                        return
                record.lanes.append({"knee":knee,"ankle":ankle,"toes":toes,"stance":stance,"travel_speed":velocity,"travel":travel,"step_distance":sample.step_distance,"root_drop":sample.drop,"gait":sample.gait,"foot_start":{"near":sample.goals.near.start,"far":sample.goals.far.start},"root_y":p.root[1],"points":points,"error":sample.error,"pose_us":pose_us,"joint_jump":jump,"raster_us":result.cpu_us})
            rows.append(record)
            await process_frame
            await RenderingServer.frame_post_draw
            if root.get_texture().get_image().save_png(out.path_join("frame-%03d.png"%frame))!=OK:
                fail("capture failed")
                return
            frame+=1
    var file=FileAccess.open(out.path_join("records.json"),FileAccess.WRITE)
    file.store_string(JSON.stringify(rows))
    print("ARMS_088_CAPTURE_OK frames=",frame)
    quit()
