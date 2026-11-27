extends SceneTree
const Walk=preload("res://lab/walk_control.gd")
const Motion=preload("res://lab/walk_motion.gd")
const Training=preload("res://lab/training_control.gd")
const Punch=preload("res://lab/training_punch.gd")
var failures:Array=[]
func check(ok:bool,message:String)->void:
    if not ok and not failures.has(message):failures.append(message)
func _initialize()->void:call_deferred("run")
func run()->void:
    var docs:Dictionary={}
    for i in 3:docs[i+1]=Punch.default_doc(Punch.IDS[i])
    var leads:Dictionary={}
    for count in [1,2,3]:
        var f=Training.new(docs)
        for n in count:f.press(1)
        for tick in Punch.BOUNDARIES[count]:f.step(0)
        check(f.active==0,"exact attack boundary")
        var end:Array=Motion.toes(f.walker.rig,f.walker.pose)
        var lead:int=Walk.lead_of(end,f.walker.guard_lead)
        leads[lead]=true
        check(f.walker.guard_lead==lead,"select actual lead after attack")
        for t in Walk.STOP_TICKS+2:
            f.step(0)
            check(f.walker.guard_lead==lead,"lead latched during recovery")
        var fixed:Array=Motion.toes(f.walker.rig,f.walker.pose)
        check((Vector2(fixed[lead]).x-Vector2(fixed[1-lead]).x)>10.,"wide stance in selected order")
        var origin:float=f.walker.x
        for t in 240:
            f.step(0)
            var points:Array=Motion.toes(f.walker.rig,f.walker.pose)
            check(f.walker.guard_lead==lead and Walk.lead_of(points,lead)==lead,"no flip during idle")
            for i in 2:check(Vector2(points[i]).distance_to(fixed[i])<.1,"grounded anchors")
            check(f.walker.x==origin,"idle no travel")
        check(f.press(1),"can attack again from either stance")
        for t in 28:f.step(0)
    # This source combo ends near-forward at all three boundaries. Force the
    # opposite actual pose independently, as a future authored move can.
    var reverse=Walk.new()
    reverse.guard_lead=1
    reverse.set_intent(reverse.guard_intent(reverse.programs.walk_idle,0.))
    reverse.guard_lead=0 # Stale prior state must not override actual feet.
    reverse.capture_transition()
    check(reverse.guard_lead==1,"far lead inferred from actual pose")
    var anchors:Array=Motion.toes(reverse.rig,reverse.pose)
    for t in 260:
        reverse.step(0)
        var points:Array=Motion.toes(reverse.rig,reverse.pose)
        check(reverse.guard_lead==1 and Vector2(points[1]).x>Vector2(points[0]).x+10.,"far-forward remains stable")
        for i in 2:check(Vector2(points[i]).distance_to(anchors[i])<.1,"reversed guard anchor")
    var walking_leads:Dictionary={}
    for direction in [-1,1]:
        for tick in range(12,64,4):
            var w=Walk.new()
            for n in tick:w.step(direction)
            var expected:int=Walk.lead_of(Motion.toes(w.rig,w.pose),w.guard_lead)
            walking_leads[expected]=true
            for n in 45:w.step(0)
            check(w.guard_lead==expected and Walk.lead_of(Motion.toes(w.rig,w.pose),expected)==expected,"walking retains actual lead")
    check(walking_leads.size()==2,"walking covers both lead variants")
    for last in [0,1]:
        check(Walk.lead_of([Vector2(.2,0.),Vector2.ZERO],last)==last,"overlap retains previous lead")
    if failures.is_empty():print("ADAPTIVE_GUARD_OK")
    else:
        for failure in failures:push_error(failure)
    quit(0 if failures.is_empty() else 1)
