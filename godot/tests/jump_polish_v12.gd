extends SceneTree
## Run on Godot 4.4.1: --headless --path godot --script res://tests/jump_polish_v12.gd
const Jump=preload("res://lab/jump_control.gd")
const Training=preload("res://lab/training_control.gd")
const Motion=preload("res://lab/walk_motion.gd")
const Walk=preload("res://lab/walk_control.gd")
var failures:Array=[]

func check(ok:bool,message:String)->void:
    if not ok and not failures.has(message):failures.append(message)

func _initialize()->void:call_deferred("run")

func run()->void:
    for settings in [{},{"height_scale":.5,"flight_seconds":.4,"power_scale":.5,"tuck_scale":0.},{"height_scale":1.7,"flight_seconds":1.4,"power_scale":1.5,"tuck_scale":1.5}]:
        for lead in 2:
            for direction in [-1,0,1]:
                var f=Training.new()
                var w=f.walker
                w.guard_lead=lead
                w.set_intent(w.guard_intent(w.programs.walk_idle,0.))
                var goal:Array=Motion.toes(w.rig,w.pose)
                check(f.jump.configure(settings),"configure grounded")
                check(f.press_jump(direction),"start jump")
                var duration:int=f.jump.flight_ticks
                var ratio:float=f.jump.height_scale
                check(not f.jump.configure({"flight_seconds":.4,"height_scale":.5}),"active settings locked")
                var peak:float=0.
                for tick in range(Jump.PREP_TICKS+duration):
                    check(f.jump.state!=0,"no premature landing")
                    f.step(direction)
                    peak=maxf(peak,f.jump.altitude)
                    check(f.jump.altitude>=0.,"nonnegative altitude")
                    check(f.jump.flight_ticks==duration and f.jump.height_scale==ratio,"settings unchanged in flight")
                check(f.jump.state==0 and f.jump.altitude==0.,"land on configured tick")
                check(absf(peak/f.jump.body_height-ratio)<.004,"configured height")
                var landed:Array=Motion.toes(w.rig,w.pose)
                for i in 2:check(Vector2(landed[i]).distance_to(goal[i])<.05,"landing stance")
                check(Walk.lead_of(landed,lead)==lead,"lead preserved")
                check(f.press(),"attack immediately after landing")
    var scene=load("res://lab/walk_studio.tscn").instantiate()
    scene.manual=true
    root.add_child(scene)
    check(not scene.polish.visible,"panel hidden on entry")
    scene.toggle_polish()
    check(scene.polish.visible,"panel open")
    scene.polish.sliders["height_scale"].value=1.2
    scene.polish.sliders["flight_seconds"].value=.6
    scene.polish.request_jump(1)
    check(scene.jump_total==42 and scene.jump_frame==0,"panel launch and duration")
    scene.polish.sliders["height_scale"].value=.5
    scene.toggle_pause()
    var before:int=scene.training.ticks
    scene.manual=false
    for i in 8:scene._physics_process(1./60.)
    check(scene.training.ticks==before,"pause freezes ticks")
    scene.step_once()
    check(scene.training.ticks==before+1 and scene.paused,"single step")
    scene.toggle_pause()
    scene.set_playback_speed(.25)
    before=scene.training.ticks
    for i in 16:scene._physics_process(1./60.)
    check(scene.training.ticks==before+4,"quarter speed")
    scene.manual=true
    for i in 100:
        if scene.training.jump.state==0:break
        scene.advance()
    check(scene.jump_frame==42 and scene.trajectory.size()==43,"trace complete")
    check(absf(scene.measured_peak/scene.training.jump.body_height-1.2)<.004,"pending sliders do not affect current jump")
    scene.polish.reset_settings()
    check(is_equal_approx(scene.polish.settings().height_scale,Jump.HEIGHT_SCALE),"restore defaults")
    scene.reset()
    check(scene.trajectory.is_empty() and scene.jump_frame==0,"reset clears trace")
    scene.queue_free()
    if failures.is_empty():print("JUMP_POLISH_V12_OK")
    else:
        for failure in failures:push_error(failure)
    quit(0 if failures.is_empty() else 1)
