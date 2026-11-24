extends SceneTree
const W=preload("res://game/world.gd")
const J=preload("res://game/jab.gd")
const R=preload("res://game/rig.gd")
var errors:int=0
func _initialize()->void:call_deferred("_run")
func check(ok:bool,msg:String)->void:
    if not ok:errors+=1;push_error(msg)
func close_world(gap:float=66)->RefCounted:
    var w=W.new()
    w.a.separate(150)
    w.b.separate(w.a.pos.x+gap-w.b.pos.x)
    w.rig_a.sample(w.a)
    w.rig_b.sample(w.b)
    return w
func _run()->void:
    var w=close_world()
    var support:Array[Vector2]=w.a.feet.duplicate()
    var bx:float=w.b.pos.x
    var before:Vector2=w.rig_a.points.hand_near
    var reach:float=0
    for i in range(100):
        w.tick({"jab":true},{})
        reach=maxf(reach,w.rig_a.points.hand_near.x-before.x)
        check(w.a.feet==support,"Attacker feet planted")
        var p:Dictionary=w.rig_a.points
        check(absf(p.shoulder_near.distance_to(p.elbow_near)-R.UPPER_ARM)<.001,"Upper arm length")
        check(absf(p.elbow_near.distance_to(p.hand_near)-R.LOWER_ARM)<.001,"Forearm length")
    check(w.hits==1 and w.jab_b.hp==90,"One contact per held attack")
    check(w.jab_a.attacks==1 and w.jab_a.age<0,"Held key does not repeat")
    check(w.b.pos.x>bx+10 and w.frozen_ticks==J.HITSTOP,"Knockback and hitstop")
    check(reach>20,"Fist extension")
    w.tick({}, {})
    w.tick({"jab":true},{})
    check(w.jab_a.attacks==2,"Second key press attacks")
    var miss=W.new()
    for i in range(70):miss.tick({"jab":i==0},{})
    check(miss.hits==0 and miss.jab_b.hp==100,"Out of range miss")
    var mirror=close_world()
    for i in range(100):mirror.tick({},{"jab":i==0})
    check(mirror.hits==1 and mirror.jab_a.hp==90 and mirror.a.pos.x<440,"Mirrored contact and knockback")
    var duel=close_world()
    for i in range(70):duel.tick({"jab":i==0},{"jab":i==0})
    check(duel.hits==2 and duel.jab_a.hp==90 and duel.jab_b.hp==90,"Simultaneous contact")
    var air=close_world()
    air.tick({"jump":true},{})
    air.tick({"jab":true},{})
    check(air.jab_a.attacks==0,"No airborne jab")
    var no_stop=close_world()
    no_stop.hitstop_enabled=false
    for i in range(100):no_stop.tick({"jab":i==0},{})
    check(no_stop.hits==1 and no_stop.frozen_ticks==0,"Hitstop A/B")
    print("N jab failures: ",errors)
    quit(0 if errors==0 else 1)
