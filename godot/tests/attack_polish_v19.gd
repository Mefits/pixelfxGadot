extends SceneTree
const Training=preload("res://lab/training_control.gd")
const Tuning=preload("res://lab/attack_tuning.gd")
const K=preload("res://lab/sparse_kick_poses.gd")
const L=preload("res://lab/roundhouse_kick_poses.gd")
var failures:Array=[]
var cases:int=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,message:String)->void:
    if not ok and not failures.has(message):failures.append(message)

func run()->void:
    for roundhouse in [false,true]:
        var f=Training.new()
        var actor=f.round_kick if roundhouse else f.kick
        var d:Dictionary=Tuning.defaults(roundhouse)
        actor.apply_tuning()
        for tick in range(1,actor.retract_tick+1):
            var original:Dictionary=L.sample(tick) if roundhouse else K.sample(tick)
            check(actor.sample_key(tick)==original,"default artistic key")
            check(actor.authored_tick(tick)==float(tick),"default tick identity")
        check(actor.contact_start()==(12 if roundhouse else 11),"default contact start")
        check(actor.contact_end()==(16 if roundhouse else 13),"default contact end")
        for side in [0,1]:
            for timings in [[3,2,5,5],[20,8,22,25],[9,4,11,10]]:
                f=Training.new()
                actor=f.round_kick if roundhouse else f.kick
                var settings:Dictionary={"prep_ticks":timings[0],"strike_ticks":timings[1],"return_ticks":timings[2],"recovery_ticks":timings[3],"leg":side,"reach_scale":.8,"pelvis_scale":1.25,"acceleration_scale":1.3}
                actor.configure(settings)
                var before:int=f.strikes
                var accepted:bool=f.press_round_kick() if roundhouse else f.press_kick()
                check(accepted,"start")
                var end:int=timings[0]+timings[1]+timings[2]+timings[3]
                check(actor.striking==side,"forced anatomical side")
                check(actor.end_tick==end,"tuned duration")
                check(actor.authored_tick(actor.chamber_tick)==float(d.prep_ticks),"chamber remapping")
                check(actor.authored_tick(actor.hit_tick)==float(d.prep_ticks+d.strike_ticks),"hit remapping")
                actor.configure({})
                for i in end:
                    f.step(0)
                    check(actor.active==(i+1<end),"running snapshot / release")
                    check(is_finite(actor.current_speed) and is_finite(actor.current_reach),"finite measurements")
                check(f.strikes==before+1,"one contact result")
                check(actor.trace.size()==end+1,"one measured point per tick")
                check(actor.trace_hit_index==actor.hit_tick,"impact marker")
                check(actor.peak_speed>0. and actor.peak_reach>0.,"nonzero measurements")
                accepted=f.press_round_kick() if roundhouse else f.press_kick()
                check(accepted and actor.end_tick==(36 if roundhouse else 32),"pending defaults next attack")
                cases+=1
    var bad:Dictionary=Tuning.normalize({"prep_ticks":-1,"strike_ticks":999,"leg":"bad","reach_scale":INF},false)
    check(bad.prep_ticks==3 and bad.strike_ticks==8 and bad.leg==-1 and bad.reach_scale==1.,"invalid values normalized")
    print("ATTACK_POLISH_V19 ",JSON.stringify({"cases":cases,"failures":failures}))
    quit(0 if failures.is_empty() else 1)
