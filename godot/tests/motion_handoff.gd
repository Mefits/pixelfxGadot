extends SceneTree
const Handoff=preload("res://lab/motion_handoff.gd")
var failure:String=""
func _initialize():call_deferred("run")
func check(ok:bool,reason:String)->bool:
    if not ok and failure.is_empty():failure=reason
    return ok
func distance(a:Dictionary,b:Dictionary)->float:
    var d:float=0.
    for key in a:d=maxf(d,Vector2(a[key]).distance_to(b[key]))
    return d
func trace(h)->Array:
    return [h.phase,h.pose.duplicate(true),h.travel,h.player.save(),h.physics.world.state() if h.physics.world!=null else []]
func replay(h,count:int)->bool:
    var snap:Dictionary=h.snapshot()
    var records:Array=[]
    for t in count:
        if not h.step({"speed":0.}):return false
        records.append(trace(h))
    if not h.restore(snap):return false
    for t in count:
        if not h.step({"speed":0.}) or trace(h)!=records[t]:return false
    return h.restore(snap)
func run()->void:
    if not ClassDB.class_exists("MotionPhysics099D") or not ClassDB.class_exists("PixelFXBodyRaster"):
        push_error("native modules missing")
        quit(1)
        return
    root.size=Vector2i(960,540)
    root.content_scale_size=root.size
    var s=load("res://lab/hybrid_studio.tscn").instantiate()
    s.manual=true
    root.add_child(s)
    if not s.last_ok:
        push_error("initial H render")
        quit(1)
        return
    var args:=OS.get_cmdline_user_args()
    var capture:bool=args.size()==1
    var frame:int=0
    var reports:Array=[]
    for scenario in ["walk","sprint","attack"]:
        s.reset()
        s.target_speed=1. if scenario=="walk" else 1.85
        for t in 96:
            if scenario=="attack" and t==88:s.queue_action("jab")
            s.advance_tick()
            if capture and scenario=="sprint" and t>=66:
                await process_frame
                await RenderingServer.frame_post_draw
                if root.get_texture().get_image().save_png(args[0].path_join("frame-%04d.png"%frame))!=OK:
                    failure="capture write"
                    break
                frame+=1
        if not failure.is_empty():break
        var h=s.handoff
        var before:Dictionary=h.points(h.pose,h.travel)
        var start_x:float=h.travel+float(h.pose.root[0])
        var moving:float=absf(h.travel-h.previous_travel)
        if not check(moving>.1,"entry was not moving"):break
        # UI queue must take the actual resolved pose, not reset the guard.
        s.queue_physics_hit()
        s.advance_tick()
        if not check(h.phase==Handoff.PHYSICS,"UI handoff rejected "+h.message):break
        if not check(h.entry_error<.02 and h.velocity_error<.02,"entry conversion error"):break
        if not check(h.velocity_clamps==0,"entry velocities unexpectedly clamped"):break
        var first:Dictionary=h.points(h.pose,h.travel)
        if not check(distance(before,first)<.02,"hitstop entry jumped"):break
        if not check(h.player.action=="" and h.player.events.is_empty(),"interrupted attack not cancelled"):break
        var entered_recovery:bool=false
        var recovered:bool=false
        var max_recovery_step:float=0.
        var recovery_end_step:float=0.
        var ticks:int=0
        var old:Dictionary=first
        if not check(replay(h,18),"physical wrapper replay"):break
        for t in 600:
            var old_phase:int=h.phase
            s.advance_tick()
            ticks+=1
            if not check(s.last_ok,"native render after transfer"):break
            var now:Dictionary=h.points(h.pose,h.travel)
            var delta:float=distance(old,now)
            if not check(is_finite(delta),"nonfinite world pose"):break
            if h.phase==Handoff.RECOVERY and not entered_recovery:
                entered_recovery=true
                if not check(h.quiet_ticks>=12,"returned before settling"):break
                if not check(replay(h,Handoff.RECOVERY_TICKS+3),"recovery-to-Astra replay"):break
            if old_phase==Handoff.RECOVERY:
                max_recovery_step=maxf(max_recovery_step,delta)
                if h.phase==Handoff.ASTRA:recovery_end_step=delta
            old=now
            if capture and scenario=="sprint":
                await process_frame
                await RenderingServer.frame_post_draw
                if root.get_texture().get_image().save_png(args[0].path_join("frame-%04d.png"%frame))!=OK:
                    failure="capture write"
                    break
                frame+=1
            if entered_recovery and h.phase==Handoff.ASTRA:
                recovered=true
                break
        if not check(recovered,"no return from "+scenario):break
        if not check(max_recovery_step<8. and recovery_end_step<1.,"recovery joint discontinuity "+str([max_recovery_step,recovery_end_step])):break
        var end_x:float=h.travel+float(h.pose.root[0])
        if not check(absf(end_x-start_x)>1.,"world displacement lost"):break
        var resumed:float=h.travel
        for t in 30:
            s.advance_tick()
            if capture and scenario=="sprint":
                await process_frame
                await RenderingServer.frame_post_draw
                if root.get_texture().get_image().save_png(args[0].path_join("frame-%04d.png"%frame))!=OK:
                    failure="capture write"
                    break
                frame+=1
        if not check(h.travel>resumed+1.,"Astra did not resume movement"):break
        reports.append({"scenario":scenario,"entry_error":h.entry_error,"entry_velocity_error":h.velocity_error,"velocity_clamps":h.velocity_clamps,"return_ticks":ticks,"recovery_max_joint_step":max_recovery_step,"recovery_end_joint_step":recovery_end_step,"world_displacement":end_x-start_x})
    print("HANDOFF_REPORT ",JSON.stringify(reports))
    if not failure.is_empty():
        push_error(failure)
        quit(1)
        return
    if reports.size()!=3:
        push_error("incomplete scenarios")
        quit(1)
        return
    if capture:
        var f=FileAccess.open(args[0].path_join("handoff-report.json"),FileAccess.WRITE)
        f.store_string(JSON.stringify({"frames":frame,"scenarios":reports}))
        f.close()
    print("MOTION_HANDOFF_OK")
    quit()
