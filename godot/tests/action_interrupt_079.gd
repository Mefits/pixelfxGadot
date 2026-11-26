extends SceneTree
const Body=preload("res://lab/body_ankle_069.gd")
const Clips=preload("res://addons/creature/clips.gd")
const Player=preload("res://lab/action_interrupt_079.gd")
const FIX="res://tests/fixtures/body_raster/full_058/"
const LABELS=["A / DIRECT CUT","B / INERTIAL","C / CONTACT + PHASE"]
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
var players=[]
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
        if f.clip in ["combo052a2_B","run053a_C"]:
            var path:String=FIX+f.clip+".json"
            if FileAccess.get_sha256(path)!=f.sha256:
                fail("frozen clip SHA "+path)
                return
            bank[f.clip]=JSON.parse_string(FileAccess.get_file_as_string(path)).payload.clip
    if bank.size()!=2:
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
        players.append(Player.new(rigs[lane],lane))
    phase_label=Label.new()
    phase_label.position=Vector2(8,244)
    phase_label.add_theme_font_size_override("font_size",12)
    root.add_child(phase_label)
    var run_clip:Dictionary=bank.run053a_C
    var actions:Dictionary={
        "JAB":{"name":"JAB","clip":combo,"first":0,"last":22,"loop":false},
        "CROSS":{"name":"CROSS","clip":combo,"first":23,"last":37,"loop":false},
        "KICK":{"name":"KICK","clip":combo,"first":38,"last":76,"loop":false},
        "RUN":{"name":"RUN","clip":run_clip,"first":0,"last":36,"loop":true}}
    var commands:Dictionary={0:"JAB",16:"CROSS",30:"KICK",45:"RUN",50:"JAB",75:"RUN"}
    for lane in 3:
        var line=Line2D.new()
        line.width=1.
        line.default_color=Color("#8ca1aa")
        line.points=PackedVector2Array([Vector2(lane*288+8,227.),Vector2(lane*288+280,227.)])
        line.z_index=-1
        root.add_child(line)
    bg.z_index=-2
    var frame:int=0
    for tick in 100:
            var switched:bool=commands.has(tick)
            if switched:
                for player in players:player.command(actions[commands[tick]])
            phase_label.text="TICK %02d  /  %s%s"%[tick,"COMMAND: "+str(commands[tick]) if switched else str(players[0].action.name),"  /  60 Hz"]
            var record={"frame":frame,"tick":tick,"switch":switched,"lanes":[]}
            for lane in 3:
                var rig=rigs[lane]
                var sample:Dictionary=players[lane].step()
                var p:Dictionary=sample.pose
                if sample.local>=Player.TRANSITION and p!=sample.target:
                    fail("transition not converged")
                    return
                if sample.events.size()>0 and p!=sample.target:
                    fail("contact pose changed")
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
                if sample.lock_error>.20:
                    fail("unreachable support "+str([tick,sample.lock_error]))
                    return
                record.lanes.append({"instance":sample.instance,"action":sample.action,"local":sample.local,"source":sample.source,"phase":sample.phase,"events":sample.events,"lock_count":sample.lock_count,"lock_error":sample.lock_error,"selected_locks":sample.selected_locks,"joint_jump":jump,"raster_us":result.cpu_us,"root":p.root,"endpoints":endpoints})
            rows.append(record)
            await process_frame
            await RenderingServer.frame_post_draw
            if root.get_texture().get_image().save_png(out.path_join("frame-%03d.png"%frame))!=OK:
                fail("capture failed")
                return
            frame+=1
    var file=FileAccess.open(out.path_join("records.json"),FileAccess.WRITE)
    file.store_string(JSON.stringify(rows))
    print("INTERRUPT_079_CAPTURE_OK frames=",frame)
    quit()
