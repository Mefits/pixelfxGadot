extends SceneTree
const Training=preload("res://lab/training_control.gd")
const Tuning=preload("res://lab/attack_tuning.gd")
const K=preload("res://lab/sparse_kick_poses.gd")
const L=preload("res://lab/roundhouse_kick_poses.gd")
var failures:Array=[]
func _initialize()->void:call_deferred("run")
func check(ok:bool,message:String)->void:
    if not ok and not failures.has(message):failures.append(message)
func run()->void:
    for roundhouse in [false,true]:
        for side in [0,1]:
            var f=Training.new()
            var actor=f.round_kick if roundhouse else f.kick
            var d:Dictionary=Tuning.defaults(roundhouse)
            check(d.shoulder_scale==1.,"v19 default compatibility")
            for tick in range(1,int(d.prep_ticks+d.strike_ticks+d.return_ticks)+1):
                var original:Dictionary=L.sample(tick) if roundhouse else K.sample(tick)
                check(Tuning.shape_key(original,d)==original,"unchanged default key")
                for scale in [0.,.5,1.5]:
                    var tuned:Dictionary=Tuning.normalize({"shoulder_scale":scale},roundhouse)
                    var changed:Dictionary=Tuning.shape_key(original,tuned)
                    check(is_equal_approx(changed.shoulder_turn,clampf(45.+(float(original.shoulder_turn)-45.)*scale,0.,90.)),"shoulder target")
                    changed.shoulder_turn=original.shoulder_turn
                    check(changed==original,"independent channel")
            actor.configure({"leg":side})
            check(f.press_round_kick() if roundhouse else f.press_kick(),"first start")
            var end:int=actor.end_tick
            for i in end:f.step(0)
            var first:PackedVector2Array=actor.trace.duplicate()
            var first_anchor:Vector2=actor.trace_anchor
            var first_hit:int=actor.trace_hit_index
            check(first.size()==end+1 and first_hit>=0,"complete trace")
            actor.configure({"leg":side,"shoulder_scale":0.})
            check(f.press_round_kick() if roundhouse else f.press_kick(),"second start")
            check(actor.previous_trace==first and actor.previous_trace_anchor==first_anchor and actor.previous_trace_hit_index==first_hit,"archive previous trace")
            check(actor.trace.size()==1,"fresh trace")
            for i in actor.chamber_tick:f.step(0)
            check(is_equal_approx(float(f.walker.pose.angles.shoulder_turn),45.),"neutral shoulder target in solved pose")
            check(actor.previous_trace==first,"immutable history during recording")
            var reset=Training.new()
            var restored=reset.round_kick if roundhouse else reset.kick
            restored.inherit_trace_history(actor)
            check(restored.previous_trace==first and restored.trace.is_empty(),"reset mid-attack retains completed take")
            while actor.active:f.step(0)
            var second:PackedVector2Array=actor.trace.duplicate()
            restored.inherit_trace_history(actor)
            check(restored.previous_trace==second,"reset after complete take")
            var other=f.kick if roundhouse else f.round_kick
            check(other.trace.is_empty() and other.previous_trace.is_empty(),"independent K and L history")
    var invalid:Dictionary=Tuning.normalize({"shoulder_scale":9.},false)
    check(invalid.shoulder_scale==1.5 and Tuning.normalize({},false).shoulder_scale==1.,"range and legacy JSON")
    print("ATTACK_COMPARE_V20 ",JSON.stringify({"failures":failures}))
    quit(0 if failures.is_empty() else 1)
