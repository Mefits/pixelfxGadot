extends SceneTree
const Training=preload("res://lab/training_control.gd")
const Motion=preload("res://lab/walk_motion.gd")
var max_slip:=0.
var max_hand_change:=0.
var cases:={}
var failures:=[]
func _initialize()->void:call_deferred("run")
func hands(w)->Array:
    return [w.rig.point("hand_near")+Vector2.RIGHT*w.x,w.rig.point("hand_far")+Vector2.RIGHT*w.x]
func run()->void:
    var baseline:=OS.get_cmdline_user_args().has("baseline")
    for dir in [-1,1]:
        for seed in range(2,64):
            var f=Training.new()
            var w=f.walker
            w.travel_limit=2000.
            w.x=-400. if dir>0 else 400.
            for i in seed-1:f.step(dir,true)
            var last:=hands(w)
            f.step(dir,true)
            var current:=hands(w)
            var source:Dictionary=w.pose.duplicate(true)
            var speed:float=w.ground_speed
            var side:int=w.run_gait.side
            if not w.paths[side].stance:side=1-side
            var contact:bool=w.paths[side].stance
            var anchor:float=w.x+Motion.toe(w.rig,w.pose,Motion.SIDES[side]).x
            var key:=str([dir,side,contact])
            cases[key]=cases.get(key,0)+1
            f.press_jump(0)
            if source!=w.pose:failures.append("command pose")
            for tick in 6:
                f.step(0)
                if tick==0:
                    var next:=hands(w)
                    for i in 2:max_hand_change=maxf(max_hand_change,(next[i]-2.*current[i]+last[i]).length())
                if w.paths[side].stance:
                    var toe:Vector2=Motion.toe(w.rig,w.pose,Motion.SIDES[side])+Vector2.RIGHT*w.x
                    if not contact:
                        anchor=w.x+w.paths[side].toe.x
                        contact=true
                    max_slip=maxf(max_slip,toe.distance_to(Vector2(anchor,0.)))
                if f.jump.state!=(2 if tick==5 else 1):failures.append("launch tick")
            if absf(f.jump.vx-speed)>.001:failures.append("velocity")
    print("ENTRY_METRICS ",JSON.stringify({"cases":cases,"hand_delta_change":max_hand_change,"plant_error":max_slip,"failures":failures.size()}))
    quit(0 if failures.is_empty() and (baseline or (max_slip<.05 and max_hand_change<5.)) else 1)
