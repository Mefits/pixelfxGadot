extends SceneTree
## Native acceptance probe; run with Godot 4.4.1 --headless --script.
const Training=preload("res://lab/training_control.gd")
const Round=preload("res://lab/roundhouse_kick.gd")
const Keys=preload("res://lab/roundhouse_kick_poses.gd")
const Motion=preload("res://lab/walk_motion.gd")
const IK=preload("res://lab/support_adaptation_077.gd")
const Leg=preload("res://lab/leg_constraints_082.gd")
var failures:Array=[]
var cases:int=0
var sides:Array=[0,0]
var max_slip:float=0.
var min_reach:float=INF
var min_speed:float=INF
func _initialize()->void:call_deferred("run")
func check(ok:bool,message:String)->void:
    if not ok and not failures.has(message):failures.append(message)

func exercise(f)->void:
    var w=f.walker
    var prior:Dictionary=w.pose.duplicate(true)
    var before_x:float=w.x
    var before_strikes:int=f.strikes
    check(f.press_round_kick(),"accept L")
    check(w.pose==prior and w.x==before_x,"capture does not teleport")
    check(not f.press_round_kick() and not f.press_kick() and not f.press() and not f.press_jump(),"exclusive attack")
    var strike:int=f.round_kick.striking
    var support:int=f.round_kick.support_leg
    var anchor:Vector2=f.round_kick.anchor
    var s:String=Motion.SIDES[strike]
    var reach:float=IK.reach(w.rig,s)
    var prior_tip:Vector2=f.round_kick.strike_tip(w)
    var peak:float=0.
    var hit_tip:=Vector2.ZERO
    sides[strike]+=1
    cases+=1
    for i in Round.ROUND_END:
        f.step(0)
        var tick:int=i+1
        check(f.round_kick.age==tick,"one tick per step")
        check(f.round_kick.active==(tick<Round.ROUND_END),"exact release tick")
        var toes:Array=Motion.toes(w.rig,w.pose)
        if w.paths[support].stance:
            var slip:float=(Vector2(toes[support])+Vector2.RIGHT*w.x).distance_to(anchor)
            max_slip=maxf(max_slip,slip)
            check(slip<.04,"support anchor")
        check(Vector2(toes[strike]).y<.15,"free toe above floor")
        for leg in Motion.SIDES:
            check(Leg.bend(w.pose,leg)>=-.01 and Leg.bend(w.pose,leg)<=155.01,"knee limit")
            check(Leg.ankle(w.pose,leg)>=-95.01 and Leg.ankle(w.pose,leg)<=85.01,"ankle limit")
        var tip:Vector2=f.round_kick.strike_tip(w)
        if tick>Round.ROUND_CHAMBER and tick<=Round.ROUND_HIT:
            peak=maxf(peak,tip.distance_to(prior_tip)*60.)
        prior_tip=tip
        if tick==Round.ROUND_HIT:
            hit_tip=tip
            min_reach=minf(min_reach,(tip.x-anchor.x)/reach)
            min_speed=minf(min_speed,peak/reach)
            var delta:Vector2=w.rig.point("foot_"+s)-w.rig.point("thigh_"+s)
            check(delta.length()>.99*reach and delta.y<-.44*reach,"high extension")
            check(tip.x-anchor.x>1.25*reach and tip.y-anchor.y<-reach,"shin reach and height")
            check(peak>20.*reach,"sharp strike")
            check(absf(w.pose.angles.pelvis_turn-(9. if strike==0 else 81.))<.01,"mirrored pelvis")
        if tick==18:check(tip.y<hit_tip.y,"upward follow-through")
        if tick==Round.ROUND_CHAMBER or tick==Round.ROUND_RETRACT:
            check(Leg.bend(w.pose,s)>120.,"folded knee")
    check(f.strikes==before_strikes+1,"one contact event")
    check(w.paths[0].stance and w.paths[1].stance and w.guard_lead==strike,"adaptive landing")
    check(w.ground_speed==0.,"no leftover momentum")
    check(f.press_jump(),"immediate jump after release")

func run()->void:
    check(Keys.KEYS.size()==3 and Round.ROUND_HIT-Round.ROUND_CHAMBER==3,"three keys / three strike ticks")
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
    check(combo.press() and combo.press() and combo.press(),"original combo")
    check(combo.press_round_kick() and not combo.press_round_kick() and not combo.press_kick(),"single shared buffer")
    for i in 240:
        combo.step(0)
        if combo.round_kick.active:break
    check(combo.round_kick.active and combo.last_chain==3 and combo.starts==[1,2,3],"L follows combo")
    check(combo.docs==source,"original documents unchanged")
    var sequential=Training.new()
    check(sequential.press_round_kick(),"start L")
    for i in Round.ROUND_END:sequential.step(0)
    check(sequential.press_kick(),"K after L")
    for i in sequential.kick.end_tick:sequential.step(0)
    check(sequential.press_round_kick(),"L after K")
    check(sides[0]>0 and sides[1]>0,"both anatomical sides")
    print("ROUNDHOUSE_V18 ",JSON.stringify({"cases":cases,"sides":sides,"max_slip":max_slip,"min_reach_per_leg":min_reach,"min_peak_speed_per_leg":min_speed,"failures":failures}))
    quit(0 if failures.is_empty() else 1)
