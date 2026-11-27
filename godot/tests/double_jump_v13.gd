extends SceneTree
## Godot 4.4.1: --headless --path godot --script res://tests/double_jump_v13.gd
const Jump=preload("res://lab/jump_control.gd")
const Training=preload("res://lab/training_control.gd")
const Motion=preload("res://lab/walk_motion.gd")
const Walk=preload("res://lab/walk_control.gd")
const Leg=preload("res://lab/leg_constraints_082.gd")
var failures:Array=[]
func check(ok:bool,message:String)->void:
    if not ok and not failures.has(message):failures.append(message)
func _initialize()->void:call_deferred("run")
func run()->void:
    for width in [.85,1.,1.15]:
        for lead in 2:
            for first in [-1,0,1]:
                for second in [-1,0,1]:
                    for trigger in [1,12,24,36,47]:
                        var f=Training.new({}, {"guard":{"width_scale":width}})
                        var w=f.walker
                        w.travel_limit=165.
                        w.guard_lead=lead
                        w.set_intent(w.guard_intent(w.programs.walk_idle,0.))
                        var goal:Array=Motion.toes(w.rig,w.pose)
                        check(f.press_jump(first),"first jump")
                        check(not f.press_jump(second),"no impulse in preparation")
                        for tick in range(Jump.PREP_TICKS+trigger):f.step(first)
                        var y:float=f.jump.altitude
                        var x:float=w.x
                        var vx:float=f.jump.vx
                        var pose:String=JSON.stringify(w.pose)
                        check(f.press_jump(second),"second impulse accepted")
                        check(f.jump.altitude==y and w.x==x and JSON.stringify(w.pose)==pose,"no impulse teleport or pose reset")
                        check(f.jump.vx==vx if second==0 else f.jump.vx*second>0.,"direction or inertia")
                        check(not f.press_jump(second) and not f.press(),"third impulse and airborne attack rejected")
                        var duration:int=f.jump.second_ticks
                        var peak:float=y
                        check(not f.jump.configure({"second_height_scale":.8}),"locked settings")
                        for tick in duration:
                            check(f.jump.state==2,"no premature landing")
                            f.step(second)
                            peak=maxf(peak,f.jump.altitude)
                            check(f.jump.altitude>=0.,"nonnegative altitude")
                            for side in Motion.SIDES:check(Leg.valid(w.pose,side),"leg constraints")
                            for toe in Motion.toes(w.rig,w.pose):check(Vector2(toe).y-f.jump.altitude<.05,"toe above floor")
                            if f.jump.state==2:check(not w.paths[0].stance and not w.paths[1].stance,"no air support")
                        check(absf(peak-f.jump.second_peak)<.15,"second peak")
                        check(f.jump.state==0 and f.jump.altitude==0.,"ground contact")
                        var landed:Array=Motion.toes(w.rig,w.pose)
                        for i in 2:check(Vector2(landed[i]).distance_to(goal[i])<.05,"profile landing")
                        check(Walk.lead_of(landed,lead)==lead,"lead preserved")
                        check(f.press(),"attack available on landing")
    var scene=load("res://lab/walk_studio.tscn").instantiate()
    scene.manual=true
    root.add_child(scene)
    scene.toggle_polish()
    scene.polish.request_jump(1)
    for i in range(Jump.PREP_TICKS+24):scene.advance()
    var before:int=scene.trajectory.size()
    scene.polish.request_jump(-1)
    check(scene.impulse_index==before-1 and scene.trajectory.size()==before,"trace retained")
    check(scene.jump_total==scene.jump_frame+scene.training.jump.second_ticks,"trace total")
    for i in range(scene.training.jump.second_ticks):scene.advance()
    check(scene.jump_total==scene.jump_frame and scene.trajectory.size()==scene.jump_frame+1,"trace final")
    scene.reset()
    check(scene.impulse_index==-1 and not scene.training.jump.second_used,"reset")
    scene.queue_free()
    if failures.is_empty():print("DOUBLE_JUMP_V13_OK")
    else:
        for failure in failures:push_error(failure)
    quit(0 if failures.is_empty() else 1)
