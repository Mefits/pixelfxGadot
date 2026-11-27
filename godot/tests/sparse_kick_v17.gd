extends SceneTree
## v17 engine acceptance: original v16 cases plus measured reach and impulse.
const Training=preload("res://lab/training_control.gd")
const Motion=preload("res://lab/walk_motion.gd")
const Kick=preload("res://lab/sparse_kick.gd")
const Keys=preload("res://lab/sparse_kick_poses.gd")
const Leg=preload("res://lab/leg_constraints_082.gd")
const IK=preload("res://lab/support_adaptation_077.gd")
var failures:Array=[]
var sides:Array=[0,0]
var cases:int=0
var max_slip:float=0.
var max_floor:float=0.
var min_peak_reach:float=INF
var min_peak_speed:float=INF
func _initialize()->void:call_deferred("run")
func check(ok:bool,message:String)->void:
    if not ok and not failures.has(message):failures.append(message)

func exercise(f)->void:
    var w=f.walker
    var prior:Dictionary=w.pose.duplicate(true)
    var before_x:float=w.x
    var before_strikes:int=f.strikes
    check(f.press_kick(),"accept K")
    check(w.pose==prior and w.x==before_x,"command does not teleport pose")
    check(not f.press_kick() and not f.press() and not f.press_jump(),"exclusive active attack")
    var strike:int=f.kick.striking
    var support:int=f.kick.support_leg
    var anchor:Vector2=f.kick.anchor
    var last_tip_x:float=0.
    var peak_speed:float=0.
    sides[strike]+=1
    cases+=1
    for i in Kick.END:
        f.step(0)
        check(f.kick.age==i+1,"one tick per step")
        check(f.kick.active==(i+1<Kick.END),"exact release tick")
        var toes:Array=Motion.toes(w.rig,w.pose)
        if w.paths[support].stance:
            var drift:float=(Vector2(toes[support])+Vector2.RIGHT*w.x).distance_to(anchor)
            max_slip=maxf(max_slip,drift)
            check(drift<.04,"fixed world support")
        max_floor=maxf(max_floor,Vector2(toes[strike]).y)
        check(Vector2(toes[strike]).y<.15,"free toe above floor")
        for s in Motion.SIDES:
            check(Leg.bend(w.pose,s)>=-.01 and Leg.bend(w.pose,s)<=155.01,"knee limit")
            check(Leg.ankle(w.pose,s)>=-95.01 and Leg.ankle(w.pose,s)<=85.01,"ankle limit")
        var tip_x:float=f.kick.heel_tip(w).x-anchor.x
        if i+1>Kick.CHAMBER and i+1<=Kick.HIT:
            peak_speed=maxf(peak_speed,(tip_x-last_tip_x)*60.)
        last_tip_x=tip_x
        if i+1==Kick.HIT:
            var s:String=Motion.SIDES[strike]
            var reach:float=IK.reach(w.rig,s)
            min_peak_reach=minf(min_peak_reach,tip_x/reach)
            min_peak_speed=minf(min_peak_speed,peak_speed/reach)
            check(tip_x>1.45*reach,"functional reach relative to support")
            check(peak_speed>28.*reach,"explosive distal speed")
            check(f.kick.heel_tip(w).x>Vector2(toes[strike]).x+w.x+.5,"heel leads toe at impact")
            check(absf(w.pose.angles.pelvis_turn-(5. if strike==0 else 85.))<.01,"mirrored pelvis drive")
            var delta:Vector2=w.rig.point("foot_"+s)-w.rig.point("thigh_"+s)
            check(delta.x>IK.reach(w.rig,s)*.90 and absf(delta.y)<2.,"high forward strike for both roles")
        if i+1==Kick.CHAMBER or i+1==Kick.RETRACT:
            check(Leg.bend(w.pose,Motion.SIDES[strike])>100.,"chamber and retract")
    check(f.strikes==before_strikes+1,"one hit or miss event")
    check(w.paths[0].stance and w.paths[1].stance and w.guard_lead==strike,"adaptive landing")
    check(w.ground_speed==0.,"no residual motor drift")
    check(f.press_jump(),"immediate jump after release")

func run()->void:
    check(Keys.KEYS.size()==3,"three artistic keys")
    check(Kick.HIT-Kick.CHAMBER==3,"three-tick extension")
    for support in 2:
        var f=Training.new()
        f.walker.support_load=[.85,.15] if support==0 else [.15,.85]
        exercise(f)
    for direction in [-1,1]:
        for sprint in [false,true]:
            for seed in range(2,64,2):
                var f=Training.new()
                f.walker.travel_limit=1000.
                f.walker.x=-300. if direction>0 else 300.
                for j in seed:f.step(direction,sprint)
                exercise(f)
    var combo=Training.new()
    var source:Dictionary=combo.docs.duplicate(true)
    check(combo.press() and combo.press() and combo.press(),"original combo accepted")
    check(combo.press_kick() and not combo.press_kick(),"single K buffer")
    for i in 240:
        combo.step(0)
        if combo.kick.active:break
    check(combo.kick.active and combo.last_chain==3 and combo.starts==[1,2,3],"K follows full combo")
    check(combo.docs==source,"original authored documents unchanged")
    check(sides[0]>0 and sides[1]>0,"both anatomical sides covered")
    print("KICK_V17A ",JSON.stringify({"cases":cases,"sides":sides,"max_slip":max_slip,"max_floor":max_floor,"min_peak_reach_per_leg":min_peak_reach,"min_peak_speed_per_leg_per_second":min_peak_speed,"failures":failures}))
    quit(0 if failures.is_empty() else 1)
