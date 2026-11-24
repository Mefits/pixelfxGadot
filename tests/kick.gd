extends SceneTree
const W=preload("res://game/world.gd")
const K=preload("res://game/kick_pose.gd")
const R=preload("res://game/rig.gd")
const M=preload("res://game/motor.gd")
var errors:int=0
func _initialize()->void:call_deferred("_run")
func check(ok:bool,msg:String)->void:
    if not ok:errors+=1;push_error(msg)
func close_world(gap:float=72)->RefCounted:
    var w=W.new()
    w.a.separate(150)
    w.b.separate(w.a.pos.x+gap-w.b.pos.x)
    w.rig_a.sample(w.a)
    w.rig_b.sample(w.b)
    return w
func _run()->void:
    var w=close_world()
    var support:Vector2=w.a.feet[1]
    var root_x:float=w.a.pos.x
    var bx:float=w.b.pos.x
    var max_knee:float=0
    var max_reach:float=0
    var end_pose:bool=false
    for i in range(150):
        w.tick({"kick":i<120},{})
        var p:Dictionary=w.rig_a.points
        if w.jab_a.kicking():
            check(w.a.feet[1]==support and w.a.pos.x==root_x,"Rear support and root fixed")
            check(p.foot_far.distance_to(support-Vector2(0,2))<.5,"Rendered support stays planted")
            if w.jab_a.age<K.ACTIVE_FROM:check(w.hits==0,"Windup cannot hit")
            max_knee=maxf(max_knee,M.FLOOR-p.knee_near.y)
            max_reach=maxf(max_reach,p.foot_near.x-root_x)
        for side in ["near","far"]:
            check(absf(p["thigh_"+side].distance_to(p["knee_"+side])-R.UPPER_LEG)<.001,"Thigh length")
            check(absf(p["knee_"+side].distance_to(p["foot_"+side])-R.LOWER_LEG)<.001,"Shin length")
            check(p["foot_"+side].y<=M.FLOOR+.01,"No floor penetration")
        if i>120 and w.jab_a.age<0:end_pose=p.foot_near.distance_to(w.a.feet[0]-Vector2(0,2))<.5
    check(w.hits==1 and w.jab_b.hp==100-K.DAMAGE,"One kick contact")
    check(w.jab_a.attacks==1 and end_pose,"Held kick no repeat, return to guard")
    check(max_knee>65 and max_reach>48,"Chamber and extension")
    check(w.frozen_ticks==K.HITSTOP and w.b.pos.x>bx+15,"Kick freeze and knockback")
    var mirrored=close_world()
    for i in range(150):mirrored.tick({},{"kick":i==0})
    check(mirrored.hits==1 and mirrored.jab_a.hp==100-K.DAMAGE and mirrored.a.pos.x<435,"Mirrored kick")
    var miss=close_world(130)
    for i in range(120):miss.tick({"kick":i==0},{})
    check(miss.hits==0 and miss.frozen_ticks==0,"Kick whiff")
    var air=close_world()
    air.tick({"jump":true},{})
    air.tick({"kick":true},{})
    for i in range(150):air.tick({},{})
    check(air.jab_a.attacks==0,"No airborne kick or delayed air input")
    var moving=W.new()
    for i in range(45):moving.tick({"move":1,"run":true},{})
    moving.tick({"move":1,"kick":true},{})
    for i in range(130):moving.tick({"move":1},{})
    check(moving.jab_a.attacks==1 and moving.jab_a.kind=="kick","Buffered kick settles running support")
    var interrupted=close_world(60)
    for i in range(120):interrupted.tick({"kick":i==0},{"jab":i==0})
    check(interrupted.jab_a.hp==90 and interrupted.jab_b.hp==100 and interrupted.jab_a.age<0,"Jab interrupts kick before active")
    print("N kick failures: ",errors,"; knee lift ",max_knee,"; ankle reach ",max_reach)
    quit(0 if errors==0 else 1)
