extends SceneTree
const Training=preload("res://lab/training_control.gd")
const Punch=preload("res://lab/training_punch.gd")
const Motion=preload("res://lab/walk_motion.gd")
const Walk=preload("res://lab/walk_control.gd")
const Recovery=preload("res://lab/attack_recovery.gd")
var failures:Array=[]
func check(ok:bool,label:String)->void:
    if not ok and not failures.has(label):failures.append(label)
func _initialize()->void:call_deferred("run")
func run()->void:
    var docs:Dictionary={}
    for i in 3:docs[i+1]=Punch.default_doc(Punch.IDS[i])
    var original:String=JSON.stringify(docs)
    for lead in [0,1]:
        var f=Training.new(docs)
        f.walker.guard_lead=lead
        f.walker.set_intent(f.walker.guard_intent(f.walker.programs.walk_idle,0.))
        for n in 3:f.press()
        for n in 38:f.step(0)
        check(f.active==3 and f.release_tick==26 and not f.landing.is_empty(),"landing planned at tick 26")
        if f.landing.is_empty():continue
        var plan:Dictionary=f.landing.duplicate(true)
        var initial_x:float=f.walker.x
        for n in 25:
            f.step(0)
            check(f.active==3,"no unlock in air")
            if f.age>int(plan.start):
                var t:Array=Motion.toes(f.walker.rig,f.walker.pose)
                check(Vector2(t[lead]).distance_to(plan.support_toe)<.02,"support fixed during descent")
        f.step(0)
        check(f.active==0 and f.strikes==3 and f.last_chain==3,"unlocked at landing")
        check(f.walker.guard_lead==1-lead,"kicking leg becomes leading")
        var landed:Array=Motion.toes(f.walker.rig,f.walker.pose)
        check((Vector2(landed[lead])+Vector2.RIGHT*f.walker.x).distance_to(Vector2(plan.support_toe)+Vector2.RIGHT*initial_x)<.02,"support world position preserved")
        check((Vector2(landed[1-lead])+Vector2.RIGHT*f.walker.x).distance_to(Vector2(plan.landing_toe)+Vector2.RIGHT*initial_x)<.02,"landing world position preserved")
        for n in 45:
            f.step(0)
            var t:Array=Motion.toes(f.walker.rig,f.walker.pose)
            for i in 2:check(Vector2(t[i]).distance_to(landed[i])<.03,"no reset step after landing")
        check(f.walker.guard_lead==1-lead and f.walker.idle_active,"new guard persists")
        check(f.press() and f.active==1 and f.binding.lead==1-lead,"next attack uses new guard")
        var g=Training.new(docs)
        g.walker.guard_lead=lead
        g.walker.set_intent(g.walker.guard_intent(g.walker.programs.walk_idle,0.))
        for n in 3:g.press()
        for n in 64:g.step(-1)
        var x:float=g.walker.x
        g.step(-1)
        check(g.active==0 and g.walker.direction==-1 and g.walker.x<x,"held direction accepted on next tick")
    # Authorial opt-out still executes all 38 kick ticks.
    var raw_docs:Dictionary=docs.duplicate(true)
    raw_docs[3].landing_policy="authored"
    var raw=Training.new(raw_docs)
    for n in 3:raw.press()
    for n in 64:raw.step(0)
    check(raw.active==3 and raw.release_tick==38,"authored tail retained")
    for n in 12:raw.step(0)
    check(raw.active==0 and raw.strikes==3,"authored release")
    check(JSON.stringify(docs)==original,"source docs immutable")
    if failures.is_empty():print("ATTACK_RECOVERY_OK")
    else:
        for failure in failures:push_error(failure)
    quit(0 if failures.is_empty() else 1)
