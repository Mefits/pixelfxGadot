extends SceneTree
const Jump=preload("res://lab/jump_control.gd")
const Training=preload("res://lab/training_control.gd")
const Motion=preload("res://lab/walk_motion.gd")
const Walk=preload("res://lab/walk_control.gd")
const Punch=preload("res://lab/training_punch.gd")
const Leg=preload("res://lab/leg_constraints_082.gd")
var failures:Array=[]
func check(ok:bool,label:String)->void:
    if not ok and not failures.has(label):failures.append(label)
func _initialize()->void:call_deferred("run")
func run()->void:
    var docs:Dictionary={}
    for i in 3:docs[i+1]=Punch.default_doc(Punch.IDS[i])
    var original:String=JSON.stringify(docs)
    for width in [.85,1.,1.15]:
        for lead in 2:
            for direction in [-1,0,1]:
                var f=Training.new(docs,{"guard":{"width_scale":width}})
                var w=f.walker
                w.guard_lead=lead
                w.set_intent(w.guard_intent(w.programs.walk_idle,0.))
                var expected:Array=Motion.toes(w.rig,w.pose)
                check(f.press_jump(direction),"jump starts")
                check(not f.press_jump(direction) and not f.press(),"no duplicate or air attack")
                var peak:float=0.
                for tick in range(Jump.PREP_TICKS+Jump.FLIGHT_TICKS):
                    f.step(direction)
                    peak=maxf(peak,f.jump.altitude)
                    check(f.jump.altitude>=0.,"nonnegative altitude")
                    for side in Motion.SIDES:check(Leg.valid(w.pose,side),"joint constraints")
                    var toes:Array=Motion.toes(w.rig,w.pose)
                    for toe in toes:check(Vector2(toe).y-f.jump.altitude<.03,"no below-floor toe")
                    if f.jump.altitude>0.:
                        check(not w.paths[0].stance and not w.paths[1].stance,"no air support")
                        check(f.jump.can_second(),"second available in air")
                check(f.jump.state==0 and f.jump.altitude==0.,"land and release on default tick budget")
                check(absf(peak/f.jump.body_height-Jump.HEIGHT_SCALE)<.001,"height ratio")
                check(absf(w.x)<.001 if direction==0 else w.x*direction>35.,"directional travel")
                var landed:Array=Motion.toes(w.rig,w.pose)
                for i in 2:check(Vector2(landed[i]).distance_to(expected[i])<.04,"profile landing target")
                check(Walk.lead_of(landed,lead)==lead,"lead preserved")
                check(f.press(),"immediate grounded attack")
    var steer=Training.new(docs)
    steer.press_jump(1)
    for tick in range(Jump.PREP_TICKS+10):steer.step(1)
    var before:float=steer.jump.vx
    steer.step(-1)
    check(steer.jump.vx>0. and steer.jump.vx<before,"steering not instantaneous")
    for tick in 50:steer.step(-1)
    check(steer.jump.state==0,"steering lands")
    for direction in [-1,1]:
        for phase in range(0,32,4):
            var f=Training.new(docs)
            for tick in range(phase+1):f.step(direction)
            check(f.press_jump(direction),"jump out of walk")
            for tick in range(Jump.PREP_TICKS+Jump.FLIGHT_TICKS):f.step(direction)
            check(f.jump.state==0 and f.press_jump(0),"second jump only after landing")
    check(JSON.stringify(docs)==original,"original clips unchanged")
    if failures.is_empty():print("ADAPTIVE_JUMP_OK")
    else:
        for failure in failures:push_error(failure)
    quit(0 if failures.is_empty() else 1)
