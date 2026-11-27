extends SceneTree
const Profile=preload("res://lab/fighter_profile.gd")
const Walk=preload("res://lab/walk_control.gd")
const Motion=preload("res://lab/walk_motion.gd")
const Training=preload("res://lab/training_control.gd")
const Punch=preload("res://lab/training_punch.gd")
var failures:Array=[]
func check(ok:bool,label:String)->void:
    if not ok and not failures.has(label):failures.append(label)
func _initialize()->void:call_deferred("run")
func span(points:Array)->float:
    return absf(Vector2(points[0]).x-Vector2(points[1]).x)
func run()->void:
    var docs:Dictionary={}
    for i in 3:docs[i+1]=Punch.default_doc(Punch.IDS[i])
    var original:String=JSON.stringify(docs)
    var standard:Dictionary=Profile.load_profile({"guard":{"width_scale":1.0}})
    var base=Walk.new({},standard)
    var raw:Dictionary=Motion.intent(base.programs.walk_idle,0.,base.rig)
    check(Profile.apply_guard(raw.duplicate(true),standard)==raw,"default profile leaves intent identical")
    var width:float=span([raw.paths[0].toe,raw.paths[1].toe])
    for scale in [.85,1.0,1.15]:
        for lead in [0,1]:
            var f=Training.new(docs,{"guard":{"width_scale":scale}})
            var w=f.walker
            w.guard_lead=lead
            w.set_intent(w.guard_intent(w.programs.walk_idle,0.))
            var target:float=width*scale
            check(absf(span(Motion.toes(w.rig,w.pose))-target)<.03,"profile width in stance")
            for n in 140:
                f.step(0)
                var points:Array=Motion.toes(w.rig,w.pose)
                check(absf(span(points)-target)<.03,"profile width in idle")
                check(Walk.lead_of(points,lead)==lead,"idle keeps lead")
            for n in 3:f.press()
            for n in 38:f.step(0)
            check(f.active==3 and f.release_tick==26 and not f.landing.is_empty(),"profile kick release unchanged")
            if f.landing.is_empty():continue
            check(absf(Vector2(f.landing.landing_toe).distance_to(f.landing.support_toe)-target)<.01,"landing uses same guard width")
            for n in 26:f.step(0)
            check(f.active==0 and w.guard_lead==1-lead,"landing releases with new lead")
            var landed:Array=Motion.toes(w.rig,w.pose)
            check(absf(span(landed)-target)<.03,"profile width on landing")
            for n in 60:
                f.step(0)
                var points:Array=Motion.toes(w.rig,w.pose)
                for i in 2:check(Vector2(points[i]).distance_to(landed[i])<.04,"no correction step after profile landing")
    check(JSON.stringify(docs)==original,"source clips unchanged")
    check(Profile.load_profile({"guard":{"width_scale":100}}).guard.width_scale==Profile.MAX_WIDTH,"width bounded")
    check(Profile.load_profile({"guard":{"width_scale":"invalid"}}).guard.width_scale==1.0,"invalid width fallback")
    if failures.is_empty():print("FIGHTER_PROFILE_OK")
    else:
        for failure in failures:push_error(failure)
    quit(0 if failures.is_empty() else 1)
