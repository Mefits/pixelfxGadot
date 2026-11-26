extends SceneTree
const Body=preload("res://lab/body_ankle_069.gd")
const Clips=preload("res://addons/creature/clips.gd")
const Run=preload("res://lab/sprint_impulse_086.gd")
const IK=preload("res://lab/support_adaptation_077.gd")
const Leg=preload("res://lab/leg_constraints_082.gd")
const FIX="res://tests/fixtures/body_raster/full_058/"
const LABELS=["A / 085 SPORT","B / SPORT IMPULSE","C / 085 ANIME","D / ANIME IMPULSE"]
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
    root.size=Vector2i(1152,264)
    root.content_scale_size=root.size
    var bg=ColorRect.new()
    bg.color=Color("#34424d")
    bg.size=root.size
    root.add_child(bg)
    for lane in 4:
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
        players.append(Run.new(rigs[lane],run_clip))
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
    # Dense feasibility and reproducibility of both profiles on actual rig.
    for lane in [1,3]:
        for k in range(361):
            var trial:Dictionary=players[lane].sample(k/10.,lane)
            if trial.error>.01:
                fail("procedural reach "+str([lane,k,trial.error]))
                return
            for side in Leg.SIDES:
                if not Leg.valid(trial.pose,side):
                    fail("procedural angle limit "+str([lane,k,side]))
                    return
        for k in 36:
            var first:Dictionary=players[lane].sample(float(k),lane)
            var other:Dictionary=Run.new(Body.make_rig(),run_clip).sample(float(k),lane)
            if first!=other:
                fail("same-process independent sampler mismatch")
                return
    for lane in 4:
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
    for tick in 72:
            phase_label.text="RUN / TICK %02d / 60 Hz / A+B+C: 1.45, D: 1.55 units per tick"%posmod(tick,36)
            var record={"frame":frame,"tick":tick,"lanes":[]}
            for lane in 4:
                for n in 13:
                    marks[lane][n].position.x=lane*288+8.+fposmod(n*25.-tick*Run.speed_for(lane)*3.,272.)
                var rig=rigs[lane]
                var begin:int=Time.get_ticks_usec()
                var sample:Dictionary=players[lane].sample(float(tick),lane)
                var p:Dictionary=sample.pose
                var pose_us:int=Time.get_ticks_usec()-begin
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
                    stance[side]=bool(Run.foot_path(float(tick)/Run.PERIOD+(.5 if side=="far" else 0.),lane).stance)
                    if not Leg.valid(p,side):
                        fail("leg constraint "+str([tick,lane,side,knee,ankle]))
                        return
                record.lanes.append({"knee":knee,"ankle":ankle,"toes":toes,"stance":stance,"travel_speed":Run.speed_for(lane),"root_y":p.root[1],"points":points,"error":sample.error,"pose_us":pose_us,"joint_jump":jump,"raster_us":result.cpu_us})
            rows.append(record)
            await process_frame
            await RenderingServer.frame_post_draw
            if root.get_texture().get_image().save_png(out.path_join("frame-%03d.png"%frame))!=OK:
                fail("capture failed")
                return
            frame+=1
    var file=FileAccess.open(out.path_join("records.json"),FileAccess.WRITE)
    file.store_string(JSON.stringify(rows))
    print("IMPULSE_086_CAPTURE_OK frames=",frame)
    quit()
