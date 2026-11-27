extends SceneTree
const Walk=preload("res://lab/walk_control.gd")
const Motion=preload("res://lab/walk_motion.gd")
const Training=preload("res://lab/training_control.gd")
const Punch=preload("res://lab/training_punch.gd")
const Preview=preload("res://lab/walk_preview.gd")
var failures:Array=[]
func check(ok:bool,message:String)->void:
    if not ok and not failures.has(message):failures.append(message)
func _initialize()->void:call_deferred("run")
func run()->void:
    var stance:Dictionary=Motion.default_doc("walk_idle")
    var guard:Dictionary=Motion.breathing_doc(stance)
    var docs:Dictionary={"walk_idle":stance,"walk_breathe":guard,"walk_forward":Motion.default_doc("walk_forward"),"walk_backward":Motion.default_doc("walk_backward")}
    var w=Walk.new(docs)
    check(w.programs.walk_breathe.procedural,"default procedural mode")
    check(w.action_name()=="walk_breathe" and w.idle_ticks==0,"idle starts at initialization")
    var target:Array=Motion.toes(w.rig,w.pose)
    var low:float=1.
    var high:float=0.
    var error:float=0.
    var pose_hashes:Dictionary={}
    for i in 240:
        w.step(0)
        check(w.idle_ticks==i+1,"clock increments exactly once per tick")
        check(w.x==0. and w.direction==0,"no locomotion during idle")
        check(is_equal_approx(float(w.support_load[0])+float(w.support_load[1]),1.),"normalized support")
        low=minf(low,float(w.support_load[0]))
        high=maxf(high,float(w.support_load[0]))
        for side in 2:
            error=maxf(error,Motion.toe(w.rig,w.pose,Motion.SIDES[side]).distance_to(target[side]))
            check(w.paths[side].stance,"toe contact in idle")
        if i%6==0:pose_hashes[JSON.stringify(w.pose)]=true
    check(low<.46 and high>.54 and low>.40 and high<.60,"support alternates between legs")
    check(error<.1,"toe anchors remain fixed")
    check(pose_hashes.size()>15,"idle changes across frames")
    check(is_zero_approx(w.idle_time()),"clock wraps after two full cycles")
    w.step(1)
    check(not w.idle_active and w.idle_ticks==0,"walking interrupts idle")
    for i in 15:w.step(1)
    for i in Walk.STOP_TICKS+3:w.step(0)
    check(w.idle_active and w.idle_ticks==1,"idle restarts after stopping")
    var altered:Dictionary=guard.duplicate(true)
    altered.keys[1].angles.chest+=5.
    check(not Motion.prepare(altered,stance).procedural,"authored editor changes are respected")
    var preview=Preview.new(guard)
    preview.update(.25)
    var expected:Dictionary=Motion.resolve(preview.rig,preview.support,Motion.intent(Motion.prepare(guard,stance),.25,preview.rig))
    check(preview.final_pose==expected,"editor uses same guard sampler")
    var source:Dictionary=Punch.source()
    for start_tick in [0,30,60,90]:
        var f=Training.new()
        for i in start_tick:f.step(0)
        var initial:Dictionary=f.walker.pose.duplicate(true)
        f.press(1)
        check(f.entry==initial and not f.walker.idle_active,"attack starts from actual idle pose")
        f.press(1)
        f.press(1)
        for tick in range(1,77):
            f.step(0)
            if tick>=44:
                var original:Dictionary=source.keys[tick].pose
                for channel in original.angles:
                    check(absf(float(f.walker.pose.angles[channel])-float(original.angles[channel]))<.001,"attack source angles unchanged")
                for axis in 2:
                    check(absf(float(f.walker.pose.root[axis])-float(original.root[axis]))<.001,"attack source root unchanged")
        check(f.starts==[1,2,3],"all three original stages")
        var end_lead:int=Walk.lead_of(Motion.toes(f.walker.rig,f.walker.pose),f.walker.guard_lead)
        for i in 40:f.step(0)
        check(f.walker.idle_active and f.walker.idle_ticks>0,"idle resumes after combo")
        check(f.walker.guard_lead==end_lead and Walk.lead_of(Motion.toes(f.walker.rig,f.walker.pose),end_lead)==end_lead,"combo end lead preserved")
    print("DYNAMIC_GUARD_LOAD ",low," .. ",high," TOE_ERROR ",error," UNIQUE_POSES ",pose_hashes.size())
    if failures.is_empty():print("DYNAMIC_GUARD_OK")
    else:
        for failure in failures:push_error(failure)
    quit(0 if failures.is_empty() else 1)
