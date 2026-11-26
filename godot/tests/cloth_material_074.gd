extends SceneTree
const Room=preload("res://lab/wind_room_072.gd")
const Cloth=preload("res://lab/secondary_motion_074.gd")
const LABELS=["A  /  0.72 CONTROL","B  /  SPATIAL WIND","C  /  SOFTER FABRIC"]
func _initialize():call_deferred("run")
func run():
    var args=OS.get_cmdline_user_args()
    if args.size()!=2 or not ClassDB.class_exists("PixelFXBodyRaster"):
        quit(2)
        return
    var out:String=args[0]
    var variant:int=int(args[1])
    if variant<0 or variant>2:
        quit(2)
        return
    root.size=Vector2i(480,270)
    root.content_scale_size=root.size
    var room=Room.new()
    room.manual=true
    room.cloth=Cloth.new()
    room.cloth.configure(variant)
    root.add_child(room)
    if room.failed!="":
        push_error(room.failed)
        quit(1)
        return
    var duplicate=Cloth.new()
    duplicate.configure(variant)
    duplicate.collisions=room.cloth.collisions.duplicate(true)
    duplicate.reset(room.anchor)
    for j in 480:duplicate.step(0.,false)
    var baseline:Dictionary=room.rig.points.duplicate(true)
    var geometry:Array=room.base.duplicate(true)
    var records:Array=[]
    var max_error:float=0.
    var max_replay:float=0.
    for frame in 240:
        var sec:float=frame/30.
        room.wind=0. if sec<2. or sec>=6. else 160.
        room.gust=sec>=4. and sec<6.
        var start:int=Time.get_ticks_usec()
        for j in 4:room.cloth.step(room.wind,room.gust)
        var physics:int=Time.get_ticks_usec()-start
        for j in 4:duplicate.step(room.wind,room.gust)
        for i in room.cloth.nodes.size():
            var v:Vector3=room.cloth.nodes[i]
            if not v.is_finite():
                push_error("non-finite cloth")
                quit(1)
                return
            max_replay=maxf(max_replay,v.distance_to(duplicate.nodes[i]))
        var err:float=room.cloth.error()
        max_error=maxf(max_error,err)
        if room.cloth.nodes[0]!=room.cloth.pins[0] or room.cloth.nodes[1]!=room.cloth.pins[1] or room.rig.points!=baseline or room.base!=geometry:
            push_error("pin/body invariant")
            quit(1)
            return
        if not room.render_frame():
            push_error(room.failed)
            quit(1)
            return
        room.status.text="LAB 0.74  /  "+LABELS[variant]
        var tip:Vector3=room.cloth.tip()-room.anchor
        var turn:float=0.
        for row in range(1,Cloth.ROWS-1):
            var a:Vector3=(room.cloth.nodes[2*(row-1)]+room.cloth.nodes[2*(row-1)+1])*.5
            var b:Vector3=(room.cloth.nodes[2*row]+room.cloth.nodes[2*row+1])*.5
            var c:Vector3=(room.cloth.nodes[2*(row+1)]+room.cloth.nodes[2*(row+1)+1])*.5
            if (b-a).length()>0.00001 and (c-b).length()>0.00001:turn+=(b-a).angle_to(c-b)
        records.append({"frame":frame,"wind":room.wind,"gust":room.gust,"tip":[tip.x,tip.y,tip.z],"strain":err,"curve_turn":turn,
            "physics_us":physics/4.,"prepare_us":room.prep_us,"raster_us":room.raster_us,"bridge_us":room.bridge_us,"cloth_pixels":room.cloth_pixels})
        await process_frame
        await RenderingServer.frame_post_draw
        if root.get_texture().get_image().save_png(out.path_join("frame-%03d.png"%frame))!=OK:
            quit(1)
            return
    var file=FileAccess.open(out.path_join("records.json"),FileAccess.WRITE)
    file.store_string(JSON.stringify({"rows":records,"max_strain":max_error,"replay_error":max_replay,"nodes":room.cloth.nodes.size(),"triangles":2*(Cloth.ROWS-1)}))
    print("CLOTH_074_CAPTURE_OK frames=",records.size()," strain=",max_error," replay=",max_replay)
    quit()
