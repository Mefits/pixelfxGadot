extends SceneTree
const Bridge=preload("res://lab/astra_box2d_handoff.gd")
const Body=preload("res://lab/body_ankle_069.gd")
const Common=preload("res://lab/ragdoll_common_099c.gd")
const CFG={"width":1200,"height":420,"origin":[100,310],"density":3,"ink":0xff000000,"outline":3,"light":[-.48,-.64,.6],"seams":false,"materials":[[0xffe6ded7,0xffbdb3a8,0xff9e9081,0xff746759],[0xffa09d74,0xff827d50,0xff656139,0xff4a4628],[0xff655a4c,0xff50473b,0xff3c342c,0xff29231e],[0xffd8b2a0,0xffab8173,0xff7d574a,0xff523b32]]}
var failures:Array=[]
func _initialize():call_deferred("run")
func check(ok:bool,msg:String)->void:
    if not ok:failures.append(msg)
func commands(b)->Array:
    var c:Array=[]
    for i in b.players.size():
        var cmd:Dictionary={"speed":1.85 if i==0 and b.release_tick<0 else (0. if i==0 else 1.)}
        if b.pair and i==0 and b.tick==38:cmd.action="jab"
        c.append(cmd)
    return c
func replay(b,count:int)->void:
    var snap:Dictionary=b.snapshot()
    var states:Array=[]
    for t in count:
        check(b.step(commands(b)),"forward step")
        states.append([b.world.state(),b.world.state_hash(),b.release_tick,b.attacker_release_tick,b.contact_tick,b.contact_impulse])
    check(b.restore(snap),"restore")
    for t in count:
        check(b.step(commands(b)),"replay step")
        check(states[t]==[b.world.state(),b.world.state_hash(),b.release_tick,b.attacker_release_tick,b.contact_tick,b.contact_impulse],"exact replay "+str(t))
    check(b.restore(snap),"restore end")

