extends SceneTree
const W=preload("res://game/world.gd")
const J=preload("res://game/jab.gd")
const R=preload("res://game/rig.gd")
const P=preload("res://game/impact_reaction.gd")
var errors:int=0
func _initialize()->void:call_deferred("_run")
func check(ok:bool,msg:String)->void:
    if not ok:errors+=1;push_error(msg)
func close_world()->RefCounted:
    var w=W.new()
    w.a.separate(150)
    w.b.separate(w.a.pos.x+66-w.b.pos.x)
    w.rig_a.sample(w.a)
    w.rig_b.sample(w.b)
    return w
func _run()->void:
    var small=P.new()
    var strong=P.new()
    var low=P.new()
    var mirror=P.new()
    small.impulse(1,1,-1)
    strong.impulse(2,1,-1)
    low.impulse(2,.25,-1)
    mirror.impulse(2,1,1)
    var peaks:=Vector4.ZERO
    var head_at_chest_peak:float=0
    var peak_chest_tick:int=0
    var peak_head_tick:int=0
    for i in range(240):
        small.step()
        strong.step()
        low.step()
        mirror.step()
        check(strong.finite() and (strong.angles+mirror.angles).length()<.001,"Stable mirrored spring")
        peaks.x=maxf(peaks.x,absf(small.angles.x))
        if absf(strong.angles.x)>peaks.y:
            peaks.y=absf(strong.angles.x)
            peak_chest_tick=i
            head_at_chest_peak=absf(strong.angles.y)
        if absf(strong.angles.y)>peaks.z:
            peaks.z=absf(strong.angles.y)
            peak_head_tick=i
        peaks.w=maxf(peaks.w,absf(low.angles.x))
    check(peaks.y>peaks.x*1.6 and peaks.y>peaks.w*2,"Strength and contact height affect torque")
    check(peak_head_tick>peak_chest_tick and peaks.z>head_at_chest_peak,"Head lags torso")
    check(strong.angles.length()<.03 and strong.speeds.length()<.2,"Settles without runaway")
    check(W.new().hybrid_enabled,"Accepted hybrid response is default")
    var w=close_world()
    w.hybrid_enabled=true
    var baseline=close_world()
    baseline.hybrid_enabled=false
    var support:Array[Vector2]=w.a.feet.duplicate()
    var bx:float=w.b.pos.x
    var peak:float=0
    var diff:float=0
    var freeze_seen:bool=false
    for i in range(180):
        var prior:Vector4=w.jab_b.reaction.angles
        var prior_speed:Vector4=w.jab_b.reaction.speeds
        var frozen:bool=w.freeze>0
        var input:Dictionary={"heavy":i<100}
        w.tick(input,{})
        baseline.tick(input,{})
        if frozen:
            freeze_seen=true
            check(w.jab_b.reaction.angles==prior and w.jab_b.reaction.speeds==prior_speed,"No spring integration during hitstop")
        peak=maxf(peak,absf(w.jab_b.reaction.angles.x))
        diff=maxf(diff,w.rig_b.points.head.distance_to(baseline.rig_b.points.head))
        check(w.a.feet==support,"Heavy attack planted")
        for side in ["near","far"]:
            var p:Dictionary=w.rig_b.points
            check(absf(p["shoulder_"+side].distance_to(p["elbow_"+side])-R.UPPER_ARM)<.001,"Hybrid upper arm length")
            check(absf(p["elbow_"+side].distance_to(p["hand_"+side])-R.LOWER_ARM)<.001,"Hybrid forearm length")
            check(absf(p["thigh_"+side].distance_to(p["knee_"+side])-R.UPPER_LEG)<.001,"Hybrid upper leg length")
            check(absf(p["knee_"+side].distance_to(p["foot_"+side])-R.LOWER_LEG)<.001,"Hybrid lower leg length")
        check(absf(w.rig_b.points.hips.distance_to(w.rig_b.points.chest)-R.TORSO)<.001,"Torso length")
        check(absf(w.rig_b.points.chest.distance_to(w.rig_b.points.head)-R.NECK)<.001,"Neck length")
    check(w.hits==1 and w.jab_b.hp==75 and w.jab_a.attacks==1,"Heavy one contact")
    check(w.jab_b.reaction.impacts==1 and peak>10 and diff>3,"Visible hybrid response")
    check(freeze_seen and w.frozen_ticks==J.HEAVY_HITSTOP,"Heavy hitstop")
    check(w.b.pos.x>bx+25 and w.b.pos.distance_to(baseline.b.pos)<.001,"Matched A/B root motion")
    check(baseline.hits==1 and baseline.jab_b.hp==75,"Matched A/B damage")
    check(not w.jab_b.locked() and w.jab_b.reaction.angles.length()<.15,"Control recovered")
    var old_x:float=w.b.pos.x
    for i in range(40):w.tick({},{"move":1})
    check(w.b.pos.x>old_x+12,"Defender moves after recovery")
    var opposite=close_world()
    for i in range(160):opposite.tick({},{"heavy":i==0})
    check(opposite.hits==1 and opposite.jab_a.hp==75 and opposite.a.pos.x<425,"Heavy mirrored")
    var miss=W.new()
    for i in range(120):miss.tick({"heavy":i==0},{})
    check(miss.hits==0 and miss.jab_b.reaction.impacts==0 and miss.frozen_ticks==0,"Heavy miss no physics")
    var trade=close_world()
    for i in range(120):trade.tick({"heavy":i==0},{"heavy":i==0})
    check(trade.hits==2 and trade.jab_a.hp==75 and trade.jab_b.hp==75,"Heavy trade snapshot")
    print("N hybrid failures: ",errors,"; spring peaks ",peaks,"; peak ticks ",peak_chest_tick,"/",peak_head_tick,"; A/B head difference ",diff)
    quit(0 if errors==0 else 1)
