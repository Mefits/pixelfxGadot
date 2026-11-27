extends SceneTree
const Repeat=preload("res://lab/attack_repeat.gd")
const Training=preload("res://lab/training_control.gd")
var failures:Array=[]
func _initialize()->void:call_deferred("run")
func check(ok:bool,message:String)->void:
    if not ok and not failures.has(message):failures.append(message)
func run()->void:
    for roundhouse in [false,true]:
        for delay in [.2,.6,3.]:
            var f=Training.new()
            var repeat=Repeat.new()
            var actor=f.round_kick if roundhouse else f.kick
            var starts:Array=[]
            check(not repeat.ready_tick(true),"disabled by default")
            repeat.set_enabled(true)
            for tick in 720:
                if repeat.ready_tick(not actor.active):
                    var started:bool=f.press_round_kick() if roundhouse else f.press_kick()
                    check(started,"start without overlap")
                    if started:
                        starts.append(tick)
                        repeat.launched(delay)
                f.step(0)
                if starts.size()>=4:break
            check(starts.size()==4,"four repetitions")
            if starts.size()==4:
                check(starts[0]==0,"immediate first start")
                for i in range(1,starts.size()):
                    check(starts[i]-starts[i-1]==actor.end_tick+roundi(delay*60.),"exact rest after completion")
            repeat.set_enabled(false)
            for i in 200:check(not repeat.ready_tick(true),"stop cancels future starts")
    var wait=Repeat.new()
    wait.set_enabled(true)
    wait.launched(.2)
    for i in 120:check(not wait.ready_tick(false),"busy never starts")
    check(wait.remaining==12,"busy does not consume rest")
    for i in 12:check(not wait.ready_tick(true),"rest tick")
    check(wait.ready_tick(true),"launch after rest")
    print("ATTACK_REPEAT_V20 ",JSON.stringify({"failures":failures}))
    quit(0 if failures.is_empty() else 1)