func run()->void:
    var args:=OS.get_cmdline_user_args()
    if args.size()<1 or not ClassDB.class_exists("MotionPhysics099D") or not ClassDB.class_exists("PixelFXBodyRaster"):
        quit(2)
        return
    var out:String=args[0]
    var capture:bool=args.size()>1 and args[1]=="capture"
    var solo=Bridge.new()
    if not solo.setup(false):
        push_error("solo setup")
        quit(1)
        return
    for t in 72:check(solo.step(commands(solo)),"solo step")
    replay(solo,12)
    check(solo.track_error<.05,"moving support tracking "+str(solo.track_error))
    check(solo.release(),"solo release")
    check(solo.release_error<.001,"solo release continuity")
    replay(solo,12)
    for t in 96:check(solo.step(commands(solo)),"solo dynamic")
    var b=Bridge.new()
    if not b.setup(true):
        push_error("pair setup")
        quit(1)
        return
    root.size=Vector2i(1200,450)
    root.content_scale_size=root.size
    var bg:=ColorRect.new()
    bg.color=Color("#34424d")
    bg.size=Vector2(1200,450)
    root.add_child(bg)
    var floor_line:=Line2D.new()
    floor_line.default_color=Color("#8ca1aa")
    floor_line.width=1.
    floor_line.points=PackedVector2Array([Vector2(0,310.+b.floor_y*3.+22),Vector2(1200,310.+b.floor_y*3.+22)])
    root.add_child(floor_line)
    var sp:=Sprite2D.new()
    sp.centered=false
    sp.position=Vector2(0,22)
    sp.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
    root.add_child(sp)
    var label:=Label.new()
    label.position=Vector2(8,0)
    root.add_child(label)
    var raster=ClassDB.instantiate("PixelFXBodyRaster")
    var body=Body.new(2)
    var cfg:Dictionary=CFG.duplicate(true)
    var records:Array=[]
    var times:Array=[]
    var peak_anchor:float=0.
    var peak_precontact_anchor:float=0.
    var peak_floor:float=0.
    var peak_limit:float=0.
    var worst_anchor_tick:int=-1
    for t in 360:
        if t in [12,80,180]:replay(b,12)
        var start:int=Time.get_ticks_usec()
        if not b.step(commands(b)):
            failures.append("pair step "+str(t))
            break
        times.append(Time.get_ticks_usec()-start)
        var poses:Array=b.poses()
        var parts:Array=[]
        for c in 2:
            var m=b.models[c]
            var p:Dictionary=poses[c]
            var metrics:Dictionary=Common.validate(m)
            if c==1:
                if b.contact_tick<0:peak_precontact_anchor=maxf(peak_precontact_anchor,metrics.anchor)
                if metrics.anchor>peak_anchor:
                    peak_anchor=metrics.anchor
                    worst_anchor_tick=t
                peak_floor=maxf(peak_floor,metrics.penetration)
                peak_limit=maxf(peak_limit,metrics.angle_error_deg)
            if capture and t%2==1:
                var mesh:Array=body.make(m.rig.points,p.angles,m.rig.rotations.head)
                for i in mesh.size():mesh[i].material_id=(1 if c==0 else 3) if i in [0,2,3,8,9] else (2 if i in [5,6,7,11,12,13,15,17] else 0)
                parts.append_array(mesh)
        records.append({"tick":t,"state":b.world.state(),"contact":b.contacts,"release":b.release_tick,"attacker_release":b.attacker_release_tick})
        if capture and t%2==1:
            var result:Dictionary=raster.render(cfg,parts)
            if not result.get("ok",false):
                failures.append("raster "+str(t))
                break
            var im:=Image.create_from_data(result.width,result.height,false,Image.FORMAT_RGBA8,result.rgba)
            var bounds:Rect2i=im.get_used_rect()
            if bounds.size.x==0 or bounds.position.x<=0 or bounds.position.y<=0 or bounds.end.x>=1200 or bounds.end.y>=420:
                failures.append("capture bounds "+str(t)+" "+str(bounds))
            if sp.texture==null:sp.texture=ImageTexture.create_from_image(im)
            else:sp.texture.update(im)
            label.text="ASTRA -> BOX2D | 120 Hz | tick %03d | contact %d | release %d | impulse %.1f"%[t,b.contact_tick,b.release_tick,b.contact_impulse]
            await process_frame
            await RenderingServer.frame_post_draw
            if root.get_texture().get_image().save_png(out.path_join("frame-%03d.png"%((t-1)/2)))!=OK:
                failures.append("capture failed")
                break
    check(b.contact_tick>=0,"no cross-fighter normal impulse")
    check(b.attacker_release_tick>=0 and b.attacker_release_tick<b.contact_tick,"attacker not finite mass before contact")
    check(b.attacker_release_error<.001,"attacker release continuity")
    check(b.release_tick>=b.contact_tick and b.release_tick>=0,"no contact-triggered release")
    check(b.release_error<.001,"pair release continuity "+str(b.release_error))
    check(b.track_error<.05,"pair tracking "+str(b.track_error))
    check(peak_precontact_anchor<1.,"precontact anchor residual "+str(peak_precontact_anchor))
    check(peak_anchor<3.,"pair anchor residual "+str(peak_anchor))
    check(peak_floor<3.,"pair floor residual "+str(peak_floor))
    check(peak_limit<30.,"pair angle residual "+str(peak_limit))
    times.sort()
    var report:Dictionary={"solo_tracking":solo.track_error,"solo_release_error":solo.release_error,"pair_tracking":b.track_error,"pair_release_error":b.release_error,"attacker_release_tick":b.attacker_release_tick,"attacker_release_error":b.attacker_release_error,"contact_tick":b.contact_tick,"release_tick":b.release_tick,"normal_impulse_sum":b.contact_impulse,"peak_anchor":peak_anchor,"peak_precontact_anchor":peak_precontact_anchor,"worst_anchor_tick":worst_anchor_tick,"peak_floor":peak_floor,"peak_angle_deg":peak_limit,"p95_us":times[int(.95*times.size())] if not times.is_empty() else -1,"failures":failures}
    var f:=FileAccess.open(out.path_join("report.json"),FileAccess.WRITE)
    f.store_string(JSON.stringify(report))
    f.close()
    f=FileAccess.open(out.path_join("trace.json"),FileAccess.WRITE)
    f.store_string(JSON.stringify(records))
    f.close()
    print("ASTRA_BOX2D_REPORT ",JSON.stringify(report))
    print("ASTRA_BOX2D_CAPTURE_DONE")
    quit(0 if failures.is_empty() else 1)
