extends SceneTree
## Godot 4.4.1: --headless --path godot --script res://tests/run_v14.gd
const Walk=preload("res://lab/walk_control.gd")
const Training=preload("res://lab/training_control.gd")
const Motion=preload("res://lab/walk_motion.gd")
const Jump=preload("res://lab/jump_control.gd")
const Leg=preload("res://lab/leg_constraints_082.gd")
var failures:Array=[]
func check(ok:bool,message:String)->void:
    if not ok and not failures.has(message):failures.append(message)
func _initialize()->void:call_deferred("run")
func run()->void:
    for dir in [-1,1]:
        var w=Walk.new()
        w.travel_limit=1000.
        for tick in 30:
            var previous:float=w.ground_speed
            var old_x:float=w.x
            var old_paths:Array=w.paths.duplicate(true)
            w.step(dir,true)
            check(absf(w.ground_speed-previous)<=Walk.RUN_ACCEL/60.+.001,"bounded acceleration")
            check(absf(w.ground_speed-(w.x-old_x)*60.)<.001,"actual signed velocity")
            for i in 2:
                if old_paths[i].stance and w.paths[i].stance:
                    check(absf(Vector2(old_paths[i].toe).x+old_x-Vector2(w.paths[i].toe).x-w.x)<.02,"stance goal pinned")
            for side in Motion.SIDES:check(Leg.valid(w.pose,side),"run leg limits")
        check(absf(w.ground_speed-dir*Walk.RUN_SPEED)<.001,"full sprint")
        check(w.sprint_active and w.FACING==1,"sprint fixed facing")
        for tick in 30:
            var previous:float=w.ground_speed
            w.step(dir,false)
            check(absf(w.ground_speed-previous)<=Walk.RUN_BRAKE/60.+.001,"run to walk brakes")
        check(not w.sprint_active and absf(w.ground_speed-dir*w.walk_speed(dir))<.001,"walk restored")
        for tick in 25:w.step(dir,true)
        var previous:float=w.ground_speed
        w.step(-dir,true)
        check(w.ground_speed*dir>0. and absf(w.ground_speed)<absf(previous),"reverse first brakes")
        for tick in 45:w.step(-dir,true)
        check(w.ground_speed*(-dir)>100.,"reverse after stop")
        for tick in 50:w.step(0,false)
        check(not w.sprint_active and w.ground_speed==0. and w.action_name()=="walk_breathe","idle after brake")
        # Start both jumps away from limits; compare the air segment only.
        var standing=Training.new()
        standing.walker.travel_limit=1000.
        standing.press_jump(dir)
        for tick in Jump.PREP_TICKS:standing.step(dir)
        var start:float=standing.walker.x
        for tick in standing.jump.flight_ticks:standing.step(dir)
        var normal_distance:float=absf(standing.walker.x-start)
        var f=Training.new()
        f.walker.travel_limit=1000.
        f.walker.x=-200. if dir>0 else 200.
        for tick in 30:f.step(dir,true)
        check(absf(f.walker.ground_speed)>100.,"training sprint")
        var incoming:float=f.walker.ground_speed
        f.press_jump(dir)
        check(f.jump.inherited_speed==incoming and not f.walker.sprint_active,"captured before suspension")
        for tick in Jump.PREP_TICKS:f.step(dir,true)
        check(absf(f.jump.vx-incoming)<.001,"launch momentum")
        start=f.walker.x
        for tick in f.jump.flight_ticks:f.step(dir,true)
        check(absf(f.walker.x-start)>normal_distance*1.6,"run lengthens flight")
        check(f.jump.state==0 and f.walker.ground_speed==0.,"landing clears speed")
        check(f.press(),"immediate attack after landing")
        var d=Training.new()
        d.walker.travel_limit=1000.
        d.walker.x=-200. if dir>0 else 200.
        for tick in 30:d.step(dir,true)
        d.press_jump(0)
        for tick in Jump.PREP_TICKS+12:d.step(0)
        var vx:float=d.jump.vx
        var height:float=d.jump.altitude
        var x:float=d.walker.x
        check(absf(vx)>100.,"released input preserves momentum")
        check(d.press_jump(-dir),"second impulse")
        check(d.jump.vx*(-dir)>100. and d.jump.altitude==height and d.walker.x==x,"second redirects without teleport")
        check(not d.press_jump(dir),"no third jump")
        for tick in d.jump.second_ticks:d.step(-dir)
        check(d.jump.state==0,"double jump lands")
    var wall=Training.new()
    for tick in 100:wall.step(1,true)
    check(wall.walker.x<=Training.BAG_X-Training.BAG_RADIUS-9.+.001 and wall.walker.ground_speed==0.,"bag stops sprint")
    wall.press_jump(0)
    check(wall.jump.launch_vx==0.,"no stale speed at obstacle")
    if failures.is_empty():print("RUN_V14_OK")
    else:
        for failure in failures:push_error(failure)
    quit(0 if failures.is_empty() else 1)
