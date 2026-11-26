extends SceneTree
const Body=preload("res://lab/body_ankle_069.gd")
const Clips=preload("res://addons/creature/clips.gd")
const Support=preload("res://lab/support_adaptation_077.gd")
const FIX="res://tests/fixtures/body_raster/full_058/"
const LABELS=["A / AUTHORED","B / FOOT IK","C / FOOT IK + PELVIS"]
const DT:float=1.0/60.0
var cfg={"width":288,"height":240,"origin":[128,200],"density":3,"ink":0xff000000,"outline":3,
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
var phase_label:Label
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
        if f.clip in ["combo052a2_B"]:
            var path:String=FIX+f.clip+".json"
            if FileAccess.get_sha256(path)!=f.sha256:
                fail("frozen clip SHA "+path)
                return
            bank[f.clip]=JSON.parse_string(FileAccess.get_file_as_string(path)).payload.clip
    if bank.size()!=1:
        fail("missing clips")
        return
    var combo:Dictionary=bank.combo052a2_B
    root.size=Vector2i(864,264)
    root.content_scale_size=root.size
    var bg=ColorRect.new()
    bg.color=Color("#34424d")
    bg.size=root.size
    root.add_child(bg)
    for lane in 3:
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
        old_joints.append({})
    phase_label=Label.new()
    phase_label.position=Vector2(8,244)
    phase_label.add_theme_font_size_override("font_size",12)
    root.add_child(phase_label)
    var reference=Body.make_rig()
    reference.evaluate(Clips.sample(combo,0.,false))
    var initial:Dictionary=reference.points.duplicate(true)
    reference.evaluate(Clips.sample(combo,64.*DT,false))
    var landing:Dictionary=reference.points.duplicate(true)
    # Visual guide for two different support heights; no terrain physics yet.
    for lane in 3:
        var line=Line2D.new()
        line.width=1.
        line.default_color=Color("#8ca1aa")
        var step_x:float=lane*288+128.+7.*3.
        var low:float=224.+3.
        var high:float=low-2.5*3.
        line.points=PackedVector2Array([Vector2(lane*288+8,low),Vector2(step_x,low),Vector2(step_x,high),Vector2(lane*288+280,high)])
        line.z_index=-1
        root.add_child(line)
    bg.z_index=-2
    var frame:int=0
    # Two final exposures give an even frame count for the normal 30Hz GIF.
    for tick in 78:
            var t:float=minf(float(tick),76.)
            var target:Dictionary=Clips.sample(combo,t*DT,false)
            var event:bool=false
            var anchor:String=""
            for e in combo.events:
                if roundi(float(e.t)*60.)==tick:
                    event=true
                    anchor=e.anchor
            phase_label.text="COMBO / TICK %02d / %s"%[tick,"STRIKE "+anchor if event else "60 Hz"]
            var record={"frame":frame,"segment":0,"tick":tick,"event":event,"anchor":anchor,"lanes":[]}
            for lane in 3:
                var rig=rigs[lane]
                var adapted:Dictionary=Support.adapt(rig,target,t,initial,landing,lane)
                var p:Dictionary=adapted.pose
                if lane==0 and p!=target:
                    fail("authored control changed")
                    return
                for id in target.angles:
                    if not id.begins_with("thigh_") and not id.begins_with("knee_") and p.angles[id]!=target.angles[id]:
                        fail("unrelated angle changed "+id)
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
                var goal:Dictionary=adapted.goal
                var e_near:float=Vector2(joints.foot_near).distance_to(goal.near)
                var e_far:float=Vector2(joints.foot_far).distance_to(goal.far)
                for side in ["near","far"]:
                    var upper:float=Vector2(joints["thigh_"+side]).distance_to(joints["knee_"+side])
                    var lower:float=Vector2(joints["knee_"+side]).distance_to(joints["foot_"+side])
                    if absf(upper-sqrt(125.))>.0001 or absf(lower-sqrt(125.))>.0001:
                        fail("bone length changed")
                        return
                var shift:Vector2=Support.root_of(p)-Support.root_of(target)
                if shift.length()>4.001:
                    fail("root bound")
                    return
                record.lanes.append({"airborne":goal.airborne,"near_error":e_near,"far_error":e_far,"pelvis_support_dx":absf(Vector2(joints.hips).x-Vector2(goal.near).x),"root_shift":[shift.x,shift.y],"endpoints":endpoints,"joint_jump":jump,"raster_us":result.cpu_us,"root":p.root,"foot_near":[joints.foot_near.x,joints.foot_near.y],"foot_far":[joints.foot_far.x,joints.foot_far.y]})
            rows.append(record)
            await process_frame
            await RenderingServer.frame_post_draw
            if root.get_texture().get_image().save_png(out.path_join("frame-%03d.png"%frame))!=OK:
                fail("capture failed")
                return
            frame+=1
    var file=FileAccess.open(out.path_join("records.json"),FileAccess.WRITE)
    file.store_string(JSON.stringify(rows))
    print("SUPPORT_077_CAPTURE_OK frames=",frame)
    quit()
