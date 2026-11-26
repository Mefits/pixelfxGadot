extends SceneTree
const Body=preload("res://lab/body_ankle_069.gd")
const Reaction=preload("res://lab/impact_impulse_098.gd")
const Control097=preload("res://lab/impact_ragdoll_097.gd")
const Leg=preload("res://lab/leg_constraints_082.gd")
const FIX="res://tests/fixtures/body_raster/full_058/combo052a2_B.json"
const LABELS=["A / IMPULSE x1","B / IMPULSE x3","C / IMPULSE x5"]
const EVENTS={18:["BODY",1.]}
const FRAMES:int=360
var cfg={"width":520,"height":540,"origin":[380,485],"density":3,"ink":0xff000000,"outline":3,"light":[-.48,-.64,.6],"seams":false,"materials":[[0xffe6ded7,0xffbdb3a8,0xff9e9081,0xff746759],[0xffa09d74,0xff827d50,0xff656139,0xff4a4628],[0xff655a4c,0xff50473b,0xff3c342c,0xff29231e]]}
func _initialize():call_deferred("run")
func fail(reason:String)->void:
    push_error(reason)
    quit(1)
func input_at(player,t:int)->void:
    if EVENTS.has(t):
        player.strike(t,"BODY",-1.,1.45,2)
func run():
    var args=OS.get_cmdline_user_args()
    if args.size()!=1 or not ClassDB.class_exists("PixelFXBodyRaster"):
        quit(2)
        return
    var fixture=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/body_raster/poses.json"))
    var verified:bool=false
    for f in fixture.clips:
        if f.clip=="combo052a2_B":verified=FileAccess.get_sha256(FIX)==f.sha256
    if not verified:
        fail("frozen guard SHA mismatch")
        return
    var source:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(FIX)).payload.clip.keys[0].pose
    var min_y:float=0.
    for mode in 3:
        for cut in [29,160,260]:
            var a=Reaction.new(Body.make_rig(),source,mode)
            var b=Reaction.new(Body.make_rig(),source,mode)
            for t in cut:
                input_at(a,t)
                a.step()
                for point in a.rig.points.values():min_y=minf(min_y,Vector2(point).y)
            b.restore(a.snapshot())
            if cut>18 and b.strike(18,"BODY",-1.,1.45,2):
                fail("duplicate accepted")
                return
            for t in range(cut,FRAMES):
                input_at(a,t)
                input_at(b,t)
                if a.step()!=b.step() or a.snapshot()!=b.snapshot():
                    fail("replay mismatch "+str([mode,cut,t]))
                    return
                for point in a.rig.points.values():min_y=minf(min_y,Vector2(point).y)
    var control=Control097.new(Body.make_rig(),source,2)
    var local=Reaction.new(Body.make_rig(),source,0)
    for frame in FRAMES:
        input_at(control,frame)
        input_at(local,frame)
        if control.step().pose!=local.step().pose:
            fail("097 C control regression "+str(frame))
            return
    # The replay above samples every joint in all three actual trajectories.
    # One shared vertical framing, plus 54 pixels for the full raster skin.
    # Keep the original density and ground reference; never move the body.
    var origin_y:int=maxi(485,ceili(-min_y*3.)+54)
    var view_h:int=origin_y+55
    cfg.height=view_h
    print("CAPTURE_BOUNDS min_joint_y=",min_y," origin_y=",origin_y," lane_height=",view_h)
    root.size=Vector2i(1560,view_h+32)
    root.content_scale_size=root.size
    var bg=ColorRect.new()
    bg.color=Color("#34424d")
    bg.size=root.size
    bg.z_index=-2
    root.add_child(bg)
    var players:Array=[]
    var bodies:Array=[]
    var engines:Array=[]
    var sprites:Array=[]
    var arrows:Array=[]
    var grids:Array=[]
    var meters:Array=[]
    var old:Array=[{}, {}, {}]
    var rows:Array=[]
    for lane in 3:
        players.append(Reaction.new(Body.make_rig(),source,lane))
        bodies.append(Body.new(2))
        engines.append(ClassDB.instantiate("PixelFXBodyRaster"))
        var sp=Sprite2D.new()
        sp.centered=false
        sp.position=Vector2(lane*520,24)
        sp.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
        root.add_child(sp)
        sprites.append(sp)
        var label=Label.new()
        label.text=LABELS[lane]
        label.position=Vector2(lane*520+8,1)
        label.add_theme_font_size_override("font_size",14)
        root.add_child(label)
        var floor_line=Line2D.new()
        floor_line.width=1.
        floor_line.default_color=Color("#8ca1aa")
        var floor_px:float=float(origin_y)+24.+players[lane].floor_y*3.
        floor_line.points=PackedVector2Array([Vector2(lane*520+8,floor_px),Vector2(lane*520+512,floor_px)])
        floor_line.z_index=-1
        root.add_child(floor_line)
        var grid=Line2D.new()
        grid.width=1.
        grid.default_color=Color("#8ca1aa")
        grid.z_index=-1
        root.add_child(grid)
        grids.append(grid)
        var meter=Label.new()
        meter.position=Vector2(lane*520+8,view_h-14)
        meter.add_theme_font_size_override("font_size",13)
        root.add_child(meter)
        meters.append(meter)
        var arrow=Line2D.new()
        arrow.width=2.
        arrow.default_color=Color("#ffb66d")
        arrow.z_index=2
        root.add_child(arrow)
        arrows.append(arrow)
    var caption=Label.new()
    caption.position=Vector2(8,view_h+8)
    caption.add_theme_font_size_override("font_size",14)
    root.add_child(caption)
    var last:int=-100
    var zone:String=""
    for t in FRAMES:
        if EVENTS.has(t):
            last=t
            zone=EVENTS[t][0]
        caption.text="60 Hz / %03d / SAME RIG + TONE + FRICTION / HORIZONTAL CAMERA FOLLOWS BODY"%t
        var record:Dictionary={"tick":t,"lanes":[]}
        for lane in 3:
            var player=players[lane]
            input_at(player,t)
            var start:int=Time.get_ticks_usec()
            var sample:Dictionary=player.step()
            var pose_us:int=Time.get_ticks_usec()-start
            var p:Dictionary=sample.pose
            var rig=player.rig
            if sample.error>.01:
                fail("ankle drift "+str([lane,t,sample.error]))
                return
            for side in Leg.SIDES:
                if not Leg.valid(p,side):
                    fail("leg limit "+str([lane,t,side,Leg.bend(p,side),Leg.ankle(p,side)]))
                    return
            var q:Dictionary=rig.points.duplicate(true)
            var points:Dictionary={}
            var jump:float=0.
            for joint in rig.joints:
                var id:String=joint.id
                var point:Vector2=q[id]
                if not point.is_finite():
                    fail("nonfinite")
                    return
                if not String(joint.parent).is_empty():
                    if absf(point.distance_to(q[joint.parent])-Vector2(joint.offset).length())>.0002:
                        fail("bone length "+id)
                        return
                if old[lane].has(id):jump=maxf(jump,point.distance_to(old[lane][id]))
                points[id]=[point.x,point.y]
            old[lane]=q
            var parts:Array=bodies[lane].make(q,p.angles,rig.rotations.head)
            for i in [0,2,3,8,9]:parts[i].material_id=1
            for i in [5,6,7,11,12,13,15,17]:parts[i].material_id=2
            # Common 3px/unit scale, horizontal camera only. A world-space
            # ruler and numerical displacement keep travel legible.
            var camera:float=minf(0.,sample.com.x+12.)
            var min_x:float=INF
            var max_x:float=-INF
            for point in q.values():
                min_x=minf(min_x,Vector2(point).x)
                max_x=maxf(max_x,Vector2(point).x)
            var origin_x:float=clampf(380.-camera*3.,54.-min_x*3.,466.-max_x*3.)
            camera=(380.-origin_x)/3.
            cfg.origin=[origin_x,float(origin_y)]
            var marks:=PackedVector2Array()
            # draw floor ticks with separate short strokes linked along floor
            var floor_screen:float=float(origin_y)+24.+player.floor_y*3.
            for k in range(-60,12):
                var x:float=380.+(float(k)*10.-camera)*3.
                if x>=10. and x<=510.:
                    var px:float=lane*520+x
                    marks.append(Vector2(px,floor_screen))
                    marks.append(Vector2(px,floor_screen+5.))
                    marks.append(Vector2(px,floor_screen))
            grids[lane].points=marks
            meters[lane].text="COM X %+.1f  /  10-unit floor ticks"%sample.com.x
            var result:Dictionary=engines[lane].render(cfg,parts)
            if not result.get("ok",false):
                fail(str(result))
                return
            var im=Image.create_from_data(result.width,result.height,false,Image.FORMAT_RGBA8,result.rgba)
            var bounds=im.get_used_rect()
            if bounds.size.x==0 or bounds.position.x<=0 or bounds.position.y<=0 or bounds.end.x>=520 or bounds.end.y>=view_h:
                fail("empty or clipped "+str([lane,t,bounds,view_h,cfg.origin,sample.com]))
                return
            if sprites[lane].texture==null:sprites[lane].texture=ImageTexture.create_from_image(im)
            else:sprites[lane].texture.update(im)
            arrows[lane].visible=t-last<5
            if arrows[lane].visible:
                var target:Vector2=q.head if zone=="HEAD" else Vector2(q.chest).lerp(q.hips,.55)
                var end:Vector2=Vector2(lane*520+origin_x,float(origin_y)+24.)+target*3.+Vector2(10,0)
                arrows[lane].points=PackedVector2Array([end+Vector2(26,0),end,end+Vector2(7,-5),end,end+Vector2(7,5)])
            record.lanes.append({"phase":sample.phase,"moving":sample.moving,"swing":sample.swing,"anchors":{"near":[sample.anchors.near.x,sample.anchors.near.y],"far":[sample.anchors.far.x,sample.anchors.far.y]},"points":points,"offset":sample.offset,"velocity":sample.energy_proxy,"error":sample.error,"accepted":sample.accepted,"pose_us":pose_us,"joint_jump":jump,"support_count":sample.support_count,"clearance":sample.clearance,"steps":sample.steps,"slip":sample.slip,"contact_joint":sample.contact_joint,"slide":sample.slide,"angles":p.angles.duplicate(true),"raster_bottom":bounds.end.y,"raster_origin_y":origin_y,"floor_y":player.floor_y,"physics_contacts":sample.physics_contacts,"touched":sample.touched,"motor":sample.motor,"physics_anchor_error":sample.physics_anchor_error,"physics_penetration":sample.physics_penetration,"physics_pose_error":sample.physics_pose_error,"physics_peak_speed":sample.physics_peak_speed,"com":[sample.com.x,sample.com.y],"tone_impulse":sample.tone_impulse,"friction_impulse":sample.friction_impulse})
        rows.append(record)
        await process_frame
        await RenderingServer.frame_post_draw
        if root.get_texture().get_image().save_png(args[0].path_join("frame-%03d.png"%t))!=OK:
            fail("capture failed")
            return
    var file=FileAccess.open(args[0].path_join("records.json"),FileAccess.WRITE)
    file.store_string(JSON.stringify(rows))
    print("IMPACT_098_CAPTURE_OK frames=",FRAMES)
    quit()
