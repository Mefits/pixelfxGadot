extends SceneTree
const Controller=preload("res://lab/motionphysics_controller.gd")
const Common=preload("res://lab/ragdoll_common_099c.gd")
func _initialize():call_deferred("run")
func fail(msg:String)->void:
    push_error(msg)
    quit(1)
func run()->void:
    if not ClassDB.class_exists("MotionPhysics099D") or not ClassDB.class_exists("PixelFXBodyRaster"):
        fail("native extensions missing")
        return
    root.size=Vector2i(960,540)
    root.content_scale_size=root.size
    var s=load("res://lab/motionphysics_studio.tscn").instantiate()
    s.manual=true
    root.add_child(s)
    if not s.last_ok:
        fail("initial render")
        return
    var initial:Array=s.controller.world.state()
    for t in 30:s.advance_tick()
    if initial!=s.controller.world.state():
        fail("pre-hit guard drift")
        return
    for profile in 3:
        s.set_profile(profile)
        s.hit_button.pressed.emit()
        if s.controller.event_count!=1 or s.controller.age!=0:
            fail("UI did not start event clock")
            return
        # Check exact replay including the hitstop clock and its inputs.
        var snap:Dictionary=s.controller.snapshot()
        var rows:Array=[]
        for t in 36:
            s.advance_tick()
            if not s.last_ok:
                fail("render profile "+str(profile))
                return
            rows.append(s.controller.world.state())
        if not s.controller.restore(snap):
            fail("wrapper restore")
            return
        for t in 36:
            s.advance_tick()
            if s.controller.world.state()!=rows[t]:
                fail("wrapper replay profile "+str(profile))
                return
        var metrics:Dictionary=Common.validate(s.controller.model)
        if metrics.anchor>=1. or metrics.penetration>=.6 or metrics.angle_error_deg>=8.:
            fail("profile constraints")
            return
    s.set_profile(1)
    s.partial.button_pressed=true
    s.target_select.select(3)
    s.hit_button.pressed.emit()
    if not s.controller.pinned or s.controller.event_count!=1:
        fail("partial UI")
        return
    var before:Array=s.controller.world.state()
    for t in 20:s.advance_tick()
    var after:Array=s.controller.world.state()
    for i in s.controller.n:
        if s.controller.lower(s.controller.model.bodies[i].id) and before[i]!=after[i]:
            fail("pinned segment moved")
            return
    var arm:int=s.controller.model.ids.hand_near
    if Vector2(before[arm][0],before[arm][1]).distance_to(Vector2(after[arm][0],after[arm][1]))<.5:
        fail("arm did not respond")
        return
    var snap:Dictionary=s.controller.snapshot()
    s.partial.button_pressed=false
    if s.controller.pinned or s.controller.world.state()!=after:
        fail("authority release discontinuity")
        return
    for t in 12:s.advance_tick()
    var end:Array=s.controller.world.state()
    if not s.controller.restore(snap) or not s.controller.set_pinned(false):
        fail("restore partial authority")
        return
    for t in 12:s.advance_tick()
    if s.controller.world.state()!=end:
        fail("authority release replay")
        return
    s.set_profile(1)
    s.target_select.select(0)
    s.hold.value=.45
    s.motor.value=.65
    s.hit_button.pressed.emit()
    if s.controller.settings.hold!=s.hold.value or s.controller.settings.motor!=s.motor.value:
        fail("custom parameters ignored")
        return
    for t in 12:s.advance_tick()
    var args:=OS.get_cmdline_user_args()
    if args.size()==1:
        await process_frame
        await RenderingServer.frame_post_draw
        if root.get_texture().get_image().save_png(args[0].path_join("box2d-studio.png"))!=OK:
            fail("UI capture")
            return
    print("MOTIONPHYSICS_STUDIO_OK")
    quit()
